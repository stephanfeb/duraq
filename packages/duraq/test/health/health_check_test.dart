import 'package:duraq/duraq.dart';
import 'package:test/test.dart';

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
      metrics.recordThroughput(QueueOperation.process);
      await storage.store(
        'jobs',
        QueueEntry<String>(id: 'e1', data: 'x', createdAt: DateTime.now()),
      );

      final check = QueueHealthCheck(storage, metrics);
      final result = await check.check();

      expect(result.status, equals(HealthStatus.healthy));
      expect(result.component, equals('queue'));
      // Read from the storage, for the queues that exist. This used to report
      // the size recorded against a queue named 'default', which nothing in
      // the system ever used, so the figure was always whatever a caller had
      // last written there — or zero.
      expect(result.details['waiting'], equals(1));
      expect(result.details['ready'], equals(1));
      expect(result.details['queues'], equals({
        'jobs': {'waiting': 1, 'ready': 1},
      }));
      expect(result.details['errorRate'], equals(0.0));
    });

    test('separates work that is waiting from work that can be done',
        () async {
      await storage.store(
        'jobs',
        QueueEntry<String>(id: 'now', data: 'x', createdAt: DateTime.now()),
      );
      await storage.store(
        'jobs',
        QueueEntry<String>(
          id: 'tomorrow',
          data: 'x',
          createdAt: DateTime.now(),
          scheduledFor: DateTime.now().add(const Duration(days: 1)),
        ),
      );

      final result = await QueueHealthCheck(storage, metrics).check();

      expect(result.details['waiting'], equals(2));
      expect(result.details['ready'], equals(1),
          reason: 'work scheduled for tomorrow is not work falling behind');
    });

    test('reports degraded when the ready backlog passes its limit', () async {
      for (var i = 0; i < 5; i++) {
        await storage.store(
          'jobs',
          QueueEntry<String>(id: 'e$i', data: 'x', createdAt: DateTime.now()),
        );
      }

      final result = await QueueHealthCheck(
        storage,
        metrics,
        maxReadyBacklog: 3,
      ).check();

      expect(result.status, equals(HealthStatus.degraded));
      expect(result.message, contains('5'));
    });

    test('a backlog that cannot be worked on yet is not degraded', () async {
      for (var i = 0; i < 5; i++) {
        await storage.store(
          'jobs',
          QueueEntry<String>(
            id: 'e$i',
            data: 'x',
            createdAt: DateTime.now(),
            scheduledFor: DateTime.now().add(const Duration(days: 1)),
          ),
        );
      }

      final result = await QueueHealthCheck(
        storage,
        metrics,
        maxReadyBacklog: 3,
      ).check();

      expect(result.status, equals(HealthStatus.healthy));
      expect(result.details['waiting'], equals(5));
      expect(result.details['ready'], equals(0));
    });

    test('reports on the queues it is told to watch', () async {
      await storage.store('a',
          QueueEntry<String>(id: 'e1', data: 'x', createdAt: DateTime.now()));
      await storage.store('b',
          QueueEntry<String>(id: 'e2', data: 'x', createdAt: DateTime.now()));

      final result =
          await QueueHealthCheck(storage, metrics, queueNames: ['a']).check();

      expect(result.details['queues'], equals({
        'a': {'waiting': 1, 'ready': 1},
      }));
    });

    test('should return degraded when error rate is high', () async {
      // Record high error rate
      for (var i = 0; i < 10; i++) {
        metrics.recordThroughput(QueueOperation.process);
        if (i < 3) { // 30% error rate
          metrics.recordError(QueueOperation.process, Exception('test error'));
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
        metrics.recordThroughput(QueueOperation.process);
        if (i < 3) {
          metrics.recordError(QueueOperation.process, Exception('test error'));
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