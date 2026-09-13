import '../storage/storage_interface.dart';
import '../metrics/queue_metrics.dart';

/// Status of a health check
enum HealthStatus {
  healthy,
  degraded,
  unhealthy,
}

/// Result of a health check
class HealthCheckResult {
  final String component;
  final HealthStatus status;
  final String message;
  final Map<String, dynamic> details;
  final DateTime timestamp;

  HealthCheckResult({
    required this.component,
    required this.status,
    required this.message,
    this.details = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Interface for health checks
abstract class HealthCheck {
  /// Check the health of a specific component
  Future<HealthCheckResult> check();
}

/// Health check for queue storage
class StorageHealthCheck implements HealthCheck {
  final StorageInterface storage;

  StorageHealthCheck(this.storage);

  @override
  Future<HealthCheckResult> check() async {
    try {
      // Test basic storage operations
      await storage.ping();
      return HealthCheckResult(
        component: 'storage',
        status: HealthStatus.healthy,
        message: 'Storage is responding normally',
      );
    } catch (e) {
      return HealthCheckResult(
        component: 'storage',
        status: HealthStatus.unhealthy,
        message: 'Storage check failed: ${e.toString()}',
        details: {'error': e.toString()},
      );
    }
  }
}

/// Health check for queue metrics.
///
/// Reports whether the metrics collector answers. It used to ask for the size
/// of a queue called `health-check`, a name nothing in the system ever used, so
/// it reported healthy whatever the collector held.
class MetricsHealthCheck implements HealthCheck {
  final QueueMetrics metrics;

  /// How far back the probe reads. Only affects which figures come back, not
  /// whether the check passes.
  final Duration window;

  MetricsHealthCheck(
    this.metrics, {
    this.window = const Duration(minutes: 5),
  });

  @override
  Future<HealthCheckResult> check() async {
    try {
      // Read figures the collector holds for the system as a whole, rather
      // than for one invented queue name.
      final processed = await metrics.getThroughputRate(
        QueueOperation.process,
        window: window,
      );
      final averageProcessingTime =
          await metrics.getAverageProcessingTime(window: window);

      return HealthCheckResult(
        component: 'metrics',
        status: HealthStatus.healthy,
        message: 'Metrics system is functioning normally',
        details: {
          'processedPerSecond': processed,
          'avgProcessingTimeMs': averageProcessingTime.inMilliseconds,
          'windowMinutes': window.inMinutes,
        },
      );
    } catch (e) {
      return HealthCheckResult(
        component: 'metrics',
        status: HealthStatus.unhealthy,
        message: 'Metrics check failed: ${e.toString()}',
        details: {'error': e.toString()},
      );
    }
  }
}

/// Health check for queue operations.
///
/// Reports on the queues that actually exist, using the storage as the source
/// of truth for how much work is waiting and the metrics collector for how
/// that work has been going. It used to ask the metrics collector for the size
/// of a queue called `default`, which meant it reported on a queue the system
/// generally did not have.
///
/// Running the check records each queue's size through [metrics], so a system
/// that checks its health on a timer also gets a history of queue sizes.
class QueueHealthCheck implements HealthCheck {
  final StorageInterface storage;
  final QueueMetrics metrics;

  /// The queues to report on. Null means every queue the storage knows about,
  /// which is the useful default for "is this system healthy".
  final List<String>? queueNames;

  final Duration errorRateWindow;
  final double maxErrorRate;

  /// Ready entries above which the queue is reported degraded, if set.
  ///
  /// Compared against work that can be done *now*, not the backlog: entries
  /// scheduled for next week are not a sign of anything being wrong.
  final int? maxReadyBacklog;

  QueueHealthCheck(
    this.storage,
    this.metrics, {
    this.queueNames,
    this.errorRateWindow = const Duration(minutes: 5),
    this.maxErrorRate = 0.1, // 10% error rate threshold
    this.maxReadyBacklog,
  });

  @override
  Future<HealthCheckResult> check() async {
    try {
      final names = queueNames ?? await storage.listQueues();

      var totalWaiting = 0;
      var totalReady = 0;
      final perQueue = <String, Map<String, int>>{};

      for (final name in names) {
        final waiting = await storage.count(name);
        final ready = await storage.countReady(name);
        totalWaiting += waiting;
        totalReady += ready;
        perQueue[name] = {'waiting': waiting, 'ready': ready};

        // Running this check is the only moment anything counts a queue, so it
        // is also where the size gets sampled. Without this,
        // `getCurrentQueueSize` reads zero forever, which is what made the
        // metric worth nothing before.
        metrics.recordQueueSize(name, waiting);
      }

      final errorRate = await metrics.getErrorRate(
        QueueOperation.process,
        window: errorRateWindow,
      );
      final avgProcessingTime = await metrics.getAverageProcessingTime(
        window: errorRateWindow,
      );

      final details = <String, dynamic>{
        'errorRate': errorRate,
        // Waiting counts everything pending; ready counts what can be handed
        // out now. Scaling on the first is how a queue full of work scheduled
        // for tomorrow looks like a queue that is falling behind.
        'waiting': totalWaiting,
        'ready': totalReady,
        'queues': perQueue,
        'avgProcessingTime': avgProcessingTime.inMilliseconds,
      };

      if (errorRate > maxErrorRate) {
        return HealthCheckResult(
          component: 'queue',
          status: HealthStatus.degraded,
          message: 'High error rate detected',
          details: details,
        );
      }

      if (maxReadyBacklog != null && totalReady > maxReadyBacklog!) {
        return HealthCheckResult(
          component: 'queue',
          status: HealthStatus.degraded,
          message: 'Ready backlog of $totalReady is above '
              'the limit of $maxReadyBacklog',
          details: details,
        );
      }

      return HealthCheckResult(
        component: 'queue',
        status: HealthStatus.healthy,
        message: names.isEmpty
            ? 'No queues exist yet'
            : 'Queue is operating normally',
        details: details,
      );
    } catch (e) {
      return HealthCheckResult(
        component: 'queue',
        status: HealthStatus.unhealthy,
        message: 'Queue check failed: ${e.toString()}',
        details: {'error': e.toString()},
      );
    }
  }
}

/// Aggregates multiple health checks
class HealthCheckAggregator {
  final List<HealthCheck> checks;

  HealthCheckAggregator(this.checks);

  Future<Map<String, HealthCheckResult>> checkAll() async {
    final checkResults = await Future.wait(checks.map((check) => check.check()));
    return {for (final result in checkResults) result.component: result};
  }

  Future<HealthStatus> getOverallStatus() async {
    final results = await checkAll();
    
    if (results.values.any((r) => r.status == HealthStatus.unhealthy)) {
      return HealthStatus.unhealthy;
    }
    
    if (results.values.any((r) => r.status == HealthStatus.degraded)) {
      return HealthStatus.degraded;
    }
    
    return HealthStatus.healthy;
  }
} 