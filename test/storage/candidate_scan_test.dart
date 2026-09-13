import 'dart:io';

import 'package:duraq/duraq.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// Regression tests for H4.
///
/// Retrieval used to sweep every pending entry in the queue before looking for
/// work, and then walk candidates one row at a time with a growing offset.
/// Neither is required for correctness, and both grew with the backlog.
void main() {
  group('Candidate selection in SQLiteStorage', () {
    late Directory tempDir;
    late String dbPath;
    late SQLiteStorage storage;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('duraq_candidates_');
      dbPath = path.join(tempDir.path, 'duraq_test.db');
      storage = SQLiteStorage(dbPath: dbPath);
    });

    tearDown(() {
      storage.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    /// Stores [count] entries with strictly increasing creation times, so the
    /// retrieval order is deterministic.
    Future<void> storeOrdered(String queueName, int count) async {
      final base = DateTime.now().subtract(Duration(seconds: count + 1));
      await storage.transaction(() async {
        for (var i = 0; i < count; i++) {
          await storage.store(
            queueName,
            QueueEntry<String>(
              id: 'e$i',
              data: 'payload-$i',
              createdAt: base.add(Duration(seconds: i)),
            ),
          );
        }
        return null;
      });
    }

    test('entries come back in priority then creation order', () async {
      await storeOrdered('test-queue', 5);

      for (var i = 0; i < 5; i++) {
        final claimed = await storage.retrieve('test-queue');
        expect(claimed?.id, equals('e$i'));
        await storage.updateEntryStatus(
            'test-queue', claimed!.id, EntryStatus.completed);
      }
    });

    test('a candidate locked by another consumer is skipped', () async {
      await storeOrdered('test-queue', 4);

      // Another consumer holds a lock on the first two entries while they are
      // still pending, as a second process would.
      final other = sqlite3.open(dbPath);
      addTearDown(other.dispose);
      final otherLock = QueueLock(other);
      await otherLock.tryAcquire('test-queue', 'e0');
      await otherLock.tryAcquire('test-queue', 'e1');

      final claimed = await storage.retrieve('test-queue');
      expect(claimed?.id, equals('e2'));
    });

    test('the walk continues past the first batch of locked candidates',
        () async {
      // More locked candidates than the batch the retrieval reads at a time,
      // so finding the free entry requires a second batch.
      const locked = 18;
      await storeOrdered('test-queue', locked + 2);

      final other = sqlite3.open(dbPath);
      addTearDown(other.dispose);
      final otherLock = QueueLock(other);
      for (var i = 0; i < locked; i++) {
        expect(await otherLock.tryAcquire('test-queue', 'e$i'), isNotNull);
      }

      final claimed = await storage.retrieve('test-queue');
      expect(claimed?.id, equals('e$locked'));
    });

    test('null is returned when every candidate is locked', () async {
      await storeOrdered('test-queue', 3);

      final other = sqlite3.open(dbPath);
      addTearDown(other.dispose);
      final otherLock = QueueLock(other);
      for (var i = 0; i < 3; i++) {
        await otherLock.tryAcquire('test-queue', 'e$i');
      }

      expect(await storage.retrieve('test-queue'), isNull);
    });

    test('retrieval still marks expired entries as expired', () async {
      await storage.store(
        'test-queue',
        QueueEntry<String>(
          id: 'alive',
          data: 'still good',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      // Stored with a future expiry, then moved into the past, so the entry
      // lands in the table as pending and only the sweep can expire it.
      final db = sqlite3.open(dbPath);
      addTearDown(db.dispose);
      db.execute(
        'INSERT INTO queue_entries (id, queue_name, data, created_at, '
        'updated_at, expires_at, attempts, priority, status) '
        'VALUES (?, ?, ?, ?, ?, ?, 0, 0, ?)',
        [
          'stale',
          'test-queue',
          '"gone"',
          DateTime.now().millisecondsSinceEpoch,
          DateTime.now().millisecondsSinceEpoch,
          DateTime.now()
              .subtract(const Duration(minutes: 1))
              .millisecondsSinceEpoch,
          EntryStatus.pending.name,
        ],
      );

      final claimed = await storage.retrieve('test-queue');
      expect(claimed?.id, equals('alive'));

      final stale = (await storage.retrieveAll('test-queue'))
          .firstWhere((e) => e.id == 'stale');
      expect(stale.status, equals(EntryStatus.expired));
    });
  });
}
