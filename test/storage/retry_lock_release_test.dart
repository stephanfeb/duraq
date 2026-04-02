import 'package:test/test.dart';
import 'package:duraq/src/queue_entry.dart';
import 'package:duraq/src/storage/sqlite_storage.dart';
import 'dart:io';

void main() {
  late SQLiteStorage storage;
  late File dbFile;

  setUp(() async {
    dbFile = File('test/test_retry_lock.db');
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
    storage = SQLiteStorage(dbPath: dbFile.path);
  });

  tearDown(() async {
    storage.dispose();
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
  });

  group('Lock release on retry (pending status)', () {
    test('should release lock when entry is set back to pending for retry', () async {
      final now = DateTime.now();
      final entry = QueueEntry<String>(
        id: 'retry-entry-1',
        data: 'broadcast data',
        createdAt: now,
      );

      await storage.store('broadcast-queue', entry);

      // Simulate processNext: retrieve acquires lock and sets status to processing
      final retrieved = await storage.retrieve('broadcast-queue');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('retry-entry-1'));

      // Simulate _handleFailure: set status back to pending for retry
      // (this is what duraq's Queue._handleFailure does when retries remain)
      await storage.updateEntryStatus(
        'broadcast-queue',
        'retry-entry-1',
        EntryStatus.pending,
        errorMessage: 'Connection refused',
        nextRetryAt: now.add(Duration(seconds: 10)),
        attempts: 1,
      );

      // The entry should now be retrievable again — lock should have been released
      final retried = await storage.retrieve('broadcast-queue');
      expect(retried, isNotNull, reason: 'Entry set back to pending should be retrievable after lock release');
      expect(retried!.id, equals('retry-entry-1'));
      expect(retried.attempts, equals(1));
    });

    test('processNext retry should allow subsequent processNext to succeed', () async {
      final now = DateTime.now();
      final entry = QueueEntry<String>(
        id: 'retry-entry-2',
        data: 'tx-hex-data',
        createdAt: now,
      );

      await storage.store('broadcast-queue', entry);

      // First retrieve + set back to pending (simulating failed processNext with retry)
      final first = await storage.retrieve('broadcast-queue');
      expect(first, isNotNull);

      await storage.updateEntryStatus(
        'broadcast-queue',
        'retry-entry-2',
        EntryStatus.pending,
        errorMessage: 'TLS handshake error',
        attempts: 1,
      );

      // Second retrieve should succeed — entry is pending and lock should be released
      final second = await storage.retrieve('broadcast-queue');
      expect(second, isNotNull, reason: 'Retried entry should be retrievable on next attempt');
      expect(second!.id, equals('retry-entry-2'));

      // Complete it successfully this time
      await storage.updateEntryStatus(
        'broadcast-queue',
        'retry-entry-2',
        EntryStatus.completed,
      );

      // No more entries
      final empty = await storage.retrieve('broadcast-queue');
      expect(empty, isNull);
    });
  });
}
