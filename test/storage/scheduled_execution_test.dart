import 'package:test/test.dart';
import 'package:duraq/src/queue_entry.dart';
import 'package:duraq/src/storage/sqlite_storage.dart';
import 'package:duraq/src/storage/storage_interface.dart';
import 'dart:io';

void main() {
  late SQLiteStorage storage;
  late File dbFile;

  setUp(() async {
    dbFile = File('test/test_scheduled.db');
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

  group('Scheduled Execution Tests', () {
    test('should store and retrieve entry with scheduled time', () async {
      final now = DateTime.now();
      final scheduledTime = now.add(Duration(hours: 1));
      final entry = QueueEntry<Map<String, String>>(
        id: 'test-scheduled-1',
        data: {'data': 'test'},
        createdAt: now,
        scheduledFor: scheduledTime,
      );

      await storage.store('test-queue', entry);
      
      // We'll verify the scheduled time by checking that it's not retrieved yet
      final retrieved = await storage.retrieve('test-queue');
      expect(retrieved, isNull, reason: 'Entry should not be retrieved before scheduled time');
    });

    test('should not return entries scheduled for future', () async {
      final now = DateTime.now();
      final futureTime = now.add(Duration(hours: 1));
      final entry = QueueEntry<Map<String, String>>(
        id: 'test-scheduled-2',
        data: {'data': 'future'},
        createdAt: now,
        scheduledFor: futureTime,
      );

      await storage.store('test-queue', entry);
      final dequeued = await storage.retrieve('test-queue');
      
      expect(dequeued, isNull);
    });

    test('should return entry when scheduled time has passed', () async {
      final now = DateTime.now();
      final pastTime = now.subtract(Duration(minutes: 5));
      final entry = QueueEntry<Map<String, String>>(
        id: 'test-scheduled-3',
        data: {'data': 'past'},
        createdAt: now,
        scheduledFor: pastTime,
      );

      await storage.store('test-queue', entry);
      final dequeued = await storage.retrieve('test-queue');
      
      expect(dequeued, isNotNull);
      expect(dequeued!.id, equals('test-scheduled-3'));
    });

    test('should respect priority order for scheduled entries', () async {
      final now = DateTime.now();
      final pastTime = now.subtract(Duration(minutes: 5));
      
      final entry1 = QueueEntry<Map<String, String>>(
        id: 'test-scheduled-4',
        data: {'data': 'priority-1'},
        createdAt: now,
        scheduledFor: pastTime,
        priority: 1,
      );

      final entry2 = QueueEntry<Map<String, String>>(
        id: 'test-scheduled-5',
        data: {'data': 'priority-0'},
        createdAt: now,
        scheduledFor: pastTime,
        priority: 0,
      );

      await storage.store('test-queue', entry1);
      await storage.store('test-queue', entry2);
      
      final dequeued = await storage.retrieve('test-queue');
      expect(dequeued, isNotNull);
      expect(dequeued!.id, equals('test-scheduled-5')); // Should get priority 0 first
    });
  });
} 