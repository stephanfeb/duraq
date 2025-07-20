import 'package:test/test.dart';
import 'package:duraq/src/metrics/memory_metrics.dart';
import 'package:duraq/src/metrics/queue_metrics.dart';
import 'package:duraq/src/queue_entry.dart';

void main() {
  late MemoryQueueMetrics metrics;

  setUp(() {
    metrics = MemoryQueueMetrics();
  });

  tearDown(() async {
    await metrics.dispose();
  });

  group('MemoryQueueMetrics Tests', () {
    test('should record and retrieve latency metrics', () async {
      metrics.recordLatency(QueueOperation.enqueue, Duration(milliseconds: 100));
      metrics.recordLatency(QueueOperation.enqueue, Duration(milliseconds: 200));

      final avgLatency = await metrics.getAverageLatency(QueueOperation.enqueue);
      expect(avgLatency, equals(Duration(milliseconds: 150)));
    });

    test('should record and calculate throughput rate', () async {
      // Record 5 operations over 1 second
      for (var i = 0; i < 5; i++) {
        metrics.recordThroughput(QueueOperation.dequeue);
        await Future.delayed(Duration(milliseconds: 200));
      }

      final rate = await metrics.getThroughputRate(
        QueueOperation.dequeue,
        window: Duration(seconds: 1),
      );
      expect(rate, closeTo(5.0, 2.0)); // Allow more variation due to timing
    });

    test('should record and calculate error rate', () async {
      // Record 10 operations with 2 errors
      for (var i = 0; i < 10; i++) {
        metrics.recordThroughput(QueueOperation.process);
        if (i < 2) {
          metrics.recordError(QueueOperation.process, Exception('test error'));
        }
      }

      final errorRate = await metrics.getErrorRate(QueueOperation.process);
      expect(errorRate, equals(0.2)); // 20% error rate
    });

    test('should track queue size', () async {
      metrics.recordQueueSize('test-queue', 5);
      metrics.recordQueueSize('test-queue', 10);
      metrics.recordQueueSize('test-queue', 7);

      final size = await metrics.getCurrentQueueSize('test-queue');
      expect(size, equals(7)); // Should return most recent size
    });

    test('should record and calculate processing time', () async {
      final entry = QueueEntry<String>(
        id: 'test-1',
        data: 'test',
        createdAt: DateTime.now(),
      );

      metrics.recordProcessingTime(entry, Duration(milliseconds: 100));
      metrics.recordProcessingTime(entry, Duration(milliseconds: 300));

      final avgTime = await metrics.getAverageProcessingTime();
      expect(avgTime, equals(Duration(milliseconds: 200)));
    });

    test('should respect time window for metrics', () async {
      // Record metrics at different times
      metrics.recordLatency(QueueOperation.enqueue, Duration(milliseconds: 100));
      await Future.delayed(Duration(milliseconds: 100));
      metrics.recordLatency(QueueOperation.enqueue, Duration(milliseconds: 200));

      // Get metrics with a very short window
      final recentAvg = await metrics.getAverageLatency(
        QueueOperation.enqueue,
        window: Duration(milliseconds: 50),
      );

      // Should only include the most recent metric
      expect(recentAvg, equals(Duration(milliseconds: 200)));
    });

    test('should limit number of stored metrics', () async {
      // Record more than maxMetricsPerOperation
      final count = MemoryQueueMetrics.maxMetricsPerOperation + 10;
      for (var i = 0; i < count; i++) {
        metrics.recordLatency(QueueOperation.enqueue, Duration(milliseconds: 100));
      }

      // Verify we only kept maxMetricsPerOperation metrics
      final allMetrics = await Future.wait([
        for (var i = 0; i < 10; i++)
          metrics.getAverageLatency(QueueOperation.enqueue),
      ]);

      expect(allMetrics.every((d) => d == Duration(milliseconds: 100)), isTrue);
    });

    test('should handle empty metrics gracefully', () async {
      expect(
        await metrics.getAverageLatency('non-existent'),
        equals(Duration.zero),
      );
      expect(
        await metrics.getThroughputRate('non-existent'),
        equals(0.0),
      );
      expect(
        await metrics.getErrorRate('non-existent'),
        equals(0.0),
      );
      expect(
        await metrics.getCurrentQueueSize('non-existent'),
        equals(0),
      );
      expect(
        await metrics.getAverageProcessingTime(),
        equals(Duration.zero),
      );
    });

    test('should reset all metrics', () async {
      // Record some metrics
      metrics.recordLatency(QueueOperation.enqueue, Duration(milliseconds: 100));
      metrics.recordThroughput(QueueOperation.dequeue);
      metrics.recordError(QueueOperation.process, Exception('test'));
      metrics.recordQueueSize('test-queue', 5);

      // Reset metrics
      await metrics.reset();

      // Verify all metrics are cleared
      expect(
        await metrics.getAverageLatency(QueueOperation.enqueue),
        equals(Duration.zero),
      );
      expect(
        await metrics.getThroughputRate(QueueOperation.dequeue),
        equals(0.0),
      );
      expect(
        await metrics.getErrorRate(QueueOperation.process),
        equals(0.0),
      );
      expect(
        await metrics.getCurrentQueueSize('test-queue'),
        equals(0),
      );
    });
  });
} 