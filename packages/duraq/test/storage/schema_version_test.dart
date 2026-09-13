// ignore_for_file: deprecated_member_use
// sqlite3 3.0 renamed Database.dispose to close, and 2.x — which this
// package still supports — has only dispose. These tests hold raw
// handles, so they use the name that works across the whole range.
import 'dart:io';

import 'package:duraq/duraq.dart';
import 'package:duraq/src/storage/sqlite_schema.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

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

  group('schema version 2: entry ids become per queue', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('duraq_schema_v2_');
      dbPath = path.join(tempDir.path, 'duraq_v1.db');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    /// Writes a genuine version 1 database: the shape duraq 2.0.0 shipped,
    /// where `id` is the primary key on its own.
    void writeVersion1Database({required List<(String, String)> entries}) {
      final raw = sqlite3.open(dbPath);
      raw.execute('CREATE TABLE queues (name TEXT PRIMARY KEY)');
      raw.execute('''
        CREATE TABLE queue_entries (
          id TEXT PRIMARY KEY,
          queue_name TEXT NOT NULL,
          data TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          expires_at INTEGER,
          scheduled_for INTEGER,
          next_retry_at INTEGER,
          attempts INTEGER NOT NULL DEFAULT 0,
          priority INTEGER NOT NULL DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'pending',
          error_message TEXT,
          FOREIGN KEY (queue_name) REFERENCES queues(name)
        )
      ''');
      raw.execute(
        'CREATE INDEX idx_queue_entries_retrieval '
        'ON queue_entries(queue_name, status, priority, created_at)',
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final (queue, id) in entries) {
        raw.execute('INSERT OR IGNORE INTO queues (name) VALUES (?)', [queue]);
        raw.execute(
          'INSERT INTO queue_entries (id, queue_name, data, created_at, '
          'updated_at, attempts, priority, status) '
          'VALUES (?, ?, ?, ?, ?, 0, 0, ?)',
          [id, queue, '"payload-$id"', now, now, EntryStatus.pending.name],
        );
      }
      raw.execute('PRAGMA user_version = 1');
      raw.dispose();
    }

    test('a version 1 database upgrades and keeps every entry', () async {
      writeVersion1Database(entries: [
        ('orders', 'a'),
        ('orders', 'b'),
        ('emails', 'c'),
      ]);

      final storage = SQLiteStorage(dbPath: dbPath);
      addTearDown(storage.dispose);

      expect(storage.storedSchemaVersion, equals(2));
      expect(await storage.count('orders'), equals(2));
      expect(await storage.count('emails'), equals(1));
      expect(
        (await storage.retrieveAll('emails')).single.data,
        equals('payload-c'),
      );
    });

    test('the upgraded database takes an id another queue already holds',
        () async {
      writeVersion1Database(entries: [('orders', 'order-42')]);

      final storage = SQLiteStorage(dbPath: dbPath);
      addTearDown(storage.dispose);

      // The whole point of the migration: version 1 refused this.
      await storage.store(
        'shipping',
        QueueEntry<String>(
            id: 'order-42', data: 'from shipping', createdAt: DateTime.now()),
      );

      expect(await storage.count('orders'), equals(1));
      expect(await storage.count('shipping'), equals(1));
    });

    test('the rebuilt table carries the primary key and its indexes',
        () async {
      writeVersion1Database(entries: [('orders', 'a')]);
      SQLiteStorage(dbPath: dbPath).dispose();

      final raw = sqlite3.open(dbPath);
      addTearDown(raw.dispose);

      // Both columns, in order, form the key.
      final key = raw
          .select("SELECT name FROM pragma_table_info('queue_entries') "
              'WHERE pk > 0 ORDER BY pk')
          .map((r) => r['name'] as String)
          .toList();
      expect(key, equals(['queue_name', 'id']));

      // Dropping the old table dropped its indexes; the migration puts them
      // back, and a retrieval that lost its index would still pass every
      // behavioural test while scanning the table.
      final indexes = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'index' "
              "AND tbl_name = 'queue_entries' AND name LIKE 'idx_%'")
          .map((r) => r['name'] as String)
          .toSet();
      expect(
        indexes,
        containsAll([
          'idx_queue_entries_retrieval',
          'idx_queue_entries_expiration',
          'idx_queue_entries_queue_expiration',
          'idx_queue_entries_retry',
          'idx_queue_entries_scheduled',
        ]),
      );
    });

    test('a rebuild that fails after the drop loses nothing', () async {
      writeVersion1Database(entries: [('orders', 'a'), ('orders', 'b')]);

      // A *table* sitting on one of the index names. The rebuild gets all the
      // way through the drop and the rename before `CREATE INDEX` hits it,
      // which is the case that would lose data if the step were not atomic.
      final raw = sqlite3.open(dbPath);
      raw.execute('CREATE TABLE idx_queue_entries_expiration (x TEXT)');
      raw.dispose();

      expect(
        () => SQLiteStorage(dbPath: dbPath),
        throwsA(isA<SqliteException>().having(
          (e) => e.toString(),
          'message',
          contains('idx_queue_entries_expiration'),
        )),
        reason: 'the step must fail on the index, which is after the drop; '
            'failing earlier would make the rest of this test vacuous',
      );

      final after = sqlite3.open(dbPath);
      addTearDown(after.dispose);
      expect(
        after.select('PRAGMA user_version').first.values.first,
        equals(1),
      );
      expect(
        after.select('SELECT COUNT(*) c FROM queue_entries').first['c'],
        equals(2),
        reason: 'the entries must still be there after a rolled-back rebuild',
      );
      expect(
        after
            .select("SELECT name FROM pragma_table_info('queue_entries') "
                'WHERE pk > 0')
            .map((r) => r['name'] as String),
        equals(['id']),
        reason: 'and the table must still be the version 1 shape',
      );
    });

    test('a failed migration leaves the database at version 1', () async {
      writeVersion1Database(entries: [('orders', 'a')]);

      // A table already sitting on the name the rebuild wants, which makes the
      // migration's first statement fail partway through the step.
      final raw = sqlite3.open(dbPath);
      raw.execute('CREATE TABLE queue_entries_v2 (wrong TEXT)');
      raw.dispose();

      expect(() => SQLiteStorage(dbPath: dbPath), throwsA(anything));

      final after = sqlite3.open(dbPath);
      addTearDown(after.dispose);
      expect(
        after.select('PRAGMA user_version').first.values.first,
        equals(1),
        reason: 'a rolled-back step must not record the version it aimed at',
      );
      expect(
        after.select('SELECT COUNT(*) c FROM queue_entries').first['c'],
        equals(1),
        reason: 'the original table must survive a failed rebuild',
      );
    });
  });
}
