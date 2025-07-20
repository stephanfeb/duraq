import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'package:isar/isar.dart';
import '../../lib/src/storage/isar_storage.dart';
import '../../lib/src/queue_entry.dart';

void main() {
  group('IsarStorage', () {
    late IsarStorage storage;
    late Isar isar;
    late String tempDir;

    setUp(() async {
      // Create a temporary directory for test databases
      tempDir = Directory.systemTemp.createTempSync('isar_test_').path;
      
      // Initialize Isar core
      await Isar.initializeIsarCore(download: true);
      
      // Create Isar instance with required schemas
      isar = await Isar.open(
        IsarStorage.requiredSchemas,
        directory: tempDir,
        name: 'test_queue',
      );
      
      // Create storage with external Isar instance
      storage = IsarStorage(isar);
    });

    tearDown(() async {
      await storage.dispose();
      await isar.close();
      // Clean up temporary directory
      try {
        await Directory(tempDir).delete(recursive: true);
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test('should store and retrieve queue entries', () async {
      const queueName = 'test_queue';
      final entry = QueueEntry(
        id: 'test_entry_1',
        data: 'Hello, Isar!',
        createdAt: DateTime.now(),
      );

      // Store entry
      await storage.store(queueName, entry);

      // Retrieve entry
      final retrieved = await storage.retrieve(queueName);

      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals(entry.id));
      expect(retrieved.data, equals(entry.data));
      expect(retrieved.status, equals(EntryStatus.processing));
    });

    test('should count queue entries correctly', () async {
      const queueName = 'count_test';
      
      // Initially empty
      expect(await storage.count(queueName), equals(0));

      // Add some entries
      for (int i = 0; i < 5; i++) {
        final entry = QueueEntry(
          id: 'entry_$i',
          data: 'Data $i',
          createdAt: DateTime.now(),
        );
        await storage.store(queueName, entry);
      }

      expect(await storage.count(queueName), equals(5));
    });

    test('should handle priority ordering', () async {
      const queueName = 'priority_test';
      
      // Add entries with different priorities
      final lowPriority = QueueEntry(
        id: 'low',
        data: 'Low priority',
        createdAt: DateTime.now(),
        priority: 10,
      );
      
      final highPriority = QueueEntry(
        id: 'high',
        data: 'High priority',
        createdAt: DateTime.now(),
        priority: 1,
      );

      await storage.store(queueName, lowPriority);
      await storage.store(queueName, highPriority);

      // High priority should be retrieved first
      final first = await storage.retrieve(queueName);
      expect(first!.id, equals('high'));
    });

    test('should support transactions', () async {
      const queueName = 'transaction_test';
      
      await storage.transaction(() async {
        final entry1 = QueueEntry(
          id: 'tx_entry_1',
          data: 'Transaction data 1',
          createdAt: DateTime.now(),
        );
        
        final entry2 = QueueEntry(
          id: 'tx_entry_2',
          data: 'Transaction data 2',
          createdAt: DateTime.now(),
        );

        await storage.store(queueName, entry1);
        await storage.store(queueName, entry2);
        
        return null;
      });

      expect(await storage.count(queueName), equals(2));
    });

    test('should handle dead letter operations', () async {
      const queueName = 'dead_letter_test';
      
      final entry = QueueEntry(
        id: 'dead_entry',
        data: 'Failed entry',
        createdAt: DateTime.now(),
        status: EntryStatus.deadLetter,
        errorMessage: 'Processing failed',
      );

      await storage.store(queueName, entry);

      // Retrieve dead letter
      final deadLetter = await storage.retrieveDeadLetter<String>(queueName);
      expect(deadLetter, isNotNull);
      expect(deadLetter!.id, equals('dead_entry'));
      expect(deadLetter.status, equals(EntryStatus.deadLetter));

      // Count dead letters
      expect(await storage.countDeadLetters(queueName), equals(1));

      // Retry dead letter
      await storage.retryDeadLetter(queueName, 'dead_entry');
      expect(await storage.countDeadLetters(queueName), equals(0));
    });

    test('should handle queue management', () async {
      const queueName1 = 'queue1';
      const queueName2 = 'queue2';
      
      // Add entries to different queues
      await storage.store(queueName1, QueueEntry(
        id: 'entry1',
        data: 'Data 1',
        createdAt: DateTime.now(),
      ));
      
      await storage.store(queueName2, QueueEntry(
        id: 'entry2',
        data: 'Data 2',
        createdAt: DateTime.now(),
      ));

      // List queues
      final queues = await storage.listQueues();
      expect(queues, contains(queueName1));
      expect(queues, contains(queueName2));

      // Remove a queue
      await storage.removeQueue(queueName1);
      final remainingQueues = await storage.listQueues();
      expect(remainingQueues, isNot(contains(queueName1)));
      expect(remainingQueues, contains(queueName2));
    });

    test('should respond to ping', () async {
      // Should not throw
      await storage.ping();
    });
  });
}
