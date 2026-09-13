// ignore_for_file: deprecated_member_use
// sqlite3 3.0 renamed Database.dispose to close, and 2.x — which this
// package still supports — has only dispose. These tests hold raw
// handles, so they use the name that works across the whole range.
import 'package:duraq/duraq.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

import '../support/update_semantics_suite.dart';
import '../support/storage_backend.dart';

/// The shared suite, run against the SQLite backend. Its body lives in
/// `test/support/update_semantics_suite.dart`, where `duraq_isar` runs the same one
/// against Isar, so both backends are held to one description.
void main() {
  updateSuite('SQLite', openSqlite);

group('QueueLock failure reporting', () {
  late Directory tempDir;
  late Database db;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('duraq_lockfail_');
    db = sqlite3.open(path.join(tempDir.path, 'locks.db'));
  });

  tearDown(() {
    db.dispose();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('every acquisition gets its own id, even within one millisecond',
      () async {
    final lock = QueueLock(db);
    final ids = <String>{};

    // Back-to-back claims of one entry land in the same millisecond. Ids
    // built from the clock alone collided there, and a consumer holding the
    // older one was then accepted as the current holder.
    for (var i = 0; i < 200; i++) {
      final id = await lock.tryAcquire('q', 'e1');
      expect(id, isNotNull);
      ids.add(id!);
      await lock.release('q', 'e1', lockId: id);
    }

    expect(ids, hasLength(200));
  });

  test('a second acquisition of the same entry reports contention', () async {
    final lock = QueueLock(db);

    expect(await lock.tryAcquire('q', 'e1'), isNotNull);
    expect(await lock.tryAcquire('q', 'e1'), isNull,
        reason: 'the entry is genuinely locked');
  });

  test('a storage failure is raised, not reported as contention', () async {
    final lock = QueueLock(db);

    // A schema the insert cannot satisfy. Cleanup still works, so the
    // failure happens on the insert itself — the path that used to swallow
    // everything and answer "already locked".
    db.execute('DROP TABLE queue_locks');
    db.execute('''
      CREATE TABLE queue_locks (
        queue_name TEXT NOT NULL,
        entry_id TEXT NOT NULL,
        lock_id TEXT NOT NULL,
        acquired_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        shard INTEGER NOT NULL,
        PRIMARY KEY (queue_name, entry_id)
      )
    ''');

    await expectLater(
      lock.tryAcquire('q', 'e1'),
      throwsA(isA<SqliteException>()),
    );
  });
});}
