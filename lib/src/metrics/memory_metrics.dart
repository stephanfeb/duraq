import 'dart:async';
import 'dart:collection';
import '../queue_entry.dart';
import 'queue_metrics.dart';

/// In-memory implementation of QueueMetrics
class MemoryQueueMetrics implements QueueMetrics {
  final _latencyMetrics = <String, List<MetricValue>>{};
  final _throughputMetrics = <String, List<MetricValue>>{};
  final _errorMetrics = <String, List<MetricValue>>{};
  final _queueSizeMetrics = <String, List<MetricValue>>{};
  final _processingTimeMetrics = <String, List<MetricValue>>{};

  /// Default window for metrics calculations
  static const defaultWindow = Duration(minutes: 5);

  /// Maximum number of metrics to keep per operation
  static const maxMetricsPerOperation = 1000;

  @override
  void recordLatency(String operation, Duration duration, {Map<String, String>? labels}) {
    _addMetric(
      _latencyMetrics,
      operation,
      MetricValue(
        value: duration.inMicroseconds.toDouble(),
        timestamp: DateTime.now(),
        labels: labels,
      ),
    );
  }

  @override
  void recordThroughput(String operation, {Map<String, String>? labels}) {
    _addMetric(
      _throughputMetrics,
      operation,
      MetricValue(
        value: 1.0,
        timestamp: DateTime.now(),
        labels: labels,
      ),
    );
  }

  @override
  void recordError(String operation, Object error, {Map<String, String>? labels}) {
    _addMetric(
      _errorMetrics,
      operation,
      MetricValue(
        value: 1.0,
        timestamp: DateTime.now(),
        labels: {...?labels, 'error': error.toString()},
      ),
    );
  }

  @override
  void recordQueueSize(String queueName, int size) {
    _addMetric(
      _queueSizeMetrics,
      queueName,
      MetricValue(
        value: size.toDouble(),
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void recordProcessingTime(QueueEntry entry, Duration duration) {
    _addMetric(
      _processingTimeMetrics,
      entry.id,
      MetricValue(
        value: duration.inMicroseconds.toDouble(),
        timestamp: DateTime.now(),
        labels: {'queue': entry.id},
      ),
    );
  }

  @override
  Future<Duration> getAverageLatency(String operation, {Duration? window}) async {
    final metrics = _getMetricsInWindow(_latencyMetrics[operation], window ?? defaultWindow);
    if (metrics.isEmpty) return Duration.zero;

    final average = metrics.map((m) => m.value).reduce((a, b) => a + b) / metrics.length;
    return Duration(microseconds: average.round());
  }

  @override
  Future<double> getThroughputRate(String operation, {Duration? window}) async {
    final metrics = _getMetricsInWindow(_throughputMetrics[operation], window ?? defaultWindow);
    if (metrics.isEmpty) return 0.0;

    // Calculate the actual time window between first and last metric
    final firstTime = metrics.first.timestamp;
    final lastTime = metrics.last.timestamp;
    final actualWindow = lastTime.difference(firstTime);
    
    // Use the provided window if all metrics are in the same timestamp
    // or if the actual window is too small
    final effectiveWindow = (actualWindow.inMilliseconds > 0)
        ? actualWindow
        : (window ?? Duration(seconds: 1));

    final count = metrics.length.toDouble();
    return count * Duration(seconds: 1).inMilliseconds / effectiveWindow.inMilliseconds;
  }

  @override
  Future<double> getErrorRate(String operation, {Duration? window}) async {
    final errors = _getMetricsInWindow(_errorMetrics[operation], window ?? defaultWindow);
    final throughput = _getMetricsInWindow(_throughputMetrics[operation], window ?? defaultWindow);

    if (throughput.isEmpty) return 0.0;
    return errors.length / throughput.length;
  }

  @override
  Future<int> getCurrentQueueSize(String queueName) async {
    final metrics = _queueSizeMetrics[queueName];
    if (metrics == null || metrics.isEmpty) return 0;
    return metrics.last.value.round();
  }

  @override
  Future<Duration> getAverageProcessingTime({Duration? window}) async {
    final allMetrics = _processingTimeMetrics.values.expand((m) => m).toList();
    final metrics = _getMetricsInWindow(allMetrics, window ?? defaultWindow);
    if (metrics.isEmpty) return Duration.zero;

    final average = metrics.map((m) => m.value).reduce((a, b) => a + b) / metrics.length;
    return Duration(microseconds: average.round());
  }

  @override
  Future<void> reset() async {
    _latencyMetrics.clear();
    _throughputMetrics.clear();
    _errorMetrics.clear();
    _queueSizeMetrics.clear();
    _processingTimeMetrics.clear();
  }

  @override
  Future<void> dispose() async {
    await reset();
  }

  /// Adds a metric to the specified collection
  void _addMetric(
    Map<String, List<MetricValue>> metrics,
    String key,
    MetricValue value,
  ) {
    final list = metrics.putIfAbsent(key, () => []);
    list.add(value);

    // Remove old metrics if we exceed the maximum
    if (list.length > maxMetricsPerOperation) {
      list.removeRange(0, list.length - maxMetricsPerOperation);
    }
  }

  /// Gets metrics within the specified time window
  List<MetricValue> _getMetricsInWindow(List<MetricValue>? metrics, Duration window) {
    if (metrics == null) return [];

    final cutoff = DateTime.now().subtract(window);
    return metrics.where((m) => m.timestamp.isAfter(cutoff)).toList();
  }
} 