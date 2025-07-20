import '../queue_entry.dart';

/// Represents a single metric measurement
class MetricValue {
  /// The value of the metric
  final double value;

  /// When the metric was recorded
  final DateTime timestamp;

  /// Additional labels/tags for the metric
  final Map<String, String> labels;

  /// Creates a new metric value
  MetricValue({
    required this.value,
    required this.timestamp,
    Map<String, String>? labels,
  }) : labels = labels ?? {};
}

/// Interface for queue metrics collection
abstract class QueueMetrics {
  /// Records the time taken for an operation
  void recordLatency(String operation, Duration duration, {Map<String, String>? labels});

  /// Records a throughput event (enqueue, dequeue, etc.)
  void recordThroughput(String operation, {Map<String, String>? labels});

  /// Records an error event
  void recordError(String operation, Object error, {Map<String, String>? labels});

  /// Records a queue size measurement
  void recordQueueSize(String queueName, int size);

  /// Records entry processing time
  void recordProcessingTime(QueueEntry entry, Duration duration);

  /// Gets the average latency for an operation
  Future<Duration> getAverageLatency(String operation, {Duration? window});

  /// Gets the throughput rate for an operation
  Future<double> getThroughputRate(String operation, {Duration? window});

  /// Gets the error rate for an operation
  Future<double> getErrorRate(String operation, {Duration? window});

  /// Gets the current queue size
  Future<int> getCurrentQueueSize(String queueName);

  /// Gets the average processing time for entries
  Future<Duration> getAverageProcessingTime({Duration? window});

  /// Resets all metrics
  Future<void> reset();

  /// Disposes of any resources used by the metrics collector
  Future<void> dispose();
}

/// Common queue operations for metrics
class QueueOperation {
  static const String enqueue = 'enqueue';
  static const String dequeue = 'dequeue';
  static const String update = 'update';
  static const String delete = 'delete';
  static const String process = 'process';
  static const String retry = 'retry';
  static const String deadLetter = 'dead_letter';
  static const String lock = 'lock';
  static const String unlock = 'unlock';
  
  // Prevent instantiation
  QueueOperation._();
} 