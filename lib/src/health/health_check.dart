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

/// Health check for queue metrics
class MetricsHealthCheck implements HealthCheck {
  final QueueMetrics metrics;

  MetricsHealthCheck(this.metrics);

  @override
  Future<HealthCheckResult> check() async {
    try {
      // Check if metrics system is responsive
      await metrics.getCurrentQueueSize('health-check');
      return HealthCheckResult(
        component: 'metrics',
        status: HealthStatus.healthy,
        message: 'Metrics system is functioning normally',
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

/// Health check for queue operations
class QueueHealthCheck implements HealthCheck {
  final StorageInterface storage;
  final QueueMetrics metrics;
  final Duration errorRateWindow;
  final double maxErrorRate;

  QueueHealthCheck(
    this.storage,
    this.metrics, {
    this.errorRateWindow = const Duration(minutes: 5),
    this.maxErrorRate = 0.1, // 10% error rate threshold
  });

  @override
  Future<HealthCheckResult> check() async {
    try {
      // Check error rate
      final errorRate = await metrics.getErrorRate(
        'process',
        window: errorRateWindow,
      );

      // Check queue size
      final queueSize = await metrics.getCurrentQueueSize('default');

      // Check processing time
      final avgProcessingTime = await metrics.getAverageProcessingTime(
        window: errorRateWindow,
      );

      final details = {
        'errorRate': errorRate,
        'queueSize': queueSize,
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

      return HealthCheckResult(
        component: 'queue',
        status: HealthStatus.healthy,
        message: 'Queue is operating normally',
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
    final results = <String, HealthCheckResult>{};
    
    for (final check in checks) {
      final result = await check.check();
      results[result.component] = result;
    }

    return results;
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