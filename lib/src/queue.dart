import 'dart:async';

import 'package:uuid/uuid.dart';

import 'codec.dart';
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

  /// Creates a new queue.
  ///
  /// Payloads are stored as JSON. Pass a [codec] for a payload type
  /// `jsonEncode` cannot represent on its own; without one, enqueueing such a
  /// type throws [PayloadCodecException].
  Queue(this.name, this._storage, {RetryPolicy? retryPolicy, this.codec})
      : _retryPolicy = retryPolicy,
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

    await _store(entry);
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
    await _store(entry.withData(_encode(entry.data)), onConflict: onConflict);
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
  Future<T?> dequeue() {
    return _storage.transaction<T?>(() async {
      final claimed = await _storage.retrieve(name);
      if (claimed == null) return null;

      // Decode before the delete, inside the transaction. A codec that throws
      // then rolls the claim back and leaves the entry in the queue, instead
      // of destroying a payload nobody could read.
      final data = _decode(claimed.data);
      await _storage.removeEntry(name, claimed.id);
      return data;
    });
  }

  /// Processes the next item in the queue with the given callback
  Future<bool> processNext(
    FutureOr<void> Function(T data) processor,
  ) async {
    final entry = await _storage.retrieve(name);
    if (entry == null) return false;

    try {
      await processor(_decode(entry.data));
      await _markCompleted(entry.id, entry.leaseId);
      return true;
    } catch (e) {
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
    if (_retryPolicy == null || !_retryPolicy!.shouldRetry(attempts, error)) {
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

    final retryDelay = _retryPolicy!.getRetryDelay(attempts);
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

  /// Returns the number of entries in the queue
  Future<int> get length => _storage.count(name);

  Future<void> _store(
    QueueEntry<Object?> entry, {
    StoreConflict onConflict = StoreConflict.fail,
  }) =>
      _payload.guardWrite(
        () => _storage.store(name, entry, onConflict: onConflict),
      );

  Object? _encode(T data) => _payload.encode(data);

  T _decode(Object? stored) => _payload.decode(stored);

  /// Generates a unique ID for a queue entry
  String _generateId() {
    return _uuid.v4();
  }
}
