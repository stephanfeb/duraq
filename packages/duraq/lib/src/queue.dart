import 'dart:async';

import 'package:uuid/uuid.dart';

import 'codec.dart';
import 'metrics/queue_metrics.dart';
import 'payload_translator.dart';
import 'queue_entry.dart';
import 'retry/retry_policy.dart';
import 'storage/storage_interface.dart';

/// A type-safe queue implementation
class Queue<T> {
  static const _uuid = Uuid();

  /// The name of this queue
  final String name;

  /// The storage backend
  final StorageInterface _storage;

  /// The retry policy for failed entries
  final RetryPolicy? _retryPolicy;

  /// Converts payloads to and from what the storage can hold.
  ///
  /// Null means the payload is stored as JSON directly, which restricts this
  /// queue to types `jsonEncode` accepts.
  final QueueCodec<T>? codec;

  /// Where this queue reports what it did, if anywhere.
  ///
  /// Nothing in the library recorded a metric before, so every rate a
  /// `QueueMetrics` could report read zero however busy the system was. Pass
  /// one here and enqueues, dequeues, completions, failures and processing
  /// times are recorded as they happen, each labelled with this queue's name.
  final QueueMetrics? metrics;

  /// Creates a new queue.
  ///
  /// Payloads are stored as JSON. Pass a [codec] for a payload type
  /// `jsonEncode` cannot represent on its own; without one, enqueueing such a
  /// type throws [PayloadCodecException].
  Queue(
    this.name,
    this._storage, {
    RetryPolicy? retryPolicy,
    this.codec,
    this.metrics,
  })  : _retryPolicy = retryPolicy,
        _payload = PayloadTranslator<T>(name, codec);

  final PayloadTranslator<T> _payload;

  /// Adds an item to the queue
  Future<void> enqueue(
    T data, {
    int priority = 0,
    Duration? ttl,
  }) async {
    final entry = QueueEntry<Object?>(
      id: _generateId(),
      data: _encode(data),
      createdAt: DateTime.now(),
      priority: priority,
      expiresAt: ttl != null ? DateTime.now().add(ttl) : null,
    );

    await _timed(QueueOperation.enqueue, () => _store(entry));
  }

  /// Adds a pre-built QueueEntry to the queue.
  /// Useful for advanced scenarios like scheduling.
  ///
  /// The entry carries its own id, so it can collide with one already stored.
  /// By default that throws a [DuplicateEntryException]; pass [onConflict] to
  /// overwrite the stored entry or to keep it, which is how a producer makes a
  /// repeated enqueue idempotent.
  Future<void> enqueueEntry(
    QueueEntry<T> entry, {
    StoreConflict onConflict = StoreConflict.fail,
  }) async {
    await _timed(
      QueueOperation.enqueue,
      () => _store(entry.withData(_encode(entry.data)), onConflict: onConflict),
    );
  }

  /// Takes the next item off the queue and returns its payload.
  ///
  /// The entry is claimed and deleted in one transaction, so it is gone by the
  /// time you hold the payload. That makes delivery **at most once**: if the
  /// process dies between this call returning and the work being done, the
  /// item is lost, because nothing remains to redeliver.
  ///
  /// Use [processNext] for at-least-once delivery. There the entry survives
  /// until the processor returns, a failure is retried according to the retry
  /// policy, and a consumer that dies mid-flight has its entry reclaimed.
  ///
  /// Returns null when the queue has nothing ready.
  Future<T?> dequeue() async {
    final stopwatch = Stopwatch()..start();
    var took = false;
    try {
      final data = await _storage.transaction<T?>(() async {
        final claimed = await _storage.retrieve(name);
        if (claimed == null) return null;

        // Decode before the delete, inside the transaction. A codec that
        // throws then rolls the claim back and leaves the entry in the queue,
        // instead of destroying a payload nobody could read.
        final decoded = _decode(claimed.data);
        await _storage.removeEntry(name, claimed.id);
        took = true;
        return decoded;
      });
      // An empty queue is not a dequeue. Counting it as one would make an idle
      // consumer's polling look like throughput.
      if (took) _recordDone(QueueOperation.dequeue, stopwatch.elapsed);
      return data;
    } catch (e) {
      _recordFailure(QueueOperation.dequeue, e, stopwatch.elapsed);
      rethrow;
    }
  }

  /// Processes the next item in the queue with the given callback
  Future<bool> processNext(
    FutureOr<void> Function(T data) processor,
  ) async {
    final entry = await _storage.retrieve(name);
    if (entry == null) return false;

    final stopwatch = Stopwatch()..start();
    try {
      await processor(_decode(entry.data));
      await _markCompleted(entry.id, entry.leaseId);
      final elapsed = stopwatch.elapsed;
      _recordDone(QueueOperation.process, elapsed);
      metrics?.recordProcessingTime(entry, elapsed);
      return true;
    } catch (e) {
      _recordFailure(QueueOperation.process, e, stopwatch.elapsed);
      await _handleFailure(entry, e.toString());
      rethrow;
    }
  }

  /// Marks an entry as completed
  Future<void> _markCompleted(String entryId, String? leaseId) async {
    await _storage.updateEntryStatus(
      name,
      entryId,
      EntryStatus.completed,
      leaseId: leaseId,
    );
  }

  /// Handles a failed entry according to retry policy
  Future<void> _handleFailure(QueueEntry<dynamic> entry, String error) async {
    final attempts = entry.attempts + 1;
    if (_retryPolicy == null || !_retryPolicy.shouldRetry(attempts, error)) {
      if (_retryPolicy?.shouldMoveToDeadLetter(attempts, error) ?? true) {
        await _storage.updateEntryStatus(
          name,
          entry.id,
          EntryStatus.deadLetter,
          errorMessage: error,
          attempts: attempts,
          leaseId: entry.leaseId,
        );
      } else {
        await _storage.updateEntryStatus(
          name,
          entry.id,
          EntryStatus.failed,
          errorMessage: error,
          attempts: attempts,
          leaseId: entry.leaseId,
        );
      }
      return;
    }

    final retryDelay = _retryPolicy.getRetryDelay(attempts);
    final nextRetry = DateTime.now().add(retryDelay);

    await _storage.updateEntryStatus(
      name,
      entry.id,
      EntryStatus.pending,
      errorMessage: error,
      nextRetryAt: nextRetry,
      attempts: attempts,
      leaseId: entry.leaseId,
    );
  }

  /// The number of entries waiting in this queue, due or not.
  ///
  /// Includes entries scheduled for later and entries waiting out a retry
  /// backoff, so a queue can report a length of five and hand out nothing.
  /// Use [readyLength] for the number that can be worked on now.
  Future<int> get length => _storage.count(name);

  /// The number of entries that could be handed out right now.
  ///
  /// Zero here means [processNext] returns false and [dequeue] returns null.
  /// This is the figure a health check or an autoscaler wants; [length] counts
  /// work that may not be due for days.
  Future<int> get readyLength => _storage.countReady(name);

  Future<void> _store(
    QueueEntry<Object?> entry, {
    StoreConflict onConflict = StoreConflict.fail,
  }) =>
      _payload.guardWrite(
        () => _storage.store(name, entry, onConflict: onConflict),
      );

  Object? _encode(T data) => _payload.encode(data);

  T _decode(Object? stored) => _payload.decode(stored);

  /// Runs [action], recording how long it took and whether it threw.
  Future<R> _timed<R>(String operation, Future<R> Function() action) async {
    if (metrics == null) return action();

    final stopwatch = Stopwatch()..start();
    try {
      final result = await action();
      _recordDone(operation, stopwatch.elapsed);
      return result;
    } catch (e) {
      _recordFailure(operation, e, stopwatch.elapsed);
      rethrow;
    }
  }

  void _recordDone(String operation, Duration elapsed) {
    final metrics = this.metrics;
    if (metrics == null) return;
    metrics.recordThroughput(operation, labels: _labels);
    metrics.recordLatency(operation, elapsed, labels: _labels);
  }

  void _recordFailure(String operation, Object error, Duration elapsed) {
    final metrics = this.metrics;
    if (metrics == null) return;
    // Throughput counts attempts, not successes: an error rate is errors over
    // throughput, so leaving failures out of the denominator would let the
    // rate exceed 1 and mean nothing.
    metrics.recordThroughput(operation, labels: _labels);
    metrics.recordError(operation, error, labels: _labels);
    metrics.recordLatency(operation, elapsed, labels: _labels);
  }

  /// Every metric this queue records carries its name, so one collector can
  /// serve several queues and still be read apart.
  Map<String, String> get _labels => {'queue': name};

  /// Generates a unique ID for a queue entry
  String _generateId() {
    return _uuid.v4();
  }
}
