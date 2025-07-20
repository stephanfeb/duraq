import 'package:test/test.dart';
import 'package:duraq/src/queue_entry.dart';
import 'package:duraq/src/storage/sqlite_storage.dart';
import 'dart:io';

void main() {
  late SQLiteStorage storage;
  late File dbFile;

  setUp(() async {
    dbFile = File('test/test_concurrent.db');
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

  group('Concurrent Processing Tests', () {
    test('should prevent concurrent processing of same entry', () async {
      final now = DateTime.now();
      final entry = QueueEntry<String>(
        id: 'test-entry-1',
        data: 'test data',
        createdAt: now,
      );

      await storage.store('test-queue', entry);

      // First retrieval should succeed
      final retrieved1 = await storage.retrieve('test-queue');
      expect(retrieved1?.id, equals('test-entry-1'));

      // Second retrieval should return null (entry is locked)
      final retrieved2 = await storage.retrieve('test-queue');
      expect(retrieved2, isNull);
    });

    test('should allow processing different entries concurrently', () async {
      final now = DateTime.now();
      final entry1 = QueueEntry<String>(
        id: 'test-entry-1',
        data: 'test data 1',
        createdAt: now,
      );

      final entry2 = QueueEntry<String>(
        id: 'test-entry-2',
        data: 'test data 2',
        createdAt: now,
      );

      await storage.store('test-queue', entry1);
      await storage.store('test-queue', entry2);

      // Both entries should be retrievable
      final retrieved1 = await storage.retrieve('test-queue');
      expect(retrieved1?.id, equals('test-entry-1'));

      final retrieved2 = await storage.retrieve('test-queue');
      expect(retrieved2?.id, equals('test-entry-2'));
    });

    test('should release lock when processing completes', () async {
      final now = DateTime.now();
      final entry = QueueEntry<String>(
        id: 'test-entry-1',
        data: 'test data',
        createdAt: now,
      );

      await storage.store('test-queue', entry);

      // First retrieval
      final retrieved1 = await storage.retrieve('test-queue');
      expect(retrieved1?.id, equals('test-entry-1'));

      // Mark as completed
      await storage.updateEntryStatus(
        'test-queue',
        'test-entry-1',
        EntryStatus.completed,
      );

      // Should be able to retrieve next entry (if it existed)
      final retrieved2 = await storage.retrieve('test-queue');
      expect(retrieved2, isNull); // null because no more entries
    });

    test('should release lock when processing fails', () async {
      final now = DateTime.now();
      final entry = QueueEntry<String>(
        id: 'test-entry-1',
        data: 'test data',
        createdAt: now,
      );

      await storage.store('test-queue', entry);

      // First retrieval
      final retrieved1 = await storage.retrieve('test-queue');
      expect(retrieved1?.id, equals('test-entry-1'));

      // Mark as failed
      await storage.updateEntryStatus(
        'test-queue',
        'test-entry-1',
        EntryStatus.failed,
        errorMessage: 'Test error',
      );

      // Should be able to retrieve next entry (if it existed)
      final retrieved2 = await storage.retrieve('test-queue');
      expect(retrieved2, isNull); // null because no more entries
    });

    test('should handle multiple concurrent queue operations', () async {
      final now = DateTime.now();
      final entries = List.generate(5, (i) => QueueEntry<String>(
        id: 'test-entry-$i',
        data: 'test data $i',
        createdAt: now,
      ));

      // Store all entries
      await Future.wait(
        entries.map((e) => storage.store('test-queue', e))
      );

      // Try to retrieve all entries concurrently
      final retrievedEntries = await Future.wait(
        List.generate(10, (_) => storage.retrieve('test-queue'))
      );

      // Should only get 5 non-null entries (one for each stored entry)
      final nonNullEntries = retrievedEntries.where((e) => e != null).toList();
      expect(nonNullEntries.length, equals(5));

      // Each entry should be retrieved exactly once
      final retrievedIds = nonNullEntries.map((e) => e!.id).toSet();
      expect(retrievedIds.length, equals(5));
      for (var i = 0; i < 5; i++) {
        expect(retrievedIds.contains('test-entry-$i'), isTrue);
      }
    });
  });
} 