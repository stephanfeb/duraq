import 'dart:io';

import 'package:duraq/duraq.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// Regression tests for C1 and C2.
///
/// Both defects came from the same cause: transaction depth was tracked with a
/// single counter while `transaction()` was asynchronous, so callers that
/// overlapped nested inside each other's transactions by accident.
void main() {
  group('Concurrent access to SQLiteStorage', () {
    late SQLiteStorage storage;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('duraq_serial_');
      storage = SQLiteStorage(
        dbPath: path.join(tempDir.path, 'duraq_test.db'),
      );
    });

    tearDown(() {
      storage.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    QueueEntry<String> entry(String id) => QueueEntry<String>(
          id: id,
          data: 'payload-$id',
          createdAt: DateTime.now(),
        );

    test('a failing transaction does not roll back a concurrent one', () async {
      final committing = storage.transaction(() async {
        await storage.store('test-queue', entry('keep-me'));
        // Yield, so an interleaving implementation has every chance to nest the
        // other transaction inside this one.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return 'committed';
      });

      final failing = storage.transaction(() async {
        await storage.store('test-queue', entry('discard-me'));
        throw StateError('simulated failure');
      });

      await expectLater(failing, throwsStateError);
      expect(await committing, equals('committed'));

      final ids = (await storage.retrieveAll('test-queue'))
          .map((e) => e.id)
          .toSet();
      expect(ids, contains('keep-me'));
      expect(ids, isNot(contains('discard-me')));
    });

    test('concurrent transactions all commit their own work', () async {
      await Future.wait(
        List.generate(
          12,
          (i) => storage.transaction(() async {
            await storage.store('test-queue', entry('e$i'));
            await Future<void>.delayed(const Duration(milliseconds: 1));
            return null;
          }),
        ),
      );

      expect(await storage.count('test-queue'), equals(12));
    });

    test('concurrent retrievals hand out every entry exactly once', () async {
      const total = 25;
      for (var i = 0; i < total; i++) {
        await storage.store('test-queue', entry('e$i'));
      }

      final retrieved = await Future.wait(
        List.generate(total * 2, (_) => storage.retrieve('test-queue')),
      );

      final delivered = retrieved.whereType<QueueEntry>().toList();
      expect(delivered.length, equals(total));
      expect(delivered.map((e) => e.id).toSet().length, equals(total));
    });

    test('a retrieval never reports empty while entries are still pending',
        () async {
      for (var i = 0; i < 5; i++) {
        await storage.store('test-queue', entry('e$i'));
      }

      // Five concurrent consumers against five entries: none of them may be
      // told the queue is empty.
      final firstRound = await Future.wait(
        List.generate(5, (_) => storage.retrieve('test-queue')),
      );
      expect(firstRound.whereType<QueueEntry>().length, equals(5));

      final leftPending = (await storage.retrieveAll('test-queue'))
          .where((e) => e.status == EntryStatus.pending);
      expect(leftPending, isEmpty);
    });

    test('operations inside a transaction body do not deadlock', () async {
      final result = await storage.transaction(() async {
        await storage.store('test-queue', entry('inner'));
        final count = await storage.count('test-queue');
        final all = await storage.retrieveAll('test-queue');
        await storage.transaction(() async {
          await storage.store('test-queue', entry('nested'));
          return null;
        });
        return [count, all.length];
      }).timeout(const Duration(seconds: 5));

      expect(result, equals([1, 1]));
      expect(await storage.count('test-queue'), equals(2));
    });

    test('the storage stays usable after a transaction body throws', () async {
      await expectLater(
        storage.transaction(() async => throw StateError('boom')),
        throwsStateError,
      );

      await storage
          .store('test-queue', entry('after'))
          .timeout(const Duration(seconds: 5));
      expect(await storage.count('test-queue'), equals(1));
    });

    test('a manual transaction waits for work already in flight', () async {
      final inFlight = storage.transaction(() async {
        await storage.store('test-queue', entry('first'));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return null;
      });

      // Must queue behind the transaction above rather than nesting into it.
      await storage.beginTransaction().timeout(const Duration(seconds: 5));
      final seenAtStart = await storage.count('test-queue');
      await storage.store('test-queue', entry('second'));
      await storage.commitTransaction();

      await inFlight;

      expect(seenAtStart, equals(1),
          reason: 'the in-flight transaction should have committed first');
      expect(await storage.count('test-queue'), equals(2));
    });

    test('work queued behind a manual transaction runs after it commits',
        () async {
      await storage.beginTransaction();
      await storage.store('test-queue', entry('manual'));
      await storage.commitTransaction();

      // The critical section is free again.
      await storage
          .transaction(() async {
            await storage.store('test-queue', entry('later'));
            return null;
          })
          .timeout(const Duration(seconds: 5));

      expect(await storage.count('test-queue'), equals(2));
    });
  });
}
