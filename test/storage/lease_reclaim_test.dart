import 'dart:io';

import 'package:duraq/duraq.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../utils/isar_test_core.dart';

/// Regression tests for C4, and for H1 which the reclaim depends on.
///
/// A consumer that dies without acknowledging its entry used to strand it in
/// `processing` forever. Retrieval now takes back any entry whose lease has
/// expired, and parks one that has been delivered too many times.
void main() {
  QueueEntry<String> entry(String id) => QueueEntry<String>(
        id: id,
        data: 'payload-$id',
        createdAt: DateTime.now(),
      );

  group('Lease reclaim on SQLiteStorage', () {
    late Directory tempDir;
    late String dbPath;
    late SQLiteStorage storage;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('duraq_lease_');
      dbPath = path.join(tempDir.path, 'duraq_test.db');
      storage = SQLiteStorage(
        dbPath: dbPath,
        leaseDuration: const Duration(milliseconds: 200),
      );
    });

    tearDown(() {
      storage.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('an entry is not reclaimed while its lease is live', () async {
      await storage.store('test-queue', entry('e1'));

      final claimed = await storage.retrieve('test-queue');
      expect(claimed?.id, equals('e1'));

      // The lease has not expired, so nobody else may have it.
      expect(await storage.retrieve('test-queue'), isNull);
      expect(await storage.reclaimStaleEntries(), equals(0));
    });

    test('an entry whose consumer died is handed out again', () async {
      await storage.store('test-queue', entry('e1'));

      final claimed = await storage.retrieve('test-queue');
      expect(claimed?.id, equals('e1'));
      // The consumer dies here: no completion, no failure, no acknowledgement.

      await Future<void>.delayed(const Duration(milliseconds: 300));

      final redelivered = await storage.retrieve('test-queue');
      expect(redelivered?.id, equals('e1'));
      expect(redelivered?.attempts, equals(1),
          reason: 'a reclaimed delivery counts as an attempt');
    });

    test('a stranded entry is visible to the queue again', () async {
      final queue = Queue<String>('test-queue', storage);
      await queue.enqueue('work');

      await storage.retrieve('test-queue');
      expect(await queue.length, equals(0));

      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(await storage.reclaimStaleEntries(), equals(1));
      expect(await queue.length, equals(1));
    });

    test('reclaim recovers entries left behind by a previous run', () async {
      await storage.store('test-queue', entry('e1'));
      await storage.store('test-queue', entry('e2'));
      await storage.retrieve('test-queue');
      await storage.retrieve('test-queue');

      // Simulate a restart against the same database file.
      storage.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      storage = SQLiteStorage(
        dbPath: dbPath,
        leaseDuration: const Duration(milliseconds: 200),
      );

      expect(await storage.reclaimStaleEntries(), equals(2));

      final ids = <String>{};
      ids.add((await storage.retrieve('test-queue'))!.id);
      ids.add((await storage.retrieve('test-queue'))!.id);
      expect(ids, equals({'e1', 'e2'}));
    });

    test('reclaim can be limited to one queue', () async {
      await storage.store('queue-a', entry('a1'));
      await storage.store('queue-b', entry('b1'));
      await storage.retrieve('queue-a');
      await storage.retrieve('queue-b');

      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(await storage.reclaimStaleEntries(queueName: 'queue-a'),
          equals(1));
      expect(await storage.reclaimStaleEntries(queueName: 'queue-a'),
          equals(0));
      expect(await storage.reclaimStaleEntries(queueName: 'queue-b'),
          equals(1));
    });

    test('an entry that keeps killing its consumer is dead lettered',
        () async {
      final storage = SQLiteStorage(
        dbPath: path.join(tempDir.path, 'poison.db'),
        leaseDuration: const Duration(milliseconds: 50),
        maxDeliveryAttempts: 3,
      );
      addTearDown(storage.dispose);

      await storage.store('test-queue', entry('poison'));

      // Each round is a consumer that takes the entry and dies. The budget
      // allows three deliveries, and the expiry after the last one parks it.
      for (var i = 0; i < 3; i++) {
        final claimed = await storage.retrieve('test-queue');
        expect(claimed?.id, equals('poison'),
            reason: 'delivery ${i + 1} should still be offered');
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }

      // The budget is used up, so the entry is parked instead of redelivered.
      expect(await storage.retrieve('test-queue'), isNull);
      expect(await storage.countDeadLetters('test-queue'), equals(1));

      final parked = await storage.retrieveDeadLetter<String>('test-queue');
      expect(parked?.id, equals('poison'));
      expect(parked?.errorMessage, contains('Lease expired'));
    });

    test('disposing one consumer does not free another consumer\'s entry',
        () async {
      // Two storage instances on the same database file, as two processes or
      // isolates would be.
      final other = SQLiteStorage(
        dbPath: dbPath,
        leaseDuration: const Duration(minutes: 5),
      );
      addTearDown(other.dispose); // dispose is idempotent

      await storage.store('test-queue', entry('e1'));
      await storage.store('test-queue', entry('e2'));

      final mine = await storage.retrieve('test-queue');
      final theirs = await other.retrieve('test-queue');
      expect({mine?.id, theirs?.id}, equals({'e1', 'e2'}));

      // One consumer shuts down cleanly. The other is still working.
      other.dispose();

      final afterShutdown = await storage.retrieveAll('test-queue');
      final stillClaimed = afterShutdown
          .where((e) => e.id == mine!.id && e.status == EntryStatus.processing);
      expect(stillClaimed, hasLength(1),
          reason: "the surviving consumer's entry must stay claimed");
    });
  });

  group('Lease reclaim on IsarStorage', () {
    late IsarStorage storage;
    late Isar isar;
    late String tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('duraq_lease_isar_').path;
      await ensureIsarCore();
      isar = await Isar.open(
        IsarStorage.requiredSchemas,
        directory: tempDir,
        name: 'lease_test',
      );
      storage = IsarStorage(
        isar,
        leaseDuration: const Duration(milliseconds: 200),
      );
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

    test('an entry is not reclaimed while its lease is live', () async {
      await storage.store('test-queue', entry('e1'));

      expect((await storage.retrieve('test-queue'))?.id, equals('e1'));
      expect(await storage.retrieve('test-queue'), isNull);
      expect(await storage.reclaimStaleEntries(), equals(0));
    });

    test('an entry whose consumer died is handed out again', () async {
      await storage.store('test-queue', entry('e1'));
      expect((await storage.retrieve('test-queue'))?.id, equals('e1'));

      await Future<void>.delayed(const Duration(milliseconds: 300));

      final redelivered = await storage.retrieve('test-queue');
      expect(redelivered?.id, equals('e1'));
      expect(redelivered?.attempts, equals(1));
    });

    test('reclaim recovers stranded entries and reports the count', () async {
      await storage.store('test-queue', entry('e1'));
      await storage.retrieve('test-queue');
      expect(await storage.count('test-queue'), equals(0));

      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(await storage.reclaimStaleEntries(), equals(1));
      expect(await storage.count('test-queue'), equals(1));
    });
  });
}
