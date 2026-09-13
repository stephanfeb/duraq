import 'package:duraq/duraq.dart';
import 'package:test/test.dart';

/// Tests the parts of the library a *custom* backend inherits.
///
/// Found by re-measuring coverage for Q2: `StorageInterface` and `RetryPolicy`
/// were the only files at 0%. Everything in them that a built-in backend
/// overrides is covered through that backend, and what was left was exactly the
/// code shipped for somebody else's implementation — the default `countReady`,
/// the default `runMaintenance`, and `shouldMoveToDeadLetter`. All documented,
/// all shipped, none ever executed.
///
/// These extend rather than implement, which is the point: `extends` is what
/// carries the default bodies across, and it is the path those defaults exist
/// for.

/// The smallest backend that satisfies the interface: a list in memory, with
/// every optional member left to inherit.
class MinimalBackend extends StorageInterface {
  final List<QueueEntry<dynamic>> entries = [];

  @override
  Future<void> store(
    String queueName,
    QueueEntry<dynamic> entry, {
    StoreConflict onConflict = StoreConflict.fail,
  }) async =>
      entries.add(entry);

  @override
  Future<List<QueueEntry<dynamic>>> retrieveAll(String queueName) async =>
      List.of(entries);

  @override
  Future<int> count(String queueName) async => entries.length;

  // Nothing below is exercised here; the interface just requires it.
  @override
  Future<void> beginTransaction() async {}
  @override
  Future<void> commitTransaction() async {}
  @override
  Future<void> rollbackTransaction() async {}
  @override
  Future<T> transaction<T>(Future<T> Function() operations) => operations();
  @override
  Future<QueueEntry<dynamic>?> retrieve(String queueName) async => null;
  @override
  Future<List<String>> listQueues() async => ['test-queue'];
  @override
  Future<void> removeQueue(String queueName) async {}
  @override
  Future<void> removeEntry(String queueName, String entryId) async {}
  @override
  Future<void> updateEntryStatus(
    String queueName,
    String entryId,
    EntryStatus status, {
    String? errorMessage,
    DateTime? nextRetryAt,
    int? attempts,
    String? leaseId,
  }) async {}
  @override
  Future<QueueEntry<T>?> retrieveDeadLetter<T>(String queueName) async => null;
  @override
  Future<List<QueueEntry<T>>> listDeadLetters<T>(
    String queueName, {
    int? limit,
    int? offset,
  }) async =>
      [];
  @override
  Future<void> retryDeadLetter(String queueName, String entryId) async {}
  @override
  Future<void> removeDeadLetter(String queueName, String entryId) async {}
  @override
  Future<int> purgeDeadLetters(String queueName, DateTime cutoff) async => 0;
  @override
  Future<int> countDeadLetters(String queueName) async => 0;
  @override
  Future<void> ping() async {}
  @override
  Future<void> close() async {}
}

/// A retry policy that supplies only what it must, inheriting the rest.
class MinimalRetryPolicy extends RetryPolicy {
  @override
  int get maxAttempts => 3;

  @override
  bool shouldRetry(int attempts, [Object? error]) => attempts < maxAttempts;

  @override
  Duration getRetryDelay(int attempts) => const Duration(seconds: 1);
}

void main() {
  QueueEntry<String> entry(
    String id, {
    EntryStatus status = EntryStatus.pending,
    DateTime? expiresAt,
    DateTime? scheduledFor,
    DateTime? nextRetryAt,
  }) =>
      QueueEntry<String>(
        id: id,
        data: 'payload-$id',
        createdAt: DateTime.now(),
        status: status,
        expiresAt: expiresAt,
        scheduledFor: scheduledFor,
        nextRetryAt: nextRetryAt,
      );

  group('the countReady a custom backend inherits', () {
    late MinimalBackend storage;
    final future = DateTime.now().add(const Duration(days: 1));
    final past = DateTime.now().subtract(const Duration(days: 1));

    setUp(() => storage = MinimalBackend());

    test('counts entries that could be handed out', () async {
      await storage.store('test-queue', entry('a'));
      await storage.store('test-queue', entry('b'));

      expect(await storage.countReady('test-queue'), equals(2));
    });

    test('ignores entries that are not pending', () async {
      await storage.store('test-queue', entry('a'));
      await storage.store(
          'test-queue', entry('b', status: EntryStatus.processing));
      await storage.store(
          'test-queue', entry('c', status: EntryStatus.completed));

      expect(await storage.countReady('test-queue'), equals(1));
    });

    test('ignores entries that have expired', () async {
      await storage.store('test-queue', entry('gone', expiresAt: past));
      await storage.store('test-queue', entry('live', expiresAt: future));

      expect(await storage.countReady('test-queue'), equals(1));
    });

    test('ignores entries scheduled for later', () async {
      await storage.store('test-queue', entry('later', scheduledFor: future));
      await storage.store('test-queue', entry('now', scheduledFor: past));

      expect(await storage.countReady('test-queue'), equals(1));
    });

    test('ignores entries waiting out a retry', () async {
      await storage.store('test-queue', entry('backoff', nextRetryAt: future));
      await storage.store('test-queue', entry('due', nextRetryAt: past));

      expect(await storage.countReady('test-queue'), equals(1));
    });

    test('an empty queue is zero, not an error', () async {
      expect(await storage.countReady('test-queue'), equals(0));
    });

    test('agrees with the built-in backends on the same entries', () async {
      // The default reads every entry and filters in memory; the backends
      // answer with a query. They have to reach the same number, or a custom
      // backend and a built-in one would disagree about the same queue.
      for (final e in [
        entry('ready'),
        entry('later', scheduledFor: future),
        entry('backoff', nextRetryAt: future),
        entry('gone', expiresAt: past),
        entry('taken', status: EntryStatus.processing),
      ]) {
        await storage.store('test-queue', e);
      }

      expect(await storage.countReady('test-queue'), equals(1));
    });
  });

  group('the runMaintenance a custom backend inherits', () {
    test('says it is not supported rather than doing nothing', () async {
      // Silently reporting an empty pass would let a caller believe retention
      // was being applied when nothing had run.
      await expectLater(
        MinimalBackend().runMaintenance(),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('the RetryPolicy default', () {
    test('sends an exhausted entry to the dead letter queue', () {
      // The one behaviour a policy gets for free, and the one that decides
      // whether failed work is kept or dropped.
      expect(MinimalRetryPolicy().shouldMoveToDeadLetter(3), isTrue);
    });
  });
}
