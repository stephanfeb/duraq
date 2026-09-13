import 'package:duraq/duraq.dart';
import 'package:test/test.dart';

import 'storage_backend.dart';

/// Regression tests for H2.
///
/// Acquiring a claim generated a lock id, returned it, and then nobody kept it.
/// Release deleted whatever lock was on the entry, so a consumer whose lease
/// had expired released its successor's lock and marked the entry finished
/// while that successor was still working on it.

  QueueEntry<String> entry(String id) => QueueEntry<String>(
        id: id,
        data: 'payload-$id',
        createdAt: DateTime.now(),
      );

  /// Retrieves as soon as an entry becomes available, giving up after [limit].
  Future<QueueEntry<dynamic>?> retrieveWithin(
    StorageInterface storage,
    String queueName,
    Duration limit,
  ) async {
    final deadline = DateTime.now().add(limit);
    while (DateTime.now().isBefore(deadline)) {
      final claimed = await storage.retrieve(queueName);
      if (claimed != null) return claimed;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return null;
  }

void leaseSuite(String backend, StorageOpener open) {
    group('$backend lease ownership', () {
      late StorageInterface storage;
      late Future<void> Function() close;

      Future<void> useStorage(Duration lease) async {
        final opened = await open(leaseDuration: lease);
        storage = opened.storage;
        close = opened.close;
      }

      setUp(() => useStorage(const Duration(minutes: 5)));
      tearDown(() => close());

      test('a claimed entry carries the lease it was claimed under', () async {
        await storage.store('test-queue', entry('e1'));

        final claimed = await storage.retrieve('test-queue');
        expect(claimed?.leaseId, isNotNull);

        // Reading entries is not claiming them, so those carry no lease.
        final listed = await storage.retrieveAll('test-queue');
        expect(listed.single.leaseId, isNull);
      });

      test('two claims of the same entry get different leases', () async {
        await close();
        await useStorage(const Duration(milliseconds: 100));
        await storage.store('test-queue', entry('e1'));

        final first = await storage.retrieve('test-queue');
        final second = await retrieveWithin(
          storage,
          'test-queue',
          const Duration(seconds: 5),
        );

        expect(second, isNotNull);
        expect(second!.id, equals(first!.id));
        expect(second.leaseId, isNot(equals(first.leaseId)));
      });

      test('a consumer whose lease expired cannot complete the entry',
          () async {
        await close();
        await useStorage(const Duration(milliseconds: 100));
        await storage.store('test-queue', entry('e1'));

        // The slow consumer takes the entry and is still working on it.
        final slow = await storage.retrieve('test-queue');

        // Its lease expires and the entry is handed to someone else.
        final fast = await retrieveWithin(
          storage,
          'test-queue',
          const Duration(seconds: 5),
        );
        expect(fast, isNotNull);

        // The slow consumer finishes and reports success against a lease that
        // is no longer the live one.
        await storage.updateEntryStatus(
          'test-queue',
          'e1',
          EntryStatus.completed,
          leaseId: slow!.leaseId,
        );

        final stored = (await storage.retrieveAll('test-queue')).single;
        expect(stored.status, equals(EntryStatus.processing),
            reason: 'the entry belongs to the consumer still working on it');
      });

      test('a stale lease does not release the new holder\'s claim', () async {
        await close();
        await useStorage(const Duration(seconds: 30));
        await storage.store('test-queue', entry('e1'));

        final slow = await storage.retrieve('test-queue');
        // Force the handover without waiting out a long lease.
        await storage.updateEntryStatus(
            'test-queue', 'e1', EntryStatus.pending);
        final fast = await storage.retrieve('test-queue');
        expect(fast?.leaseId, isNot(equals(slow?.leaseId)));

        await storage.updateEntryStatus(
          'test-queue',
          'e1',
          EntryStatus.completed,
          leaseId: slow!.leaseId,
        );

        // If the stale release had gone through, the entry would be offered
        // again while its holder is still working.
        expect(await storage.retrieve('test-queue'), isNull);
      });

      test('the live lease completes the entry normally', () async {
        await storage.store('test-queue', entry('e1'));

        final claimed = await storage.retrieve('test-queue');
        await storage.updateEntryStatus(
          'test-queue',
          'e1',
          EntryStatus.completed,
          leaseId: claimed!.leaseId,
        );

        final stored = (await storage.retrieveAll('test-queue')).single;
        expect(stored.status, equals(EntryStatus.completed));
      });

      test('an update without a lease still applies unconditionally',
          () async {
        await storage.store('test-queue', entry('e1'));
        await storage.retrieve('test-queue');

        // Administrative changes do not hold a claim and must still work.
        await storage.updateEntryStatus(
            'test-queue', 'e1', EntryStatus.deadLetter);

        expect(await storage.countDeadLetters('test-queue'), equals(1));
      });

      test('processing through the queue passes the lease for you', () async {
        final queue = Queue<String>('test-queue', storage);
        await queue.enqueue('work');

        expect(await queue.processNext((_) {}), isTrue);

        final stored = (await storage.retrieveAll('test-queue')).single;
        expect(stored.status, equals(EntryStatus.completed));
      });

      test('a failure through the queue also carries the lease', () async {
        final queue = Queue<String>('test-queue', storage);
        await queue.enqueue('work');

        await expectLater(
          queue.processNext((_) => throw StateError('boom')),
          throwsStateError,
        );

        final stored = (await storage.retrieveAll('test-queue')).single;
        expect(stored.status, equals(EntryStatus.deadLetter),
            reason: 'no retry policy means the first failure parks the entry');
      });
    });
  }
