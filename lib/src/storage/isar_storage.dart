import 'dart:convert';
import 'package:isar/isar.dart';

import '../queue_entry.dart';
import 'storage_interface.dart';
import 'isar_models.dart';
import 'isar_lock.dart';

/// Isar-based implementation of StorageInterface
/// 
/// This implementation accepts an external Isar instance, allowing users to
/// share the same Isar database across multiple components and manage the
/// database lifecycle externally.
class IsarStorage implements StorageInterface {
  final Isar _isar;
  late final IsarQueueLock _lock;
  
  /// Tracks the current transaction depth
  int _transactionDepth = 0;
  
  /// Whether the storage has been disposed
  bool _isDisposed = false;

  /// Default lock duration for queue entries
  static const defaultLockDuration = Duration(minutes: 5);

  /// Creates an IsarStorage instance with an external Isar database.
  /// 
  /// The provided [isar] instance must be opened with the required schemas
  /// from [requiredSchemas]. The caller is responsible for managing the
  /// Isar instance lifecycle (opening and closing).
  /// 
  /// Example:
  /// ```dart
  /// final isar = await Isar.open([
  ///   ...IsarStorage.requiredSchemas,
  ///   // other schemas...
  /// ]);
  /// final storage = IsarStorage(isar);
  /// ```
  IsarStorage(this._isar) {
    if (!_isar.isOpen) {
      throw ArgumentError('Provided Isar instance is not open');
    }
    _lock = IsarQueueLock(_isar);
  }

  /// Returns the list of Isar collection schemas required by DuraQ.
  /// 
  /// Users must include these schemas when opening their Isar instance:
  /// ```dart
  /// final isar = await Isar.open([
  ///   ...IsarStorage.requiredSchemas,
  ///   // your other schemas...
  /// ]);
  /// ```
  static List<CollectionSchema> get requiredSchemas => [
    QueueCollectionSchema,
    QueueEntryCollectionSchema,
    QueueLockCollectionSchema,
  ];

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('Cannot use disposed IsarStorage');
    }
    if (!_isar.isOpen) {
      throw StateError('Isar instance has been closed');
    }
  }

  @override
  Future<void> beginTransaction() async {
    _checkDisposed();
    // Isar handles transactions automatically, but we track depth for compatibility
    _transactionDepth++;
  }

  @override
  Future<void> commitTransaction() async {
    _checkDisposed();
    if (_transactionDepth == 0) {
      throw StateError('No transaction to commit');
    }
    _transactionDepth--;
  }

  @override
  Future<void> rollbackTransaction() async {
    _checkDisposed();
    if (_transactionDepth == 0) {
      throw StateError('No transaction to rollback');
    }
    _transactionDepth--;
  }

  @override
  Future<T> transaction<T>(Future<T> Function() operations) async {
    _checkDisposed();
    await beginTransaction();
    try {
      // Execute operations directly - Isar will handle the transaction internally
      final result = await operations();
      await commitTransaction();
      return result;
    } catch (e) {
      if (_transactionDepth > 0) {
        await rollbackTransaction();
      }
      rethrow;
    }
  }

  @override
  Future<void> store(String queueName, QueueEntry entry) async {
    _checkDisposed();
    
    await _isar.writeTxn(() async {
      // Ensure queue exists
      final existingQueue = await _isar.queueCollections
          .filter()
          .nameEqualTo(queueName)
          .findFirst();
      
      if (existingQueue == null) {
        final queue = QueueCollection()
          ..name = queueName
          ..createdAt = DateTime.now()
          ..lastUpdatedAt = DateTime.now();
        await _isar.queueCollections.put(queue);
      }

      // If entry is already expired, store it as expired
      final status = entry.isExpired ? EntryStatus.expired : entry.status;

      // Store entry
      final entryCollection = QueueEntryCollection()
        ..entryId = entry.id
        ..queueName = queueName
        ..data = jsonEncode({'data': entry.data})
        ..createdAt = entry.createdAt
        ..lastUpdatedAt = entry.lastUpdatedAt
        ..expiresAt = entry.expiresAt
        ..scheduledFor = entry.scheduledFor
        ..nextRetryAt = entry.nextRetryAt
        ..attempts = entry.attempts
        ..priority = entry.priority
        ..status = status
        ..errorMessage = entry.errorMessage;

      await _isar.queueEntryCollections.put(entryCollection);
    });
  }

  @override
  Future<QueueEntry?> retrieve(String queueName) async {
    _checkDisposed();
    
    return await _isar.writeTxn(() async {
      return await _retrieveInternal(queueName);
    });
  }

  /// Internal method to retrieve an entry without transaction handling
  Future<QueueEntry?> _retrieveInternal(String queueName) async {
    final now = DateTime.now();

    // First, mark expired entries
    final expiredEntries = await _isar.queueEntryCollections
        .filter()
        .queueNameEqualTo(queueName)
        .and()
        .statusEqualTo(EntryStatus.pending)
        .and()
        .expiresAtIsNotNull()
        .and()
        .expiresAtLessThan(now)
        .findAll();
    
    for (final entry in expiredEntries) {
      entry.status = EntryStatus.expired;
      entry.lastUpdatedAt = now;
      await _isar.queueEntryCollections.put(entry);
    }

    // Find the next available entry
    final entryCollection = await _isar.queueEntryCollections
        .filter()
        .queueNameEqualTo(queueName)
        .and()
        .statusEqualTo(EntryStatus.pending)
        .and()
        .group((q) => q
            .expiresAtIsNull()
            .or()
            .expiresAtGreaterThan(now))
        .and()
        .group((q) => q
            .scheduledForIsNull()
            .or()
            .scheduledForLessThan(now, include: true))
        .sortByPriority()
        .thenByCreatedAt()
        .findFirst();

    if (entryCollection == null) {
      return null;
    }

    // Try to acquire a lock on the entry
    final lockId = await _lock.tryAcquire(
      queueName,
      entryCollection.entryId,
      lockDuration: defaultLockDuration,
    );

    // If we couldn't acquire the lock, try the next entry
    if (lockId == null) {
      return _retrieveInternal(queueName);
    }

    final data = jsonDecode(entryCollection.data)['data'];
    
    // Update the entry status to processing
    entryCollection.status = EntryStatus.processing;
    entryCollection.lastUpdatedAt = now;
    await _isar.queueEntryCollections.put(entryCollection);

    return QueueEntry(
      id: entryCollection.entryId,
      data: data,
      createdAt: entryCollection.createdAt,
      lastUpdatedAt: entryCollection.lastUpdatedAt,
      attempts: entryCollection.attempts,
      priority: entryCollection.priority,
      status: EntryStatus.processing,
      errorMessage: entryCollection.errorMessage,
      expiresAt: entryCollection.expiresAt,
      nextRetryAt: entryCollection.nextRetryAt,
    );
  }

  /// Removes expired entries from the queue
  Future<int> cleanupExpiredEntries() async {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(hours: 24));
    
    // Count entries to be deleted
    final count = await _isar.queueEntryCollections
        .filter()
        .statusEqualTo(EntryStatus.expired)
        .and()
        .lastUpdatedAtLessThan(cutoff)
        .count();

    // Mark entries as expired first
    await _isar.writeTxn(() async {
      final entriesToExpire = await _isar.queueEntryCollections
          .filter()
          .statusEqualTo(EntryStatus.pending)
          .and()
          .expiresAtIsNotNull()
          .and()
          .expiresAtLessThan(now)
          .findAll();
      
      for (final entry in entriesToExpire) {
        entry.status = EntryStatus.expired;
        entry.lastUpdatedAt = now;
        await _isar.queueEntryCollections.put(entry);
      }

      // Remove expired entries older than 24 hours
      await _isar.queueEntryCollections
          .filter()
          .statusEqualTo(EntryStatus.expired)
          .and()
          .lastUpdatedAtLessThan(cutoff)
          .deleteAll();
    });

    return count;
  }

  @override
  Future<int> count(String queueName) async {
    final now = DateTime.now();
    return await _isar.queueEntryCollections
        .filter()
        .queueNameEqualTo(queueName)
        .and()
        .statusEqualTo(EntryStatus.pending)
        .and()
        .group((q) => q
            .expiresAtIsNull()
            .or()
            .expiresAtGreaterThan(now))
        .count();
  }

  @override
  Future<List<String>> listQueues() async {
    final queues = await _isar.queueCollections.where().findAll();
    return queues.map((queue) => queue.name).toList();
  }

  @override
  Future<void> removeQueue(String queueName) async {
    await _isar.writeTxn(() async {
      // Remove all entries for this queue
      await _isar.queueEntryCollections
          .filter()
          .queueNameEqualTo(queueName)
          .deleteAll();
      
      // Remove the queue itself
      await _isar.queueCollections
          .filter()
          .nameEqualTo(queueName)
          .deleteAll();
    });
  }

  @override
  Future<void> removeEntry(String queueName, String entryId) async {
    await _isar.writeTxn(() async {
      await _isar.queueEntryCollections
          .filter()
          .queueNameEqualTo(queueName)
          .and()
          .entryIdEqualTo(entryId)
          .deleteAll();
    });
  }

  @override
  Future<void> updateEntryStatus(
    String queueName,
    String entryId,
    EntryStatus status, {
    String? errorMessage,
    DateTime? nextRetryAt,
  }) async {
    _checkDisposed();

    // Release the lock if the entry is completed or failed
    if (status == EntryStatus.completed || status == EntryStatus.failed) {
      await _lock.release(queueName, entryId, '${queueName}_${entryId}_*');
    }

    await _isar.writeTxn(() async {
      final entry = await _isar.queueEntryCollections
          .filter()
          .queueNameEqualTo(queueName)
          .and()
          .entryIdEqualTo(entryId)
          .findFirst();

      if (entry != null) {
        entry.status = status;
        entry.lastUpdatedAt = DateTime.now();
        entry.errorMessage = errorMessage;
        entry.nextRetryAt = nextRetryAt;
        await _isar.queueEntryCollections.put(entry);
      }
    });
  }

  /// Retrieves all entries with a specific status from a queue
  Future<List<QueueEntry>> getEntriesByStatus(
    String queueName,
    EntryStatus status,
  ) async {
    final entries = await _isar.queueEntryCollections
        .filter()
        .queueNameEqualTo(queueName)
        .and()
        .statusEqualTo(status)
        .sortByPriority()
        .thenByCreatedAt()
        .findAll();

    return entries.map((entry) {
      final data = jsonDecode(entry.data)['data'];
      return QueueEntry(
        id: entry.entryId,
        data: data,
        createdAt: entry.createdAt,
        lastUpdatedAt: entry.lastUpdatedAt,
        attempts: entry.attempts,
        priority: entry.priority,
        status: status,
        errorMessage: entry.errorMessage,
        expiresAt: entry.expiresAt,
        nextRetryAt: entry.nextRetryAt,
      );
    }).toList();
  }

  /// Disposes of the storage
  /// 
  /// This releases all locks but does NOT close the Isar instance, as it's
  /// managed externally by the caller.
  Future<void> dispose() async {
    if (!_isDisposed) {
      _transactionDepth = 0;
      
      // Release all locks before disposing
      await _lock.releaseAllLocks();
      
      // Note: We don't close the Isar instance as it's managed externally
      _isDisposed = true;
    }
  }

  @override
  Future<QueueEntry<T>?> retrieveDeadLetter<T>(String queueName) async {
    _checkDisposed();
    final entry = await _isar.queueEntryCollections
        .filter()
        .queueNameEqualTo(queueName)
        .and()
        .statusEqualTo(EntryStatus.deadLetter)
        .sortByLastUpdatedAt()
        .findFirst();

    if (entry == null) return null;

    final data = jsonDecode(entry.data)['data'];
    return QueueEntry<T>(
      id: entry.entryId,
      data: data as T,
      createdAt: entry.createdAt,
      lastUpdatedAt: entry.lastUpdatedAt,
      attempts: entry.attempts,
      priority: entry.priority,
      status: EntryStatus.deadLetter,
      errorMessage: entry.errorMessage,
      expiresAt: entry.expiresAt,
      nextRetryAt: entry.nextRetryAt,
    );
  }

  @override
  Future<List<QueueEntry<T>>> listDeadLetters<T>(
    String queueName, {
    int? limit,
    int? offset,
  }) async {
    _checkDisposed();
    final entries = await _isar.queueEntryCollections
        .filter()
        .queueNameEqualTo(queueName)
        .and()
        .statusEqualTo(EntryStatus.deadLetter)
        .sortByLastUpdatedAt()
        .offset(offset ?? 0)
        .limit(limit ?? 100)
        .findAll();

    return entries.map((entry) {
      final data = jsonDecode(entry.data)['data'];
      return QueueEntry<T>(
        id: entry.entryId,
        data: data as T,
        createdAt: entry.createdAt,
        lastUpdatedAt: entry.lastUpdatedAt,
        attempts: entry.attempts,
        priority: entry.priority,
        status: EntryStatus.deadLetter,
        errorMessage: entry.errorMessage,
        expiresAt: entry.expiresAt,
        nextRetryAt: entry.nextRetryAt,
      );
    }).toList();
  }

  @override
  Future<void> retryDeadLetter(String queueName, String entryId) async {
    _checkDisposed();
    await _isar.writeTxn(() async {
      final entry = await _isar.queueEntryCollections
          .filter()
          .queueNameEqualTo(queueName)
          .and()
          .entryIdEqualTo(entryId)
          .and()
          .statusEqualTo(EntryStatus.deadLetter)
          .findFirst();

      if (entry != null) {
        entry.status = EntryStatus.pending;
        entry.lastUpdatedAt = DateTime.now();
        entry.nextRetryAt = null;
        await _isar.queueEntryCollections.put(entry);
      }
    });
  }

  @override
  Future<void> removeDeadLetter(String queueName, String entryId) async {
    _checkDisposed();
    await _isar.writeTxn(() async {
      await _isar.queueEntryCollections
          .filter()
          .queueNameEqualTo(queueName)
          .and()
          .entryIdEqualTo(entryId)
          .and()
          .statusEqualTo(EntryStatus.deadLetter)
          .deleteAll();
    });
  }

  @override
  Future<int> purgeDeadLetters(String queueName, DateTime cutoff) async {
    _checkDisposed();
    
    // First count how many entries will be deleted
    final count = await _isar.queueEntryCollections
        .filter()
        .queueNameEqualTo(queueName)
        .and()
        .statusEqualTo(EntryStatus.deadLetter)
        .and()
        .lastUpdatedAtLessThan(cutoff)
        .count();

    // Then delete them
    await _isar.writeTxn(() async {
      await _isar.queueEntryCollections
          .filter()
          .queueNameEqualTo(queueName)
          .and()
          .statusEqualTo(EntryStatus.deadLetter)
          .and()
          .lastUpdatedAtLessThan(cutoff)
          .deleteAll();
    });

    return count;
  }

  @override
  Future<int> countDeadLetters(String queueName) async {
    _checkDisposed();
    return await _isar.queueEntryCollections
        .filter()
        .queueNameEqualTo(queueName)
        .and()
        .statusEqualTo(EntryStatus.deadLetter)
        .count();
  }

  @override
  Future<List<QueueEntry>> retrieveAll(String queueName) async {
    _checkDisposed();
    
    final entries = await _isar.queueEntryCollections
        .filter()
        .queueNameEqualTo(queueName)
        .sortByPriority()
        .thenByCreatedAt()
        .findAll();
    
    return entries.map((entry) => QueueEntry(
      id: entry.entryId,
      data: jsonDecode(entry.data)['data'],
      createdAt: entry.createdAt,
      lastUpdatedAt: entry.lastUpdatedAt,
      expiresAt: entry.expiresAt,
      scheduledFor: entry.scheduledFor,
      attempts: entry.attempts,
      priority: entry.priority,
      status: entry.status,
      errorMessage: entry.errorMessage,
      nextRetryAt: entry.nextRetryAt,
    )).toList();
  }

  @override
  Future<void> ping() async {
    _checkDisposed();
    try {
      // Simple query to test database responsiveness
      await _isar.queueCollections.where().limit(1).findAll();
    } catch (e) {
      throw Exception('Isar storage is not responsive: ${e.toString()}');
    }
  }
}
