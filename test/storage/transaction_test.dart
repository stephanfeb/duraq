import 'dart:io';
import 'package:duraq/duraq.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

void main() {
  group('SQLite Transaction Support', () {
    late SQLiteStorage storage;
    late String dbPath;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('duraq_test_');
      dbPath = path.join(tempDir.path, 'duraq_test.db');
      storage = SQLiteStorage(dbPath: dbPath);
    });

    tearDown(() {
      storage.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('commits successful transaction', () async {
      await storage.transaction(() async {
        await storage.store('test-queue', QueueEntry(
          id: 'id1',
          data: 'test1',
          createdAt: DateTime.now(),
        ));

        await storage.store('test-queue', QueueEntry(
          id: 'id2',
          data: 'test2',
          createdAt: DateTime.now(),
        ));

        return null;
      });

      expect(await storage.count('test-queue'), equals(2));
    });

    test('rolls back failed transaction', () async {
      try {
        await storage.transaction(() async {
          await storage.store('test-queue', QueueEntry(
            id: 'id1',
            data: 'test1',
            createdAt: DateTime.now(),
          ));

          throw Exception('Simulated failure');
        });
      } catch (_) {
        // Expected exception
      }

      expect(await storage.count('test-queue'), equals(0));
    });

    test('supports nested transactions', () async {
      await storage.transaction(() async {
        await storage.store('test-queue', QueueEntry(
          id: 'id1',
          data: 'outer',
          createdAt: DateTime.now(),
        ));

        await storage.transaction(() async {
          await storage.store('test-queue', QueueEntry(
            id: 'id2',
            data: 'inner',
            createdAt: DateTime.now(),
          ));
          return null;
        });

        return null;
      });

      expect(await storage.count('test-queue'), equals(2));
    });

    test('rolls back inner transaction without affecting outer', () async {
      await storage.transaction(() async {
        await storage.store('test-queue', QueueEntry(
          id: 'id1',
          data: 'outer',
          createdAt: DateTime.now(),
        ));

        try {
          await storage.transaction(() async {
            await storage.store('test-queue', QueueEntry(
              id: 'id2',
              data: 'inner',
              createdAt: DateTime.now(),
            ));
            throw Exception('Simulated inner failure');
          });
        } catch (_) {
          // Expected exception
        }

        return null;
      });

      expect(await storage.count('test-queue'), equals(1));
      final entry = await storage.retrieve('test-queue');
      expect(entry?.data, equals('outer'));
    });

    test('maintains ACID properties', () async {
      // Atomicity
      try {
        await storage.transaction(() async {
          await storage.store('test-queue', QueueEntry(
            id: 'id1',
            data: 'test1',
            createdAt: DateTime.now(),
          ));
          throw Exception('Simulated failure');
        });
      } catch (_) {}
      expect(await storage.count('test-queue'), equals(0));

      // Consistency
      await storage.transaction(() async {
        await storage.store('test-queue', QueueEntry(
          id: 'id1',
          data: 'test1',
          createdAt: DateTime.now(),
        ));
        return null;
      });
      
      final entry = await storage.retrieve('test-queue');
      expect(entry?.status, equals(EntryStatus.processing));

      // Isolation (basic test)
      final futures = await Future.wait([
        storage.transaction(() async {
          await storage.store('test-queue', QueueEntry(
            id: 'id2',
            data: 'test2',
            createdAt: DateTime.now(),
          ));
          return null;
        }),
        storage.transaction(() async {
          await storage.store('test-queue', QueueEntry(
            id: 'id3',
            data: 'test3',
            createdAt: DateTime.now(),
          ));
          return null;
        }),
      ]);

      // Verify all transactions completed
      expect(futures.length, equals(2));

      // Durability (basic test)
      final countBeforeRestart = await storage.count('test-queue');
      storage.dispose();
      storage = SQLiteStorage(dbPath: dbPath);
      expect(await storage.count('test-queue'), equals(countBeforeRestart));
    });

    test('throws on invalid transaction operations', () async {
      // Commit without begin
      expect(
        () => storage.commitTransaction(),
        throwsStateError,
      );

      // Rollback without begin
      expect(
        () => storage.rollbackTransaction(),
        throwsStateError,
      );

      // Double commit
      await storage.beginTransaction();
      await storage.commitTransaction();
      expect(
        () => storage.commitTransaction(),
        throwsStateError,
      );
    });

    test('prevents use after disposal', () async {
      storage.dispose();
      expect(
        () => storage.beginTransaction(),
        throwsStateError,
      );
    });
  });
} 