import 'package:duraq/duraq.dart';

/// A mock implementation of StorageInterface for testing
class MockStorage implements StorageInterface {
  final Map<String, List<QueueEntry<dynamic>>> _queues = {};
  bool _inTransaction = false;

  /// Mock ping response for health checks
  bool _pingSuccess = true;
  Object? _pingError;

  /// Configure mock to return success for ping
  void mockPingSuccess() {
    _pingSuccess = true;
    _pingError = null;
  }

  /// Configure mock to return failure for ping
  void mockPingFailure(Object error) {
    _pingSuccess = false;
    _pingError = error;
  }

  @override
  Future<void> beginTransaction() async {
    if (_inTransaction) {
      throw StateError('Already in transaction');
    }
    _inTransaction = true;
  }

  @override
  Future<void> commitTransaction() async {
    if (!_inTransaction) {
      throw StateError('No transaction to commit');
    }
    _inTransaction = false;
  }

  @override
  Future<void> rollbackTransaction() async {
    if (!_inTransaction) {
      throw StateError('No transaction to rollback');
    }
    _inTransaction = false;
  }

  @override
  Future<T> transaction<T>(Future<T> Function() operations) async {
    await beginTransaction();
    try {
      final result = await operations();
      await commitTransaction();
      return result;
    } catch (e) {
      await rollbackTransaction();
      rethrow;
    }
  }

  @override
  Future<int> count(String queueName) async {
    return _queues[queueName]?.length ?? 0;
  }

  /// The worked example for a custom backend: `implements` copies signatures
  /// only, so the interface's default body does not arrive here and this has
  /// to be written out. It mirrors what `retrieve` would hand over.
  @override
  Future<int> countReady(String queueName) async {
    final now = DateTime.now();
    return _queues[queueName]
            ?.where((entry) =>
                entry.status == EntryStatus.pending &&
                (entry.expiresAt == null || entry.expiresAt!.isAfter(now)) &&
                (entry.scheduledFor == null ||
                    !entry.scheduledFor!.isAfter(now)) &&
                (entry.nextRetryAt == null || !entry.nextRetryAt!.isAfter(now)))
            .length ??
        0;
  }

  @override
  Future<List<String>> listQueues() async {
    return _queues.keys.toList();
  }

  @override
  Future<void> removeEntry(String queueName, String entryId) async {
    final queue = _queues[queueName];
    if (queue != null) {
      queue.removeWhere((entry) => entry.id == entryId);
    }
  }

  @override
  Future<void> removeQueue(String queueName) async {
    _queues.remove(queueName);
  }

  @override
  Future<QueueEntry<dynamic>?> retrieve(String queueName) async {
    final queue = _queues[queueName];
    if (queue == null || queue.isEmpty) return null;

    // Find first pending entry
    final index = queue.indexWhere((entry) => entry.status == EntryStatus.pending);
    if (index == -1) return null;

    // Mark as processing
    final entry = queue[index];
    queue[index] = entry.copyWith(
      status: EntryStatus.processing,
      lastUpdatedAt: DateTime.now(),
    );

    return queue[index];
  }

  @override
  Future<void> store(
    String queueName,
    QueueEntry<dynamic> entry, {
    StoreConflict onConflict = StoreConflict.fail,
  }) async {
    final entries = _queues.putIfAbsent(queueName, () => []);
    final existing = entries.indexWhere((e) => e.id == entry.id);

    if (existing >= 0) {
      switch (onConflict) {
        case StoreConflict.fail:
          throw DuplicateEntryException(queueName, entry.id);
        case StoreConflict.ignore:
          return;
        case StoreConflict.replace:
          entries[existing] = entry;
          return;
      }
    }

    entries.add(entry);
  }

  @override
  Future<void> updateEntryStatus(
    String queueName,
    String entryId,
    EntryStatus status, {
    String? errorMessage,
    DateTime? nextRetryAt,
    int? attempts,
    String? leaseId,
  }) async {
    final queue = _queues[queueName];
    final index = queue?.indexWhere((entry) => entry.id == entryId) ?? -1;
    if (queue == null || index == -1) {
      // The real backends report a status change for an id they do not hold,
      // rather than succeeding silently.
      throw EntryNotFoundException(queueName, entryId);
    }

    final entry = queue[index];

    // Pending with no retry time means available now; every other field the
    // caller left out keeps its stored value. Built directly rather than
    // through copyWith, which cannot write a null.
    final clearRetry = nextRetryAt == null && status == EntryStatus.pending;

    queue[index] = QueueEntry<dynamic>(
      id: entry.id,
      data: entry.data,
      createdAt: entry.createdAt,
      lastUpdatedAt: DateTime.now(),
      expiresAt: entry.expiresAt,
      scheduledFor: entry.scheduledFor,
      attempts: attempts ?? entry.attempts,
      priority: entry.priority,
      status: status,
      errorMessage: errorMessage ?? entry.errorMessage,
      nextRetryAt: clearRetry ? null : (nextRetryAt ?? entry.nextRetryAt),
      leaseId: entry.leaseId,
    );
  }

  @override
  Future<int> countDeadLetters(String queueName) async {
    return _queues[queueName]
        ?.where((entry) => entry.status == EntryStatus.deadLetter)
        .length ??
        0;
  }

  @override
  Future<List<QueueEntry<T>>> listDeadLetters<T>(
    String queueName, {
    int? limit,
    int? offset,
  }) async {
    final entries = _queues[queueName]
        ?.where((entry) => entry.status == EntryStatus.deadLetter)
        .toList() ??
        [];

    final start = offset ?? 0;
    final end = (limit != null) ? start + limit : entries.length;
    // Rebuild the entry around its payload rather than casting the entry
    // itself. The real backends reconstruct entries out of JSON, so a
    // QueueEntry<Object?> holding a String satisfies a caller asking for
    // QueueEntry<String>; casting the whole entry does not.
    return entries
        .skip(start)
        .take(end - start)
        .map((e) => e.withData(e.data as T))
        .toList();
  }

  @override
  Future<int> purgeDeadLetters(String queueName, DateTime cutoff) async {
    final queue = _queues[queueName];
    if (queue == null) return 0;

    final beforeCount = queue.length;
    queue.removeWhere((entry) =>
        entry.status == EntryStatus.deadLetter &&
        entry.lastUpdatedAt.isBefore(cutoff));
    return beforeCount - queue.length;
  }

  @override
  Future<void> removeDeadLetter(String queueName, String entryId) async {
    final queue = _queues[queueName];
    if (queue != null) {
      queue.removeWhere((entry) =>
          entry.id == entryId && entry.status == EntryStatus.deadLetter);
    }
  }

  @override
  Future<void> retryDeadLetter(String queueName, String entryId) async {
    final queue = _queues[queueName];
    if (queue != null) {
      final index = queue.indexWhere((entry) =>
          entry.id == entryId && entry.status == EntryStatus.deadLetter);
      if (index != -1) {
        final entry = queue[index];
        queue[index] = entry.copyWith(
          status: EntryStatus.pending,
          lastUpdatedAt: DateTime.now(),
          attempts: 0,
        );
      }
    }
  }

  @override
  Future<QueueEntry<T>?> retrieveDeadLetter<T>(String queueName) async {
    final entries = await listDeadLetters<T>(queueName, limit: 1);
    return entries.isEmpty ? null : entries.first;
  }

  /// Whether [close] has been called.
  bool get isClosed => _closed;
  bool _closed = false;

  @override
  Future<void> close() async {
    _closed = true;
  }

  @override
  Future<void> ping() async {
    if (_closed) {
      throw StateError('Cannot use a closed MockStorage');
    }
    if (!_pingSuccess) {
      throw _pingError ?? Exception('Mock ping failure');
    }
  }

  @override
  Future<List<QueueEntry<dynamic>>> retrieveAll(String queueName) async {
    return _queues[queueName]?.toList() ?? [];
  }

  /// Deletes finished entries, so the mock answers the same calls the real
  /// backends do. Nothing here has a lease, so nothing is ever reclaimed.
  @override
  Future<MaintenanceReport> runMaintenance({
    RetentionPolicy policy = const RetentionPolicy(),
    String? queueName,
  }) async {
    final now = DateTime.now();
    final names = queueName != null ? [queueName] : _queues.keys.toList();

    var expired = 0;
    var removed = 0;
    for (final name in names) {
      final entries = _queues[name];
      if (entries == null) continue;

      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        if (entry.status == EntryStatus.pending && entry.isExpired) {
          entries[i] = entry.copyWith(
            status: EntryStatus.expired,
            lastUpdatedAt: now,
          );
          expired++;
        }
      }

      removed += entries.length;
      entries.removeWhere((entry) {
        final age = policy.forStatus(entry.status);
        return age != null && now.difference(entry.lastUpdatedAt) > age;
      });
      removed -= entries.length;
    }

    return MaintenanceReport(expired: expired, removed: removed);
  }
} 