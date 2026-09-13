import 'dart:io';

import 'package:duraq/duraq.dart';
import 'package:path/path.dart' as path;

/// A storage to run a suite against, and the means to shut it down.
typedef StorageUnderTest = ({
  StorageInterface storage,
  Future<void> Function() close,
});

/// Opens one backend's storage.
///
/// Every conformance suite takes one of these, so the same suite runs against
/// any backend. `duraq` supplies the SQLite one below; `duraq_isar` supplies
/// its own and runs the same suites against it.
typedef StorageOpener = Future<StorageUnderTest> Function({
  Duration? leaseDuration,
});

/// Opens a SQLite storage on a temporary database that is deleted on close.
Future<StorageUnderTest> openSqlite({Duration? leaseDuration}) async {
  final dir = Directory.systemTemp.createTempSync('duraq_suite_sqlite_');
  final storage = SQLiteStorage(
    dbPath: path.join(dir.path, 'duraq_test.db'),
    leaseDuration: leaseDuration ?? SQLiteStorage.defaultLockDuration,
  );
  return (
    storage: storage,
    close: () async {
      await storage.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    },
  );
}
