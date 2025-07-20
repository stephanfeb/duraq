import 'package:test/test.dart';
import 'package:duraq/src/health/health_check.dart';
import 'package:duraq/src/metrics/memory_metrics.dart';
import '../utils/mock_storage.dart';

void main() {
  late MockStorage storage;
  late MemoryQueueMetrics metrics;
  late HealthCheckAggregator healthChecks;

  setUp(() {
    storage = MockStorage();
    metrics = MemoryQueueMetrics();
    healthChecks = HealthCheckAggregator([
      StorageHealthCheck(storage),
      MetricsHealthCheck(metrics),
      QueueHealthCheck(storage, metrics),
    ]);
  });

  tearDown(() async {
    await metrics.dispose();
  });

  group('StorageHealthCheck Tests', () {
    test('should return healthy when storage is responsive', () async {
      storage.mockPingSuccess();
      final check = StorageHealthCheck(storage);
      final result = await check.check();

      expect(result.status, equals(HealthStatus.healthy));
      expect(result.component, equals('storage'));
    });

    test('should return unhealthy when storage fails', () async {
      storage.mockPingFailure(Exception('Storage error'));
      final check = StorageHealthCheck(storage);
      final result = await check.check();

      expect(result.status, equals(HealthStatus.unhealthy));
      expect(result.component, equals('storage'));
      expect(result.details['error'], contains('Storage error'));
    });
  });

  group('MetricsHealthCheck Tests', () {
    test('should return healthy when metrics are responsive', () async {
      final check = MetricsHealthCheck(metrics);
      final result = await check.check();

      expect(result.status, equals(HealthStatus.healthy));
      expect(result.component, equals('metrics'));
    });
  });

  group('QueueHealthCheck Tests', () {
    test('should return healthy when queue is operating normally', () async {
      // Record some healthy metrics
      metrics.recordThroughput('process');
      metrics.recordQueueSize('default', 5);

      final check = QueueHealthCheck(storage, metrics);
      final result = await check.check();

      expect(result.status, equals(HealthStatus.healthy));
      expect(result.component, equals('queue'));
      expect(result.details['queueSize'], equals(5));
      expect(result.details['errorRate'], equals(0.0));
    });

    test('should return degraded when error rate is high', () async {
      // Record high error rate
      for (var i = 0; i < 10; i++) {
        metrics.recordThroughput('process');
        if (i < 3) { // 30% error rate
          metrics.recordError('process', Exception('test error'));
        }
      }

      final check = QueueHealthCheck(
        storage,
        metrics,
        maxErrorRate: 0.2, // 20% threshold
      );
      final result = await check.check();

      expect(result.status, equals(HealthStatus.degraded));
      expect(result.component, equals('queue'));
      expect(result.details['errorRate'], equals(0.3));
    });
  });

  group('HealthCheckAggregator Tests', () {
    test('should aggregate all health check results', () async {
      final results = await healthChecks.checkAll();

      expect(results.length, equals(3));
      expect(results.keys, containsAll(['storage', 'metrics', 'queue']));
    });

    test('should return overall unhealthy if any check is unhealthy', () async {
      storage.mockPingFailure(Exception('Storage error'));
      final status = await healthChecks.getOverallStatus();

      expect(status, equals(HealthStatus.unhealthy));
    });

    test('should return overall degraded if any check is degraded', () async {
      // Record high error rate to trigger degraded state
      for (var i = 0; i < 10; i++) {
        metrics.recordThroughput('process');
        if (i < 3) {
          metrics.recordError('process', Exception('test error'));
        }
      }

      final status = await healthChecks.getOverallStatus();
      expect(status, equals(HealthStatus.degraded));
    });

    test('should return overall healthy if all checks pass', () async {
      storage.mockPingSuccess();
      final status = await healthChecks.getOverallStatus();

      expect(status, equals(HealthStatus.healthy));
    });
  });
} 