import 'dart:io';
import 'package:duraq/duraq.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

void main() {
  group('SQLite Transaction Support', () {
    late SQLiteStorage storage;
    late String dbPath;
    late Directory tempDir;

    /// A program that opens the database and prints how many rows it holds.
    ///
    /// Durability is about what survives this process ending, so the check has
    /// to come from outside it.
    late String readerScript;

    /// This package's resolved dependencies, so the child can import duraq.
    final packageConfig =
        path.join(Directory.current.path, '.dart_tool', 'package_config.json');

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('duraq_test_');
      dbPath = path.join(tempDir.path, 'duraq_test.db');
      storage = SQLiteStorage(dbPath: dbPath);

      readerScript = path.join(tempDir.path, 'read_back.dart');
      // Writes to a file rather than stdout: the Dart toolchain prints its own
      // lines there ("Running build hooks..."), which would end up parsed as
      // part of the answer.
      File(readerScript).writeAsStringSync('''
import 'dart:io';

import 'package:duraq/duraq.dart';

Future<void> main(List<String> args) async {
  final storage = SQLiteStorage(dbPath: args[0]);
  final entries = await storage.retrieveAll('test-queue');
  File(args[1]).writeAsStringSync('\${entries.length}');
  storage.dispose();
}
''');
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

      // Both transactions' work must be there in full. Asserting
      // `futures.length` proved nothing: Future.wait on two futures returns
      // two results whatever the database did, so this passed throughout the
      // period when overlapping transactions rolled back each other's
      // committed rows (finding C1).
      expect(futures, hasLength(2));
      final ids = (await storage.retrieveAll('test-queue'))
          .map((entry) => entry.id)
          .toSet();
      expect(ids, containsAll(<String>['id2', 'id3']),
          reason: 'neither transaction may discard the other\'s work');

      // Durability: the rows have to be in the file, not just in this
      // process's memory. Reopening through SQLiteStorage here would prove
      // little — the same process, and much of it the same cache — so a
      // separate OS process reads the file back.
      final expected = (await storage.retrieveAll('test-queue')).length;
      storage.dispose();

      final answerFile = path.join(tempDir.path, 'count.txt');
      final reader = await Process.run(
        Platform.resolvedExecutable,
        ['run', '--packages=$packageConfig', readerScript, dbPath, answerFile],
      );
      expect(reader.exitCode, isZero,
          reason: 'reader process failed: ${reader.stderr}');
      expect(int.parse(File(answerFile).readAsStringSync().trim()),
          equals(expected),
          reason: 'every committed row should be readable by another process');

      storage = SQLiteStorage(dbPath: dbPath);
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