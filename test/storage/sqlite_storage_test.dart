import 'dart:io';
import 'package:duraq/duraq.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

void main() {
  group('SQLiteStorage', () {
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

    group('Basic Operations', () {
      test('stores and retrieves entries', () async {
        final entry = QueueEntry<String>(
          id: 'test1',
          data: 'test data',
          createdAt: DateTime.now(),
        );

        await storage.store('test-queue', entry);
        final retrieved = await storage.retrieve('test-queue');

        expect(retrieved?.id, equals('test1'));
        expect(retrieved?.data, equals('test data'));
      });

      test('handles entry expiration', () async {
        final entry = QueueEntry<String>(
          id: 'test1',
          data: 'test data',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(Duration(hours: 1)),
        );

        await storage.store('test-queue', entry);
        final retrieved = await storage.retrieve('test-queue');

        expect(retrieved?.id, equals('test1'));
        expect(retrieved?.data, equals('test data'));
      });

      test('expires entries', () async {
        final entry = QueueEntry<String>(
          id: 'test1',
          data: 'test data',
          createdAt: DateTime.now().subtract(Duration(hours: 2)),
          expiresAt: DateTime.now().subtract(Duration(hours: 1)),
        );

        await storage.store('test-queue', entry);
        final retrieved = await storage.retrieve('test-queue');

        expect(retrieved, isNull);
      });

      test('handles multiple expiration times', () async {
        final entry1 = QueueEntry<String>(
          id: 'test1',
          data: 'test data 1',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(Duration(hours: 2)),
        );

        final entry2 = QueueEntry<String>(
          id: 'test2',
          data: 'test data 2',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(Duration(hours: 1)),
        );

        await storage.store('test-queue', entry1);
        await storage.store('test-queue', entry2);

        expect(await storage.count('test-queue'), equals(2));
      });

      test('cleans up expired entries', () async {
        final entry = QueueEntry<String>(
          id: 'test1',
          data: 'test data',
          createdAt: DateTime.now().subtract(Duration(hours: 25)),
          expiresAt: DateTime.now().subtract(Duration(hours: 24)),
        );

        await storage.store('test-queue', entry);
        final removed = await storage.cleanupExpiredEntries();

        expect(removed, equals(1));
        expect(await storage.count('test-queue'), equals(0));
      });
    });
  });
} 