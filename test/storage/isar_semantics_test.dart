import 'dart:io';

import 'package:duraq/duraq.dart';
import 'package:duraq/src/storage/isar_models.dart';
import 'package:isar/isar.dart';
import 'package:test/test.dart';

import '../utils/isar_test_core.dart';

/// Regression tests for C5, C6 and H5.
///
/// The Isar backend used to add a row per store rather than per entry, treat
/// transactions as a counter that guaranteed nothing, and run every query as a
/// full collection scan.
void main() {
  group('IsarStorage semantics', () {
    late IsarStorage storage;
    late Isar isar;
    late String tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('duraq_isar_sem_').path;
      await ensureIsarCore();
      isar = await Isar.open(
        IsarStorage.requiredSchemas,
        directory: tempDir,
        name: 'semantics_test',
      );
      storage = IsarStorage(isar);
    });

    tearDown(() async {
      await storage.dispose();
      await isar.close();
      try {
        await Directory(tempDir).delete(recursive: true);
      } catch (_) {
        // Ignore cleanup errors
      }
    });

    QueueEntry<String> entry(String id, {String data = 'payload'}) =>
        QueueEntry<String>(id: id, data: data, createdAt: DateTime.now());

    group('entry identity (C5)', () {
      test('storing the same entry twice keeps one row', () async {
        await storage.store('test-queue', entry('same-id'));
        await storage.store('test-queue', entry('same-id'),
            onConflict: StoreConflict.replace);
        await storage.store('test-queue', entry('same-id'),
            onConflict: StoreConflict.replace);

        expect(await isar.queueEntryCollections.count(), equals(1));
        expect(await storage.count('test-queue'), equals(1));
      });

      test('a re-stored entry is delivered once, not once per store',
          () async {
        final queue = Queue<String>('test-queue', storage);
        await storage.store('test-queue', entry('same-id'));
        await storage.store('test-queue', entry('same-id'),
            onConflict: StoreConflict.replace);

        var delivered = 0;
        for (var i = 0; i < 4; i++) {
          final handled = await queue.processNext((_) => delivered++);
          if (!handled) break;
        }

        expect(delivered, equals(1));
      });

      test('a re-store updates the entry rather than adding another',
          () async {
        await storage.store('test-queue', entry('same-id', data: 'first'));
        await storage.store('test-queue', entry('same-id', data: 'second'),
            onConflict: StoreConflict.replace);

        final stored = await storage.retrieveAll('test-queue');
        expect(stored, hasLength(1));
        expect(stored.single.data, equals('second'));
      });

      test('an entry id already used by another queue is a conflict', () async {
        // Entry ids are unique across the storage, matching SQLite, where the
        // entry id is the table's primary key.
        await storage.store('queue-a', entry('shared-id'));

        await expectLater(
          storage.store('queue-b', entry('shared-id')),
          throwsA(isA<DuplicateEntryException>()),
        );

        expect(await isar.queueEntryCollections.count(), equals(1));
        expect(await storage.count('queue-a'), equals(1));
        expect(await storage.count('queue-b'), equals(0));
      });

      test('duplicates written by an earlier version can be collapsed',
          () async {
        // Write rows the way the previous implementation did: a fresh row per
        // store, with no identity check.
        await isar.writeTxn(() async {
          for (var i = 0; i < 3; i++) {
            await isar.queueEntryCollections.put(
              QueueEntryCollection()
                ..entryId = 'legacy-id'
                ..queueName = 'test-queue'
                ..data = '"payload $i"'
                ..createdAt = DateTime.now()
                ..lastUpdatedAt = DateTime.now().add(Duration(seconds: i))
                ..attempts = 0
                ..priority = 0
                ..status = EntryStatus.pending,
            );
          }
        });
        expect(await isar.queueEntryCollections.count(), equals(3));

        expect(await storage.removeDuplicateEntries(), equals(2));

        final remaining = await storage.retrieveAll('test-queue');
        expect(remaining, hasLength(1));
        expect(remaining.single.data, equals('payload 2'),
            reason: 'the most recently updated row is the one kept');
      });
    });

    group('transactions (C6)', () {
      test('a transaction that throws leaves nothing behind', () async {
        await expectLater(
          storage.transaction(() async {
            await storage.store('test-queue', entry('a'));
            await storage.store('test-queue', entry('b'));
            throw StateError('simulated failure');
          }),
          throwsStateError,
        );

        expect(await storage.retrieveAll('test-queue'), isEmpty);
      });

      test('a transaction that returns commits everything in it', () async {
        await storage.transaction(() async {
          await storage.store('test-queue', entry('a'));
          await storage.store('test-queue', entry('b'));
          return null;
        });

        expect(await storage.count('test-queue'), equals(2));
      });

      test('a nested transaction joins the one already running', () async {
        await storage
            .transaction(() async {
              await storage.store('test-queue', entry('outer'));
              await storage.transaction(() async {
                await storage.store('test-queue', entry('inner'));
                return null;
              });
              return null;
            })
            .timeout(const Duration(seconds: 5));

        expect(await storage.count('test-queue'), equals(2));
      });

      test('a failure rolls back work from before the failing step', () async {
        await storage.store('test-queue', entry('existing'));

        await expectLater(
          storage.transaction(() async {
            await storage.updateEntryStatus(
                'test-queue', 'existing', EntryStatus.completed);
            await storage.store('test-queue', entry('added'));
            throw StateError('simulated failure');
          }),
          throwsStateError,
        );

        final remaining = await storage.retrieveAll('test-queue');
        expect(remaining, hasLength(1));
        expect(remaining.single.status, equals(EntryStatus.pending),
            reason: 'the status change must have been rolled back too');
      });

      test('the manual transaction API reports that it is unsupported',
          () async {
        await expectLater(
            storage.beginTransaction(), throwsA(isA<UnsupportedError>()));
        await expectLater(
            storage.commitTransaction(), throwsA(isA<UnsupportedError>()));
        await expectLater(
            storage.rollbackTransaction(), throwsA(isA<UnsupportedError>()));
      });
    });

    group('index-backed queries (H5)', () {
      test('retrieval order is priority, then creation time', () async {
        final base = DateTime.now().subtract(const Duration(minutes: 10));
        await storage.transaction(() async {
          for (var i = 0; i < 6; i++) {
            await storage.store(
              'test-queue',
              QueueEntry<String>(
                id: 'e$i',
                data: 'payload-$i',
                createdAt: base.add(Duration(seconds: i)),
                priority: i.isEven ? 5 : 1,
              ),
            );
          }
          return null;
        });

        final order = <String>[];
        for (var i = 0; i < 6; i++) {
          final claimed = await storage.retrieve('test-queue');
          order.add(claimed!.id);
          await storage.updateEntryStatus(
              'test-queue', claimed.id, EntryStatus.completed);
        }

        expect(order, equals(['e1', 'e3', 'e5', 'e0', 'e2', 'e4']));
      });

      test('one queue never sees another queue\'s entries', () async {
        await storage.store('queue-a', entry('a1'));
        await storage.store('queue-b', entry('b1'));
        await storage.store('queue-b', entry('b2'));

        expect(await storage.count('queue-a'), equals(1));
        expect(await storage.count('queue-b'), equals(2));
        expect((await storage.retrieve('queue-a'))?.id, equals('a1'));
        expect(await storage.retrieve('queue-a'), isNull);
      });

      test('an entry without a deadline is never treated as expired',
          () async {
        await storage.store('test-queue', entry('no-ttl'));
        await storage.store(
          'test-queue',
          QueueEntry<String>(
            id: 'with-ttl',
            data: 'payload',
            createdAt: DateTime.now(),
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        );

        expect((await storage.retrieve('test-queue'))?.id, equals('no-ttl'));
        expect((await storage.retrieve('test-queue'))?.id, equals('with-ttl'));

        final statuses = {
          for (final e in await storage.retrieveAll('test-queue'))
            e.id: e.status
        };
        expect(statuses['no-ttl'], equals(EntryStatus.processing));
        expect(statuses['with-ttl'], equals(EntryStatus.processing));
      });

      test('dead letters are still listed oldest first', () async {
        for (var i = 0; i < 3; i++) {
          await storage.store('test-queue', entry('e$i'));
          await storage.updateEntryStatus(
              'test-queue', 'e$i', EntryStatus.deadLetter);
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }

        final listed = await storage.listDeadLetters<String>('test-queue');
        expect(listed.map((e) => e.id), equals(['e0', 'e1', 'e2']));
        expect((await storage.retrieveDeadLetter<String>('test-queue'))?.id,
            equals('e0'));
      });
    });
  });
}
