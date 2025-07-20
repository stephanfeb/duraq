import 'dart:async';
import 'package:uuid/uuid.dart';
import 'queue_entry.dart';
import 'retry/retry_policy.dart';
import 'storage/storage_interface.dart';

/// A type-safe queue implementation
class Queue<T> {
  /// The name of this queue
  final String name;

  /// The storage backend
  final StorageInterface _storage;

  /// The retry policy for failed entries
  final RetryPolicy? _retryPolicy;

  /// Creates a new queue
  Queue(this.name, this._storage, {RetryPolicy? retryPolicy})
      : _retryPolicy = retryPolicy;

  /// Adds an item to the queue
  Future<void> enqueue(
    T data, {
    int priority = 0,
    Duration? ttl,
  }) async {
    final entry = QueueEntry<T>(
      id: _generateId(),
      data: data,
      createdAt: DateTime.now(),
      priority: priority,
      expiresAt: ttl != null ? DateTime.now().add(ttl) : null,
    );

    await _storage.store(name, entry);
  }

  /// Adds a pre-built QueueEntry to the queue.
  /// Useful for advanced scenarios like scheduling.
  Future<void> enqueueEntry(QueueEntry<T> entry) async {
    await _storage.store(name, entry);
  }

  /// Retrieves and removes the next item from the queue
  Future<T?> dequeue() async {
    final entry = await _storage.retrieve(name);
    return entry?.data as T?;
  }

  /// Processes the next item in the queue with the given callback
  Future<bool> processNext(
    FutureOr<void> Function(T data) processor,
  ) async {
    final entry = await _storage.retrieve(name);
    if (entry == null) return false;

    try {
      await processor(entry.data as T);
      await _markCompleted(entry.id);
      return true;
    } catch (e) {
      await _handleFailure(entry, e.toString());
      rethrow;
    }
  }

  /// Marks an entry as completed
  Future<void> _markCompleted(String entryId) async {
    await _storage.updateEntryStatus(name, entryId, EntryStatus.completed);
  }

  /// Handles a failed entry according to retry policy
  Future<void> _handleFailure(QueueEntry entry, String error) async {
    final attempts = entry.attempts + 1;
    if (_retryPolicy == null || !_retryPolicy!.shouldRetry(attempts, error)) {
      if (_retryPolicy?.shouldMoveToDeadLetter(attempts, error) ?? true) {
        await _storage.updateEntryStatus(
          name,
          entry.id,
          EntryStatus.deadLetter,
          errorMessage: error,
        );
      } else {
        await _storage.updateEntryStatus(
          name,
          entry.id,
          EntryStatus.failed,
          errorMessage: error,
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
    );
  }

  /// Returns the number of entries in the queue
  Future<int> get length => _storage.count(name);

  /// Generates a unique ID for a queue entry
  String _generateId() {
    return const Uuid().v4();
  }
}
