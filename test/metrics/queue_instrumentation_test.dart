import 'dart:io';

import 'package:duraq/duraq.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// Regression tests for M9.
///
/// No library code recorded a metric, so every rate a `QueueMetrics` could
/// report read zero however busy the system was, and the health surface that
/// reads those rates reported on nothing.
void main() {
  late SQLiteStorage storage;
  late MemoryQueueMetrics metrics;
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('duraq_instr_');
    storage = SQLiteStorage(dbPath: path.join(tempDir.path, 'duraq_test.db'));
    metrics = MemoryQueueMetrics();
  });

  tearDown(() async {
    await metrics.dispose();
    storage.dispose();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Queue<String> queueNamed(String name) =>
      Queue<String>(name, storage, metrics: metrics);

  group('a queue given a metrics collector', () {
    test('records the work it enqueues', () async {
      final queue = queueNamed('jobs');
      for (var i = 0; i < 5; i++) {
        await queue.enqueue('job-$i');
      }

      expect(await metrics.getThroughputRate(QueueOperation.enqueue),
          greaterThan(0),
          reason: 'five enqueues should not read as no throughput');
      expect(await metrics.getAverageLatency(QueueOperation.enqueue),
          greaterThan(Duration.zero));
    });

    test('records the work it completes, and how long it took', () async {
      final queue = queueNamed('jobs');
      await queue.enqueue('job');

      await queue.processNext((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });

      expect(await metrics.getThroughputRate(QueueOperation.process),
          greaterThan(0));
      expect(await metrics.getAverageProcessingTime(),
          greaterThanOrEqualTo(const Duration(milliseconds: 20)),
          reason: 'the processor really did take that long');
    });

    test('records failures as errors, not as successes', () async {
      final queue = queueNamed('jobs');
      await queue.enqueue('job');

      await expectLater(
        queue.processNext((_) => throw StateError('boom')),
        throwsStateError,
      );

      expect(await metrics.getErrorRate(QueueOperation.process), equals(1.0));
    });

    test('an error rate reflects the mix of outcomes', () async {
      final queue = queueNamed('jobs');
      for (var i = 0; i < 4; i++) {
        await queue.enqueue('job-$i');
      }

      await queue.processNext((_) {});
      await queue.processNext((_) {});
      await queue.processNext((_) {});
      await expectLater(
        queue.processNext((_) => throw StateError('boom')),
        throwsStateError,
      );

      expect(await metrics.getErrorRate(QueueOperation.process), equals(0.25));
    });

    test('records dequeues, but not polls of an empty queue', () async {
      final queue = queueNamed('jobs');
      await queue.enqueue('job');

      expect(await queue.dequeue(), equals('job'));
      final afterOne =
          await metrics.getThroughputRate(QueueOperation.dequeue);
      expect(afterOne, greaterThan(0));

      // An idle consumer polling an empty queue is not throughput: the figure
      // must not move.
      for (var i = 0; i < 5; i++) {
        expect(await queue.dequeue(), isNull);
      }

      expect(await metrics.getThroughputRate(QueueOperation.dequeue),
          equals(afterOne),
          reason: 'five polls found nothing and none of them was a dequeue');
    });

    test('labels every metric with the queue it came from', () async {
      await queueNamed('alpha').enqueue('a');
      await queueNamed('beta').enqueue('b');

      // Both queues share one collector, which is the point of the label.
      expect(await metrics.getThroughputRate(QueueOperation.enqueue),
          greaterThan(0));
    });

    test('a queue without a collector still works', () async {
      final queue = Queue<String>('jobs', storage);
      await queue.enqueue('job');

      expect(await queue.processNext((_) {}), isTrue);
      expect(await metrics.getThroughputRate(QueueOperation.process),
          equals(0.0),
          reason: 'nothing was passed a collector, so nothing recorded');
    });
  });

  group('the health surface', () {
    test('is reachable from the package import', () {
      // The README documented this API, and lib/duraq.dart never exported it,
      // so following the README gave "Method not found".
      final checks = HealthCheckAggregator([
        StorageHealthCheck(storage),
        MetricsHealthCheck(metrics),
        QueueHealthCheck(storage, metrics),
      ]);

      expect(checks.checks, hasLength(3));
    });

    test('reports the error rate of a queue that has been failing', () async {
      final queue = queueNamed('jobs');
      for (var i = 0; i < 4; i++) {
        await queue.enqueue('job-$i');
      }
      await queue.processNext((_) {});
      for (var i = 0; i < 3; i++) {
        await expectLater(
          queue.processNext((_) => throw StateError('boom')),
          throwsStateError,
        );
      }

      final result = await QueueHealthCheck(
        storage,
        metrics,
        maxErrorRate: 0.1,
      ).check();

      expect(result.status, equals(HealthStatus.degraded),
          reason: 'three failures in four is not a healthy queue');
      expect(result.details['errorRate'], equals(0.75));
    });

    test('is healthy when the same queue is working', () async {
      final queue = queueNamed('jobs');
      for (var i = 0; i < 4; i++) {
        await queue.enqueue('job-$i');
        await queue.processNext((_) {});
      }

      final result = await QueueHealthCheck(storage, metrics).check();

      expect(result.status, equals(HealthStatus.healthy));
      expect(result.details['errorRate'], equals(0.0));
      expect(result.details['ready'], equals(0));
    });

    test('running the check samples each queue size', () async {
      final queue = queueNamed('jobs');
      await queue.enqueue('a');
      await queue.enqueue('b');

      expect(await metrics.getCurrentQueueSize('jobs'), equals(0),
          reason: 'nothing has measured it yet');

      await QueueHealthCheck(storage, metrics).check();

      expect(await metrics.getCurrentQueueSize('jobs'), equals(2),
          reason: 'the check is the thing that counts queues');
    });

    test('the metrics check reports figures rather than an invented queue',
        () async {
      final queue = queueNamed('jobs');
      await queue.enqueue('job');
      await queue.processNext((_) {});

      final result = await MetricsHealthCheck(metrics).check();

      expect(result.status, equals(HealthStatus.healthy));
      expect(result.details['processedPerSecond'], greaterThan(0));
    });
  });
}
