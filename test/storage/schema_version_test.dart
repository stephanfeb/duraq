import 'dart:io';

import 'package:duraq/duraq.dart';
import 'package:duraq/src/storage/isar_models.dart';
import 'package:duraq/src/storage/sqlite_schema.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import '../utils/isar_test_core.dart';

/// Regression tests for M13.
///
/// Tables were created if absent and never versioned, so a new column or a new
/// status value had no safe way of reaching a database already in the field,
/// and a database written by a newer release was opened as if nothing had
/// changed. `EntryStatus.values.byName` threw an `ArgumentError` naming neither
/// the entry nor the reason.
void main() {
  group('SqliteSchema', () {
    late Directory tempDir;
    late Database db;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('duraq_schema_');
      db = sqlite3.open(path.join(tempDir.path, 'test.db'));
    });

    tearDown(() {
      db.dispose();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    /// A schema of three versions, so the walk is exercised with real steps
    /// rather than asserted against an empty map.
    SqliteSchema schemaTo(int version, {Map<int, void Function(Database)>? extra}) =>
        SqliteSchema(
          targetVersion: version,
          // Describes the current shape in one idempotent statement, the way
          // the real one does: it also runs against a database that already
          // has the tables, on the way up from an unversioned file.
          createCurrent: (db) {
            final columns = [
              'id INTEGER',
              if (version >= 2) 'colour TEXT',
              if (version >= 3) 'size INTEGER',
            ];
            db.execute(
                'CREATE TABLE IF NOT EXISTS widgets (${columns.join(', ')})');
          },
          looksUnversioned: (db) => db
              .select(
                "SELECT 1 FROM sqlite_master WHERE type='table' AND name='widgets'",
              )
              .isNotEmpty,
          migrations: extra ??
              {
                2: (db) =>
                    db.execute('ALTER TABLE widgets ADD COLUMN colour TEXT'),
                3: (db) =>
                    db.execute('ALTER TABLE widgets ADD COLUMN size INTEGER'),
              },
        );

    List<String> columnsOf(String table) => db
        .select('PRAGMA table_info($table)')
        .map((row) => row['name'] as String)
        .toList();

    test('creates a new database at the target version directly', () {
      schemaTo(3).applyTo(db);

      expect(SqliteSchema.versionOf(db), equals(3));
      expect(columnsOf('widgets'), containsAll(['id', 'colour', 'size']));
    });

    test('walks an unversioned database up, one step at a time', () {
      // What an older release left behind: the version-1 shape, no version.
      db.execute('CREATE TABLE widgets (id INTEGER)');
      db.execute('INSERT INTO widgets (id) VALUES (7)');
      expect(SqliteSchema.versionOf(db), equals(0));

      schemaTo(3).applyTo(db);

      expect(SqliteSchema.versionOf(db), equals(3));
      expect(columnsOf('widgets'), containsAll(['id', 'colour', 'size']));
      expect(db.select('SELECT id FROM widgets').single['id'], equals(7),
          reason: 'existing rows survive the migration');
    });

    test('runs only the steps a database still needs', () {
      schemaTo(1).applyTo(db);
      expect(SqliteSchema.versionOf(db), equals(1));

      final ran = <int>[];
      SqliteSchema(
        targetVersion: 3,
        createCurrent: (_) => fail('an existing database is not recreated'),
        looksUnversioned: (_) => true,
        migrations: {
          2: (db) {
            ran.add(2);
            db.execute('ALTER TABLE widgets ADD COLUMN colour TEXT');
          },
          3: (db) {
            ran.add(3);
            db.execute('ALTER TABLE widgets ADD COLUMN size INTEGER');
          },
        },
      ).applyTo(db);

      expect(ran, equals([2, 3]));
      expect(SqliteSchema.versionOf(db), equals(3));
    });

    test('a failing step rolls back and leaves the last version that applied',
        () {
      schemaTo(1).applyTo(db);

      final schema = SqliteSchema(
        targetVersion: 3,
        createCurrent: (_) {},
        looksUnversioned: (_) => true,
        migrations: {
          2: (db) => db.execute('ALTER TABLE widgets ADD COLUMN colour TEXT'),
          3: (db) {
            db.execute('ALTER TABLE widgets ADD COLUMN size INTEGER');
            throw StateError('migration blew up');
          },
        },
      );

      expect(() => schema.applyTo(db), throwsStateError);

      expect(SqliteSchema.versionOf(db), equals(2),
          reason: 'step 2 applied in full; step 3 did not');
      expect(columnsOf('widgets'), contains('colour'));
      expect(columnsOf('widgets'), isNot(contains('size')),
          reason: 'the failed step was rolled back');
    });

    test('a missing step is reported as the bug it is', () {
      schemaTo(1).applyTo(db);

      expect(
        () => SqliteSchema(
          targetVersion: 3,
          createCurrent: (_) {},
          looksUnversioned: (_) => true,
          migrations: {2: (db) => {}},
        ).applyTo(db),
        throwsA(isA<DuraQException>()
            .having((e) => e.message, 'message', contains('No migration'))),
      );
    });

    test('a database from a newer release is refused', () {
      schemaTo(3).applyTo(db);

      expect(
        () => schemaTo(1).applyTo(db, label: 'test.db'),
        throwsA(isA<SchemaVersionException>()
            .having((e) => e.found, 'found', 3)
            .having((e) => e.supported, 'supported', 1)
            .having((e) => e.message, 'message', contains('test.db'))),
      );
    });
  });

  group('SQLiteStorage schema version', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('duraq_schema_sqlite_');
      dbPath = path.join(tempDir.path, 'duraq_test.db');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    QueueEntry<String> entry(String id) => QueueEntry<String>(
          id: id,
          data: 'payload-$id',
          createdAt: DateTime.now(),
        );

    test('a new database records the current version', () {
      final storage = SQLiteStorage(dbPath: dbPath);
      addTearDown(storage.dispose);

      expect(storage.storedSchemaVersion, equals(SQLiteStorage.schemaVersion));
    });

    test('a database already in the field opens and is stamped', () async {
      var storage = SQLiteStorage(dbPath: dbPath);
      await storage.store('q', entry('e1'));
      storage.dispose();

      // What every release before this one left behind: the current shape with
      // no version recorded.
      final raw = sqlite3.open(dbPath);
      raw.execute('PRAGMA user_version = 0');
      raw.dispose();

      storage = SQLiteStorage(dbPath: dbPath);
      addTearDown(storage.dispose);

      expect(storage.storedSchemaVersion, equals(SQLiteStorage.schemaVersion));
      expect((await storage.retrieveAll('q')).single.data, equals('payload-e1'));
      await storage.store('q', entry('e2'));
      expect(await storage.count('q'), equals(2));
    });

    test('a database from a newer DuraQ is refused', () async {
      final storage = SQLiteStorage(dbPath: dbPath);
      await storage.store('q', entry('e1'));
      storage.dispose();

      final raw = sqlite3.open(dbPath);
      raw.execute('PRAGMA user_version = 99');
      raw.dispose();

      expect(
        () => SQLiteStorage(dbPath: dbPath),
        throwsA(isA<SchemaVersionException>()
            .having((e) => e.found, 'found', 99)
            .having((e) => e.supported, 'supported', SQLiteStorage.schemaVersion)),
      );
    });

    test('a status this release has no name for names the entry', () async {
      var storage = SQLiteStorage(dbPath: dbPath);
      await storage.store('q', entry('e1'));
      storage.dispose();

      final raw = sqlite3.open(dbPath);
      raw.execute("UPDATE queue_entries SET status = 'quarantined'");
      raw.dispose();

      storage = SQLiteStorage(dbPath: dbPath);
      addTearDown(storage.dispose);

      await expectLater(
        storage.retrieveAll('q'),
        throwsA(isA<SchemaVersionException>()
            .having((e) => e.message, 'message', contains('quarantined'))
            .having((e) => e.message, 'message', contains('e1'))),
      );
    });
  });

  group('IsarStorage schema version', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('duraq_schema_isar_');
      await ensureIsarCore();
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // Ignore cleanup errors
      }
    });

    Future<Isar> open(String name,
            {List<CollectionSchema<dynamic>>? schemas}) async =>
        Isar.open(
          schemas ?? IsarStorage.requiredSchemas,
          directory: tempDir.path,
          name: name,
        );

    /// The schema set that shipped before the version collection existed.
    final previousSchemas = [
      QueueCollectionSchema,
      QueueEntryCollectionSchema,
      QueueLockCollectionSchema,
    ];

    test('a new database records the current version on first use', () async {
      final isar = await open('fresh');
      final storage = IsarStorage(isar);
      addTearDown(() async {
        await storage.dispose();
        await isar.close();
      });

      await storage.store(
        'q',
        QueueEntry<String>(id: 'e1', data: 'x', createdAt: DateTime.now()),
      );

      expect(await storage.storedSchemaVersion(),
          equals(IsarStorage.schemaVersion));
    });

    test('a database written before the version collection existed still opens',
        () async {
      // Written by the previous release: its collections, its data, no version.
      var isar = await open('upgrade', schemas: previousSchemas);
      await isar.writeTxn(() async {
        await isar.queueCollections.put(QueueCollection()
          ..name = 'q'
          ..createdAt = DateTime.now()
          ..lastUpdatedAt = DateTime.now());
        await isar.queueEntryCollections.put(QueueEntryCollection()
          ..entryId = 'e1'
          ..queueName = 'q'
          ..data = '"payload"'
          ..createdAt = DateTime.now()
          ..lastUpdatedAt = DateTime.now()
          ..attempts = 0
          ..priority = 0
          ..status = EntryStatus.pending);
      });
      await isar.close();

      isar = await open('upgrade');
      final storage = IsarStorage(isar);
      addTearDown(() async {
        await storage.dispose();
        await isar.close();
      });

      expect((await storage.retrieveAll('q')).single.data, equals('payload'));
      expect(await storage.storedSchemaVersion(), equals(1));
      expect((await storage.retrieve('q'))?.id, equals('e1'),
          reason: 'the queue still serves work after the upgrade');
    });

    test('a database from a newer DuraQ is refused, on every operation',
        () async {
      final isar = await open('future');
      await isar.writeTxn(() => isar.queueMetaCollections.put(
            QueueMetaCollection()
              ..id = metaRowId
              ..schemaVersion = 99
              ..updatedAt = DateTime.now(),
          ));

      final storage = IsarStorage(isar);
      addTearDown(() async {
        await storage.dispose();
        await isar.close();
      });

      await expectLater(
        storage.count('q'),
        throwsA(isA<SchemaVersionException>()
            .having((e) => e.found, 'found', 99)),
      );
      await expectLater(
        storage.retrieveAll('q'),
        throwsA(isA<SchemaVersionException>()),
      );
    });

    test('an instance opened without the version collection says so', () async {
      final isar = await open('handwritten', schemas: previousSchemas);
      final storage = IsarStorage(isar);
      addTearDown(() async {
        await storage.dispose();
        await isar.close();
      });

      await expectLater(
        storage.count('q'),
        throwsA(isA<DuraQException>().having(
          (e) => e.message,
          'message',
          contains('requiredSchemas'),
        )),
      );
    });
  });
}
