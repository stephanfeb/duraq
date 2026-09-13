import 'dart:convert';
import 'package:isar/isar.dart';

import '../errors.dart';
import '../queue_entry.dart';
import 'maintenance.dart';
import 'storage_interface.dart';
import 'isar_models.dart';
import 'isar_lock.dart';
import 'isar_write_scope.dart';

/// Isar-based implementation of StorageInterface
///
/// This implementation accepts an external Isar instance, allowing users to
/// share the same Isar database across multiple components and manage the
/// database lifecycle externally.
class IsarStorage implements StorageInterface {
  final Isar _isar;
  late final IsarQueueLock _lock;

  /// Whether the storage has been disposed
  bool _isDisposed = false;

  /// Default lock duration for queue entries
  static const defaultLockDuration = Duration(minutes: 5);

  /// Default number of times an entry may be delivered before it is treated as
  /// poisonous and moved to the dead letter queue.
  static const defaultMaxDeliveryAttempts = 5;

  /// How long a retrieved entry stays claimed before another consumer may take
  /// it. A consumer that dies without acknowledging its entry holds it for at
  /// most this long.
  final Duration leaseDuration;

  /// How many times an entry may be handed out before a lease that expires
  /// again sends it to the dead letter queue instead of back to pending.
  final int maxDeliveryAttempts;

  /// The earliest value the expiry index can hold, used as the lower bound of
  /// the expiry sweep so that entries without a deadline are skipped.
  static final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

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
  IsarStorage(
    this._isar, {
    this.leaseDuration = defaultLockDuration,
    this.maxDeliveryAttempts = defaultMaxDeliveryAttempts,
  }) {
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

  /// Converts a QueueEntryCollection to a QueueEntry.
  /// If [statusOverride] is provided, it is used instead of the collection's status.
  QueueEntry<T> _collectionToEntry<T>(QueueEntryCollection entry, {EntryStatus? statusOverride}) {
    return QueueEntry<T>(
      id: entry.entryId,
      data: jsonDecode(entry.data) as T,
      createdAt: entry.createdAt,
      lastUpdatedAt: entry.lastUpdatedAt,
      attempts: entry.attempts,
      priority: entry.priority,
      status: statusOverride ?? entry.status,
      errorMessage: entry.errorMessage,
      expiresAt: entry.expiresAt,
      nextRetryAt: entry.nextRetryAt,
      scheduledFor: entry.scheduledFor,
    );
  }

  /// Every entry of one status in one queue, in the order retrieval wants it:
  /// priority first, then creation time. The order comes from the index, so no
  /// sort runs over the results.
  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      _byQueueAndStatus(String queueName, EntryStatus status) =>
          _isar.queueEntryCollections
              .where()
              .queueStatusKeyEqualToAnyPriorityCreatedAt(
                queueStatusKeyFor(queueName, status),
              );

  /// The row holding one entry, looked up through the identity index.
  Future<QueueEntryCollection?> _findEntry(
    String queueName,
    String entryId,
  ) =>
      _isar.queueEntryCollections
          .where()
          .entryKeyEqualTo(entryKeyFor(queueName, entryId))
          .findFirst();

  /// Isar has no way to begin a transaction in one call and end it in another,
  /// because its write transactions take the work as a callback.
  ///
  /// Use [transaction] instead, which runs the whole body in one Isar write
  /// transaction and rolls it back if the body throws.
  @override
  Future<void> beginTransaction() async {
    _checkDisposed();
    throw UnsupportedError(
      'IsarStorage does not support manually managed transactions. '
      'Use transaction() instead, which runs the body in a single Isar write '
      'transaction.',
    );
  }

  /// Not supported; see [beginTransaction].
  @override
  Future<void> commitTransaction() async {
    _checkDisposed();
    throw UnsupportedError(
      'IsarStorage does not support manually managed transactions. '
      'Use transaction() instead.',
    );
  }

  /// Not supported; see [beginTransaction].
  @override
  Future<void> rollbackTransaction() async {
    _checkDisposed();
    throw UnsupportedError(
      'IsarStorage does not support manually managed transactions. '
      'Use transaction() instead.',
    );
  }

  /// Runs [operations] in a single Isar write transaction.
  ///
  /// Storage operations called from inside the body join that transaction, so
  /// either all of them are committed or, if the body throws, none of them are.
  /// Nested calls to [transaction] join the transaction already in progress.
  @override
  Future<T> transaction<T>(Future<T> Function() operations) {
    _checkDisposed();
    return IsarWriteScope.run(_isar, operations);
  }

  @override
  Future<void> store(
    String queueName,
    QueueEntry entry, {
    StoreConflict onConflict = StoreConflict.fail,
  }) async {
    _checkDisposed();

    await IsarWriteScope.run(_isar, () async {
      // Ensure queue exists
      final existingQueue = await _isar.queueCollections
          .where()
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

      // One row per entry. Entry ids are unique across the storage, so an id
      // already used by another queue counts as taken too.
      final existing = await _isar.queueEntryCollections
          .where()
          .entryKeyEqualTo(entryKeyFor(queueName, entry.id))
          .findAll();
      final elsewhere = existing.isNotEmpty
          ? const <QueueEntryCollection>[]
          : await _isar.queueEntryCollections
              .where()
              .entryIdEqualTo(entry.id)
              .findAll();

      final taken = existing.isNotEmpty || elsewhere.isNotEmpty;
      if (taken) {
        switch (onConflict) {
          case StoreConflict.fail:
            throw DuplicateEntryException(queueName, entry.id);
          case StoreConflict.ignore:
            return;
          case StoreConflict.replace:
            break;
        }
      }

      // Drop any extra rows an earlier version of this package left behind for
      // the same entry, including one filed under another queue.
      final duplicates = [...existing.skip(1), ...elsewhere];
      if (duplicates.isNotEmpty) {
        await _isar.queueEntryCollections
            .deleteAll(duplicates.map((e) => e.id).toList());
      }

      final entryCollection =
          existing.isEmpty ? QueueEntryCollection() : existing.first;

      entryCollection
        ..entryId = entry.id
        ..queueName = queueName
        ..data = jsonEncode(entry.data)
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

    return await IsarWriteScope.run(
      _isar,
      () => _retrieveInternal(queueName),
    );
  }

  /// Returns entries whose lease has expired without being acknowledged.
  ///
  /// An entry is considered stranded when it is still `processing` but no live
  /// lock covers it, which is what happens when a consumer crashes, is killed,
  /// or takes an entry with `dequeue` and never acknowledges it. Entries that
  /// have been delivered [maxDeliveryAttempts] times go to the dead letter
  /// queue instead of back to the queue.
  ///
  /// Must be called inside a write transaction. Returns the number of entries
  /// returned to pending.
  Future<int> _reclaimStaleInternal(String? queueName, DateTime now) async {
    final claimed = queueName == null
        ? await _isar.queueEntryCollections
            .where()
            .statusEqualTo(EntryStatus.processing)
            .findAll()
        : await _byQueueAndStatus(queueName, EntryStatus.processing).findAll();

    var reclaimed = 0;
    for (final entry in claimed) {
      // A lock that is still live means the entry is in flight somewhere.
      final liveLock = await _isar.queueLockCollections
          .where()
          .lockKeyEqualTo(lockKeyFor(entry.queueName, entry.entryId))
          .filter()
          .expiresAtGreaterThan(now)
          .findFirst();
      if (liveLock != null) continue;

      entry.attempts += 1;
      entry.lastUpdatedAt = now;

      if (entry.attempts >= maxDeliveryAttempts) {
        // Poisonous: park it rather than cycling it forever.
        entry.status = EntryStatus.deadLetter;
        entry.errorMessage =
            'Lease expired without acknowledgement after $maxDeliveryAttempts '
            'deliveries';
      } else {
        entry.status = EntryStatus.pending;
        entry.nextRetryAt = null;
        reclaimed++;
      }

      await _isar.queueEntryCollections.put(entry);
    }

    return reclaimed;
  }

  /// Returns entries whose lease expired without being acknowledged to the
  /// queue, so a crashed or killed consumer does not strand them.
  ///
  /// Retrieval does this for its own queue on every call. Call this directly at
  /// startup to recover entries left behind by a previous run, optionally for a
  /// single queue.
  ///
  /// Returns the number of entries returned to pending. Entries that have been
  /// delivered [maxDeliveryAttempts] times are moved to the dead letter queue
  /// instead and are not counted.
  Future<int> reclaimStaleEntries({String? queueName}) async {
    _checkDisposed();
    return await IsarWriteScope.run(
      _isar,
      () => _reclaimStaleInternal(queueName, DateTime.now()),
    );
  }

  /// Collapses duplicate rows left behind by versions of this package that did
  /// not enforce one row per entry.
  ///
  /// Versions before this one added a new row on every `store`, so the same
  /// logical job could be handed to a processor more than once. Call this once
  /// after upgrading, on a database that has been written by an older version.
  /// The most recently updated row for each entry is kept.
  ///
  /// Returns the number of rows removed.
  Future<int> removeDuplicateEntries() async {
    _checkDisposed();

    return await IsarWriteScope.run(_isar, () async {
      final all = await _isar.queueEntryCollections.where().findAll();

      final byKey = <String, List<QueueEntryCollection>>{};
      for (final entry in all) {
        byKey
            .putIfAbsent(entryKeyFor(entry.queueName, entry.entryId), () => [])
            .add(entry);
      }

      final doomed = <int>[];
      for (final rows in byKey.values) {
        if (rows.length < 2) continue;
        rows.sort((a, b) {
          final byTime = a.lastUpdatedAt.compareTo(b.lastUpdatedAt);
          return byTime != 0 ? byTime : a.id.compareTo(b.id);
        });
        doomed.addAll(rows.take(rows.length - 1).map((e) => e.id));
      }

      if (doomed.isEmpty) return 0;
      await _isar.queueEntryCollections.deleteAll(doomed);
      return doomed.length;
    });
  }

  /// Internal method to retrieve an entry without transaction handling
  Future<QueueEntry?> _retrieveInternal(String queueName) async {
    final now = DateTime.now();

    // Take back anything a dead consumer left claimed before looking for work.
    await _reclaimStaleInternal(queueName, now);

    // Mark entries whose deadline has passed. The lower bound keeps entries
    // without a deadline out of the index range entirely.
    final expiredEntries = await _isar.queueEntryCollections
        .where()
        .queueNameEqualToExpiresAtBetween(queueName, _epoch, now)
        .filter()
        .statusEqualTo(EntryStatus.pending)
        .and()
        .expiresAtIsNotNull()
        .findAll();

    for (final entry in expiredEntries) {
      entry.status = EntryStatus.expired;
      entry.lastUpdatedAt = now;
      await _isar.queueEntryCollections.put(entry);
    }

    // Walk candidates in index order, which is already priority then creation
    // time, until we acquire a lock on one.
    const batchSize = 16;
    var offset = 0;
    while (true) {
      final candidates = await _byQueueAndStatus(queueName, EntryStatus.pending)
          .filter()
          .group((q) => q
              .expiresAtIsNull()
              .or()
              .expiresAtGreaterThan(now))
          .and()
          .group((q) => q
              .scheduledForIsNull()
              .or()
              .scheduledForLessThan(now, include: true))
          .and()
          .group((q) => q
              .nextRetryAtIsNull()
              .or()
              .nextRetryAtLessThan(now, include: true))
          .offset(offset)
          .limit(batchSize)
          .findAll();

      if (candidates.isEmpty) {
        return null;
      }

      for (final entryCollection in candidates) {
        // Try to acquire a lock on the entry
        final lockId = await _lock.tryAcquire(
          queueName,
          entryCollection.entryId,
          lockDuration: leaseDuration,
        );

        // If we couldn't acquire the lock, try the next entry
        if (lockId == null) continue;

        // Update the entry status to processing
        entryCollection.status = EntryStatus.processing;
        entryCollection.lastUpdatedAt = now;
        await _isar.queueEntryCollections.put(entryCollection);

        return _collectionToEntry(entryCollection);
      }

      // Every candidate in this batch is locked elsewhere. If the batch came
      // back short there is nothing further to look at.
      if (candidates.length < batchSize) return null;
      offset += candidates.length;
    }
  }

  /// Removes expired entries from the queue
  Future<int> cleanupExpiredEntries() async {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(hours: 24));

    // Count entries to be deleted
    final count = await _isar.queueEntryCollections
        .where()
        .statusEqualTo(EntryStatus.expired)
        .filter()
        .lastUpdatedAtLessThan(cutoff)
        .count();

    // Mark entries as expired first
    await IsarWriteScope.run(_isar, () async {
      final entriesToExpire = await _isar.queueEntryCollections
          .where()
          .statusEqualTo(EntryStatus.pending)
          .filter()
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
          .where()
          .statusEqualTo(EntryStatus.expired)
          .filter()
          .lastUpdatedAtLessThan(cutoff)
          .deleteAll();
    });

    return count;
  }

  @override
  Future<int> count(String queueName) async {
    final now = DateTime.now();
    return await _byQueueAndStatus(queueName, EntryStatus.pending)
        .filter()
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
    await IsarWriteScope.run(_isar, () async {
      // Remove all entries for this queue
      await _isar.queueEntryCollections
          .where()
          .queueNameEqualToAnyExpiresAt(queueName)
          .deleteAll();

      // Remove the queue itself
      await _isar.queueCollections
          .where()
          .nameEqualTo(queueName)
          .deleteAll();
    });
  }

  @override
  Future<void> removeEntry(String queueName, String entryId) async {
    await IsarWriteScope.run(_isar, () async {
      await _isar.queueEntryCollections
          .where()
          .entryKeyEqualTo(entryKeyFor(queueName, entryId))
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
    int? attempts,
  }) async {
    _checkDisposed();

    await IsarWriteScope.run(_isar, () async {
      // Release the lock if the entry is no longer being processed. This runs
      // in the same transaction as the status change, so a failure cannot
      // leave one applied without the other.
      if (status == EntryStatus.completed ||
          status == EntryStatus.failed ||
          status == EntryStatus.pending) {
        await _lock.release(queueName, entryId);
      }

      final entry = await _findEntry(queueName, entryId);

      if (entry != null) {
        entry.status = status;
        entry.lastUpdatedAt = DateTime.now();
        entry.errorMessage = errorMessage;
        entry.nextRetryAt = nextRetryAt;
        if (attempts != null) {
          entry.attempts = attempts;
        }
        await _isar.queueEntryCollections.put(entry);
      }
    });
  }

  /// Retrieves all entries with a specific status from a queue
  Future<List<QueueEntry>> getEntriesByStatus(
    String queueName,
    EntryStatus status,
  ) async {
    final entries = await _byQueueAndStatus(queueName, status).findAll();

    return entries
        .map((entry) => _collectionToEntry(entry, statusOverride: status))
        .toList();
  }

  /// Disposes of the storage
  ///
  /// This releases the locks this instance holds but does NOT close the Isar
  /// instance, as it's managed externally by the caller.
  Future<void> dispose() async {
    if (!_isDisposed) {
      await _lock.releaseAllLocks();

      // Note: We don't close the Isar instance as it's managed externally
      _isDisposed = true;
    }
  }

  @override
  Future<QueueEntry<T>?> retrieveDeadLetter<T>(String queueName) async {
    _checkDisposed();
    final entry = await _byQueueAndStatus(queueName, EntryStatus.deadLetter)
        .sortByLastUpdatedAt()
        .findFirst();

    if (entry == null) return null;
    return _collectionToEntry<T>(entry);
  }

  @override
  Future<List<QueueEntry<T>>> listDeadLetters<T>(
    String queueName, {
    int? limit,
    int? offset,
  }) async {
    _checkDisposed();
    final entries = await _byQueueAndStatus(queueName, EntryStatus.deadLetter)
        .sortByLastUpdatedAt()
        .offset(offset ?? 0)
        .limit(limit ?? 100)
        .findAll();

    return entries.map((entry) => _collectionToEntry<T>(entry)).toList();
  }

  @override
  Future<void> retryDeadLetter(String queueName, String entryId) async {
    _checkDisposed();
    await IsarWriteScope.run(_isar, () async {
      final entry = await _findEntry(queueName, entryId);

      if (entry != null && entry.status == EntryStatus.deadLetter) {
        entry.status = EntryStatus.pending;
        entry.lastUpdatedAt = DateTime.now();
        entry.nextRetryAt = null;
        entry.attempts = 0;
        await _isar.queueEntryCollections.put(entry);
      }
    });
  }

  @override
  Future<void> removeDeadLetter(String queueName, String entryId) async {
    _checkDisposed();
    await IsarWriteScope.run(_isar, () async {
      final entry = await _findEntry(queueName, entryId);

      if (entry != null && entry.status == EntryStatus.deadLetter) {
        await _isar.queueEntryCollections.delete(entry.id);
      }
    });
  }

  @override
  Future<int> purgeDeadLetters(String queueName, DateTime cutoff) async {
    _checkDisposed();

    return await IsarWriteScope.run(_isar, () async {
      return await _byQueueAndStatus(queueName, EntryStatus.deadLetter)
          .filter()
          .lastUpdatedAtLessThan(cutoff)
          .deleteAll();
    });
  }

  @override
  Future<int> countDeadLetters(String queueName) async {
    _checkDisposed();
    return await _byQueueAndStatus(queueName, EntryStatus.deadLetter).count();
  }

  @override
  Future<List<QueueEntry>> retrieveAll(String queueName) async {
    _checkDisposed();

    final entries = await _isar.queueEntryCollections
        .where()
        .queueNameEqualToAnyExpiresAt(queueName)
        .sortByPriority()
        .thenByCreatedAt()
        .findAll();

    return entries.map((entry) => _collectionToEntry(entry)).toList();
  }

  @override
  Future<MaintenanceReport> runMaintenance({
    RetentionPolicy policy = const RetentionPolicy(),
    String? queueName,
  }) async {
    _checkDisposed();

    return await IsarWriteScope.run(_isar, () async {
      final now = DateTime.now();

      final reclaimed = await _reclaimStaleInternal(queueName, now);

      // Mark entries whose deadline has passed.
      final toExpire = queueName == null
          ? await _isar.queueEntryCollections
              .where()
              .statusEqualTo(EntryStatus.pending)
              .filter()
              .expiresAtIsNotNull()
              .and()
              .expiresAtLessThan(now)
              .findAll()
          : await _isar.queueEntryCollections
              .where()
              .queueNameEqualToExpiresAtBetween(queueName, _epoch, now)
              .filter()
              .statusEqualTo(EntryStatus.pending)
              .and()
              .expiresAtIsNotNull()
              .findAll();

      for (final entry in toExpire) {
        entry.status = EntryStatus.expired;
        entry.lastUpdatedAt = now;
        await _isar.queueEntryCollections.put(entry);
      }

      var removed = 0;
      for (final rule in policy.removable) {
        final cutoff = now.subtract(rule.value);
        removed += queueName == null
            ? await _isar.queueEntryCollections
                .where()
                .statusEqualTo(rule.key)
                .filter()
                .lastUpdatedAtLessThan(cutoff)
                .deleteAll()
            : await _byQueueAndStatus(queueName, rule.key)
                .filter()
                .lastUpdatedAtLessThan(cutoff)
                .deleteAll();
      }

      return MaintenanceReport(
        reclaimed: reclaimed,
        expired: toExpire.length,
        removed: removed,
      );
    });
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
