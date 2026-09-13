import 'package:duraq/duraq.dart';
import 'package:test/test.dart';

import 'storage_backend.dart';

/// Regression tests for H6 and H7.
///
/// Both backends have to answer these the same way. They used to disagree
/// about storing an entry whose id was already taken, one throwing a raw driver
/// exception with the payload in its text and the other silently adding a
/// second row, and neither offered any way to remove finished entries.

  QueueEntry<String> entry(
    String id, {
    String data = 'payload',
    EntryStatus status = EntryStatus.pending,
    DateTime? lastUpdatedAt,
    DateTime? expiresAt,
  }) =>
      QueueEntry<String>(
        id: id,
        data: data,
        createdAt: DateTime.now(),
        lastUpdatedAt: lastUpdatedAt,
        status: status,
        expiresAt: expiresAt,
      );

  /// The behaviour every backend has to provide, run against each of them.
void contractSuite(String backend, StorageOpener open) {
    group('$backend storage contract', () {
      late StorageInterface storage;
      late Future<void> Function() close;

      Future<void> useStorage({Duration? leaseDuration}) async {
        final opened = await open(leaseDuration: leaseDuration);
        storage = opened.storage;
        close = opened.close;
      }

      setUp(() => useStorage());
      tearDown(() => close());

      group('storing an entry whose id is taken (H7)', () {
        test('throws a DuplicateEntryException by default', () async {
          await storage.store('test-queue', entry('taken', data: 'original'));

          await expectLater(
            storage.store('test-queue', entry('taken', data: 'replacement')),
            throwsA(isA<DuplicateEntryException>()),
          );

          final stored = await storage.retrieveAll('test-queue');
          expect(stored, hasLength(1));
          expect(stored.single.data, equals('original'));
        });

        test('the error names the queue and id, and is a DuraQException',
            () async {
          await storage.store('test-queue', entry('taken'));

          try {
            await storage.store('test-queue', entry('taken'));
            fail('storing a taken id should have thrown');
          } on DuplicateEntryException catch (e) {
            expect(e, isA<DuraQException>());
            expect(e.queueName, equals('test-queue'));
            expect(e.entryId, equals('taken'));
          }
        });

        test('the error does not carry the entry payload', () async {
          const secret = 'card-number-4111111111111111';
          await storage.store('test-queue', entry('taken', data: secret));

          try {
            await storage.store('test-queue', entry('taken', data: secret));
            fail('storing a taken id should have thrown');
          } on DuplicateEntryException catch (e) {
            expect(e.toString(), isNot(contains(secret)));
            expect(e.message, isNot(contains(secret)));
          }
        });

        test('replace overwrites the stored entry', () async {
          await storage.store('test-queue', entry('taken', data: 'original'));

          await storage.store(
            'test-queue',
            entry('taken', data: 'replacement'),
            onConflict: StoreConflict.replace,
          );

          final stored = await storage.retrieveAll('test-queue');
          expect(stored, hasLength(1));
          expect(stored.single.data, equals('replacement'));
        });

        test('ignore keeps the stored entry and does not throw', () async {
          await storage.store('test-queue', entry('taken', data: 'original'));

          await storage.store(
            'test-queue',
            entry('taken', data: 'replacement'),
            onConflict: StoreConflict.ignore,
          );

          final stored = await storage.retrieveAll('test-queue');
          expect(stored, hasLength(1));
          expect(stored.single.data, equals('original'));
        });

        test('an id taken by another queue is a conflict too', () async {
          // Entry ids are unique across the storage, not per queue.
          await storage.store('queue-a', entry('shared'));

          await expectLater(
            storage.store('queue-b', entry('shared')),
            throwsA(isA<DuplicateEntryException>()),
          );
        });

        test('a fresh id is stored normally', () async {
          await storage.store('test-queue', entry('one'));
          await storage.store('test-queue', entry('two'));

          expect(await storage.count('test-queue'), equals(2));
        });
      });

      group('maintenance (H6)', () {
        test('removes completed entries past their retention', () async {
          await storage.store(
            'test-queue',
            entry('old',
                status: EntryStatus.completed,
                lastUpdatedAt: DateTime.now().subtract(Duration(days: 10))),
          );
          await storage.store(
            'test-queue',
            entry('recent',
                status: EntryStatus.completed,
                lastUpdatedAt: DateTime.now().subtract(Duration(hours: 1))),
          );

          final report = await storage.runMaintenance();

          expect(report.removed, equals(1));
          final left = await storage.retrieveAll('test-queue');
          expect(left.map((e) => e.id), equals(['recent']));
        });

        test('never removes work that is not finished', () async {
          final longAgo = DateTime.now().subtract(Duration(days: 400));
          await storage.store('test-queue',
              entry('waiting', lastUpdatedAt: longAgo));
          await storage.store(
            'test-queue',
            entry('claimed',
                status: EntryStatus.processing, lastUpdatedAt: longAgo),
          );

          await storage.runMaintenance();

          final left = await storage.retrieveAll('test-queue');
          expect(left.map((e) => e.id).toSet(), equals({'waiting', 'claimed'}));
        });

        test('dead letters are kept longer than completed entries', () async {
          final twoWeeksAgo = DateTime.now().subtract(Duration(days: 14));
          await storage.store('test-queue',
              entry('done', status: EntryStatus.completed, lastUpdatedAt: twoWeeksAgo));
          await storage.store('test-queue',
              entry('parked', status: EntryStatus.deadLetter, lastUpdatedAt: twoWeeksAgo));

          await storage.runMaintenance();

          final left = await storage.retrieveAll('test-queue');
          expect(left.map((e) => e.id), equals(['parked']));
        });

        test('keepEverything deletes nothing', () async {
          await storage.store(
            'test-queue',
            entry('ancient',
                status: EntryStatus.completed,
                lastUpdatedAt: DateTime.now().subtract(Duration(days: 400))),
          );

          final report = await storage.runMaintenance(
            policy: const RetentionPolicy.keepEverything(),
          );

          expect(report.removed, equals(0));
          expect(await storage.retrieveAll('test-queue'), hasLength(1));
        });

        test('marks entries that outlived their deadline', () async {
          await storage.store(
            'test-queue',
            entry('doomed',
                expiresAt: DateTime.now().add(Duration(milliseconds: 100))),
          );

          await Future<void>.delayed(const Duration(milliseconds: 200));
          final report = await storage.runMaintenance(
            policy: const RetentionPolicy.keepEverything(),
          );

          expect(report.expired, equals(1));
          final left = await storage.retrieveAll('test-queue');
          expect(left.single.status, equals(EntryStatus.expired));
        });

        test('returns entries whose consumer died', () async {
          await close();
          await useStorage(leaseDuration: const Duration(milliseconds: 100));

          await storage.store('test-queue', entry('claimed'));
          await storage.retrieve('test-queue');
          await Future<void>.delayed(const Duration(milliseconds: 200));

          final report = await storage.runMaintenance();

          expect(report.reclaimed, equals(1));
          expect(await storage.count('test-queue'), equals(1));
        });

        test('can be limited to a single queue', () async {
          final longAgo = DateTime.now().subtract(Duration(days: 10));
          await storage.store('queue-a',
              entry('a1', status: EntryStatus.completed, lastUpdatedAt: longAgo));
          await storage.store('queue-b',
              entry('b1', status: EntryStatus.completed, lastUpdatedAt: longAgo));

          final report = await storage.runMaintenance(queueName: 'queue-a');

          expect(report.removed, equals(1));
          expect(await storage.retrieveAll('queue-a'), isEmpty);
          expect(await storage.retrieveAll('queue-b'), hasLength(1));
        });

        test('reports an empty pass when there is nothing to do', () async {
          await storage.store('test-queue', entry('waiting'));

          final report = await storage.runMaintenance();

          expect(report.isEmpty, isTrue);
          expect(await storage.count('test-queue'), equals(1));
        });
      });
    });
  }
