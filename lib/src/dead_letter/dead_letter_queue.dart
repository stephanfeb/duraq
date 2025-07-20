import '../queue_entry.dart';
import '../storage/storage_interface.dart';

/// Handles failed queue entries that have exceeded their retry attempts
class DeadLetterQueue<T> {
  /// The name of the source queue
  final String sourceQueueName;

  /// The storage backend
  final StorageInterface _storage;

  /// Creates a new dead letter queue for a specific source queue
  DeadLetterQueue(this.sourceQueueName, this._storage);

  /// Retrieves a dead letter entry
  Future<QueueEntry<T>?> retrieve() async {
    return await _storage.retrieveDeadLetter<T>(sourceQueueName);
  }

  /// Lists all dead letter entries
  Future<List<QueueEntry<T>>> list({int? limit, int? offset}) async {
    return await _storage.listDeadLetters<T>(
      sourceQueueName,
      limit: limit,
      offset: offset,
    );
  }

  /// Retries a dead letter entry by moving it back to the source queue
  Future<void> retry(String entryId) async {
    await _storage.retryDeadLetter(sourceQueueName, entryId);
  }

  /// Removes a dead letter entry permanently
  Future<void> remove(String entryId) async {
    await _storage.removeDeadLetter(sourceQueueName, entryId);
  }

  /// Purges all dead letter entries older than the specified duration
  Future<int> purgeOldEntries(Duration age) async {
    final cutoff = DateTime.now().subtract(age);
    return await _storage.purgeDeadLetters(sourceQueueName, cutoff);
  }

  /// Returns the number of dead letter entries
  Future<int> get length => _storage.countDeadLetters(sourceQueueName);
} 