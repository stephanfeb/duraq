import '../queue_entry.dart';

/// Interface for queue storage implementations
abstract class StorageInterface {
  /// Starts a new transaction
  Future<void> beginTransaction();

  /// Commits the current transaction
  Future<void> commitTransaction();

  /// Rolls back the current transaction
  Future<void> rollbackTransaction();

  /// Executes operations within a transaction
  Future<T> transaction<T>(Future<T> Function() operations);

  /// Stores a queue entry
  Future<void> store(String queueName, QueueEntry entry);

  /// Retrieves the next entry from the queue
  Future<QueueEntry?> retrieve(String queueName);

  /// Returns the number of entries in a queue
  Future<int> count(String queueName);

  /// Lists all available queues
  Future<List<String>> listQueues();

  /// Removes a queue and all its entries
  Future<void> removeQueue(String queueName);

  /// Removes a specific entry from a queue
  Future<void> removeEntry(String queueName, String entryId);

  /// Updates the status of a queue entry
  Future<void> updateEntryStatus(
    String queueName,
    String entryId,
    EntryStatus status, {
    String? errorMessage,
    DateTime? nextRetryAt,
  });

  /// Retrieves a dead letter entry from a queue
  Future<QueueEntry<T>?> retrieveDeadLetter<T>(String queueName);

  /// Lists dead letter entries for a queue
  Future<List<QueueEntry<T>>> listDeadLetters<T>(
    String queueName, {
    int? limit,
    int? offset,
  });

  /// Moves a dead letter entry back to its source queue for retry
  Future<void> retryDeadLetter(String queueName, String entryId);

  /// Removes a dead letter entry permanently
  Future<void> removeDeadLetter(String queueName, String entryId);

  /// Purges dead letter entries older than the specified date
  Future<int> purgeDeadLetters(String queueName, DateTime cutoff);

  /// Returns the number of dead letter entries in a queue
  Future<int> countDeadLetters(String queueName);

  /// Retrieves all entries in the queue
  Future<List<QueueEntry>> retrieveAll(String queueName);

  /// Checks if the storage is responsive
  Future<void> ping();
} 