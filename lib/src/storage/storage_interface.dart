import '../queue_entry.dart';
import 'maintenance.dart';

/// What `store` should do when the storage already holds an entry with the
/// same id.
enum StoreConflict {
  /// Throw a `DuplicateEntryException`. The default: a repeated id is usually
  /// a mistake, and silence would hide it.
  fail,

  /// Overwrite the stored entry with the one being stored. Use this when the
  /// caller owns the id and is restating the entry.
  replace,

  /// Keep the stored entry and do nothing. Use this to make an enqueue
  /// idempotent, for a producer that retries a call it got no answer for.
  ignore,
}

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

  /// Stores a queue entry.
  ///
  /// Entry ids are unique across the whole storage, not per queue. If an entry
  /// with the same id is already stored, [onConflict] decides what happens; by
  /// default a `DuplicateEntryException` is thrown.
  Future<void> store(
    String queueName,
    QueueEntry<dynamic> entry, {
    StoreConflict onConflict = StoreConflict.fail,
  });

  /// Retrieves the next entry from the queue
  Future<QueueEntry<dynamic>?> retrieve(String queueName);

  /// Returns the number of entries in a queue
  Future<int> count(String queueName);

  /// Lists all available queues
  Future<List<String>> listQueues();

  /// Removes a queue and all its entries
  Future<void> removeQueue(String queueName);

  /// Removes a specific entry from a queue
  Future<void> removeEntry(String queueName, String entryId);

  /// Updates the status of a queue entry.
  ///
  /// Pass the [leaseId] the entry was handed out with to make the change
  /// conditional on still holding the claim. If the lease has since expired and
  /// the entry was given to another consumer, the change is discarded rather
  /// than applied over that consumer's work. Omitting it updates the entry
  /// unconditionally, which is what an administrative change wants.
  Future<void> updateEntryStatus(
    String queueName,
    String entryId,
    EntryStatus status, {
    String? errorMessage,
    DateTime? nextRetryAt,
    int? attempts,
    String? leaseId,
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
  Future<List<QueueEntry<dynamic>>> retrieveAll(String queueName);

  /// Checks if the storage is responsive
  Future<void> ping();

  /// Performs one pass of periodic upkeep and reports what it did.
  ///
  /// A pass returns entries whose consumer died to the queue, marks entries
  /// that outlived their deadline as expired, and deletes finished entries
  /// older than [policy] allows. Nothing in this package calls it on a
  /// schedule: run it from your own timer, or at startup, as often as the
  /// queue's volume warrants.
  ///
  /// Pass [queueName] to limit the pass to one queue.
  ///
  /// Backends are not required to support maintenance. The built-in SQLite and
  /// Isar backends do; a custom backend that does not will throw
  /// [UnsupportedError] from this default implementation.
  Future<MaintenanceReport> runMaintenance({
    RetentionPolicy policy = const RetentionPolicy(),
    String? queueName,
  }) async {
    throw UnsupportedError(
      '$runtimeType does not support maintenance. Override runMaintenance to '
      'support it.',
    );
  }
} 