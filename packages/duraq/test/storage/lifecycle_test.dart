import 'dart:io';

import 'package:duraq/duraq.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../utils/mock_storage.dart';

/// Regression tests for M11 and M14.
///
/// M11: neither `dispose` nor `close` appeared on `StorageInterface`, and the
/// two backends disagreed on the shape of it — SQLite's was synchronous and
/// returned void, Isar's was asynchronous — so shutdown could not be written
/// without knowing which backend was underneath.
///
/// M14: write-ahead logging ran at `synchronous = NORMAL` with no way to ask
/// for more. That is a reasonable default, but a queue that has accepted a job
/// can lose it when the machine goes down, and the package never said so.
void main() {
  group('backend-agnostic teardown', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('duraq_lifecycle_');
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // Ignore cleanup errors
      }
    });

    QueueEntry<String> entry(String id) => QueueEntry<String>(
          id: id,
          data: 'payload-$id',
          createdAt: DateTime.now(),
        );

    /// Shutdown written once, against the interface. This is the function that
    /// could not be written before.
    Future<void> shutDown(StorageInterface storage) => storage.close();

    test('a SQLite storage closes through the interface', () async {
      final storage = SQLiteStorage(
        dbPath: path.join(tempDir.path, 'duraq_test.db'),
      );
      await storage.store('q', entry('e1'));

      await shutDown(storage);

      await expectLater(storage.count('q'), throwsStateError);
    });

    test('closing twice is not an error', () async {
      final storage = SQLiteStorage(
        dbPath: path.join(tempDir.path, 'twice.db'),
      );

      await storage.close();
      await expectLater(storage.close(), completes);
    });

    test('close and dispose are the same shutdown', () async {
      final storage = SQLiteStorage(
        dbPath: path.join(tempDir.path, 'both.db'),
      );

      storage.dispose();
      // The older name still works, and close on an already-disposed storage
      // has nothing left to do.
      await expectLater(storage.close(), completes);
    });

    test('a custom backend answers to it too', () async {
      // The worked example: MockStorage implements StorageInterface, so the
      // teardown has to be reachable there as well.
      final storage = MockStorage();
      await shutDown(storage);

      expect(storage.isClosed, isTrue);
      await expectLater(storage.ping(), throwsStateError);
    });
  });

  group('SQLite durability setting', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('duraq_sync_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    SQLiteStorage open(String name, {SqliteSynchronous? synchronous}) {
      final storage = SQLiteStorage(
        dbPath: path.join(tempDir.path, '$name.db'),
        synchronous: synchronous ?? SqliteSynchronous.normal,
      );
      addTearDown(storage.dispose);
      return storage;
    }

    test('defaults to NORMAL, which is what earlier releases used', () {
      final storage = open('default');

      expect(storage.synchronous, equals(SqliteSynchronous.normal));
      expect(storage.activeSynchronous, equals(SqliteSynchronous.normal));
    });

    test('every setting reaches the connection', () {
      for (final mode in SqliteSynchronous.values) {
        final storage = open('mode_${mode.name}', synchronous: mode);

        expect(storage.activeSynchronous, equals(mode),
            reason: '${mode.name} was asked for but not applied');
      }
    });

    test('the setting belongs to the connection, not the file', () {
      final dbPath = path.join(tempDir.path, 'shared.db');
      final careful = SQLiteStorage(
        dbPath: dbPath,
        synchronous: SqliteSynchronous.full,
      );
      addTearDown(careful.dispose);
      final quick = SQLiteStorage(
        dbPath: dbPath,
        synchronous: SqliteSynchronous.off,
      );
      addTearDown(quick.dispose);

      // Unlike journal_mode, which is a property of the file, this is per
      // connection: one process asking for FULL does not make another careful.
      expect(careful.activeSynchronous, equals(SqliteSynchronous.full));
      expect(quick.activeSynchronous, equals(SqliteSynchronous.off));
    });

    test('a queue still works at the strictest setting', () async {
      final storage = open('full', synchronous: SqliteSynchronous.full);
      final queue = Queue<String>('jobs', storage);

      await queue.enqueue('work');
      expect(await queue.processNext((_) {}), isTrue);
      expect(await queue.readyLength, equals(0));
    });

    test('the pragma value and code stay in step', () {
      expect(SqliteSynchronous.off.pragmaValue, equals('OFF'));
      expect(SqliteSynchronous.off.pragmaCode, equals(0));
      expect(SqliteSynchronous.normal.pragmaCode, equals(1));
      expect(SqliteSynchronous.full.pragmaCode, equals(2));
      expect(SqliteSynchronous.extra.pragmaCode, equals(3));
    });
  });
}
