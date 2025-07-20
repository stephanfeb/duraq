import 'package:duraq/duraq.dart';

/// A mock implementation of StorageInterface for testing
class MockStorage implements StorageInterface {
  final Map<String, List<QueueEntry>> _queues = {};
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
  Future<QueueEntry?> retrieve(String queueName) async {
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
  Future<void> store(String queueName, QueueEntry entry) async {
    _queues.putIfAbsent(queueName, () => []).add(entry);
  }

  @override
  Future<void> updateEntryStatus(
    String queueName,
    String entryId,
    EntryStatus status, {
    String? errorMessage,
    DateTime? nextRetryAt,
  }) async {
    final queue = _queues[queueName];
    if (queue != null) {
      final index = queue.indexWhere((entry) => entry.id == entryId);
      if (index != -1) {
        final entry = queue[index];
        queue[index] = entry.copyWith(
          status: status,
          errorMessage: errorMessage,
          nextRetryAt: nextRetryAt,
          lastUpdatedAt: DateTime.now(),
          attempts: status == EntryStatus.deadLetter ? entry.attempts + 1 : entry.attempts,
        );
      }
    }
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
    return entries
        .skip(start)
        .take(end - start)
        .map((e) => e as QueueEntry<T>)
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
          nextRetryAt: null,
        );
      }
    }
  }

  @override
  Future<QueueEntry<T>?> retrieveDeadLetter<T>(String queueName) async {
    final entries = await listDeadLetters<T>(queueName, limit: 1);
    return entries.isEmpty ? null : entries.first;
  }

  @override
  Future<void> ping() async {
    if (!_pingSuccess) {
      throw _pingError ?? Exception('Mock ping failure');
    }
  }

  @override
  Future<List<QueueEntry>> retrieveAll(String queueName) async {
    return _queues[queueName]?.toList() ?? [];
  }
} 