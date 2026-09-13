import 'dart:async';
import 'dart:io';

import 'package:duraq_isar/duraq_isar.dart';
import 'package:isar/isar.dart';

import '../../../duraq/test/support/storage_backend.dart';

/// An opener for the suites in `duraq`, backed by Isar.
///
/// [name] must be unique per test file. Isar keeps one instance per name for
/// the whole process, so two files running at the same time under one name get
/// the same database and trip over each other's entries; a unique name per
/// call instead leaves every database of the run open at once, each reserving
/// its own mapping, which is enough to get the test process killed. One name
/// per file, reused as that file's suites open and close it, is the shape that
/// works.
StorageOpener isarBackend(String name) =>
    ({Duration? leaseDuration}) => _openIsar(name, leaseDuration);

Future<StorageUnderTest> _openIsar(String name, Duration? leaseDuration) async {
  final dir = Directory.systemTemp.createTempSync('duraq_suite_isar_');
  await ensureIsarCore();
  final isar = await Isar.open(
    IsarStorage.requiredSchemas,
    directory: dir.path,
    name: name,
    // Far more than a test needs, and small enough that several suites running
    // at once do not reserve gigabytes between them.
    maxSizeMiB: 64,
  );
  final storage = IsarStorage(
    isar,
    leaseDuration: leaseDuration ?? IsarStorage.defaultLockDuration,
  );
  return (
    storage: storage,
    close: () async {
      await storage.close();
      await isar.close();
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {
        // Ignore cleanup errors
      }
    },
  );
}

/// Prepares the Isar native core for a test suite.
///
/// `Isar.initializeIsarCore(download: true)` downloads the library next to the
/// running script, which under `dart test` is one temporary directory shared by
/// every suite in the run. Several suites use Isar, they start together, and
/// they all try to write that one file: a suite that reads it mid-download
/// fails with "slice 0 extends beyond end of file, fat file, but missing
/// compatible architecture", which reads like a platform mismatch and is really
/// a race.
///
/// The download is the same file whoever wins, so losing the race only means
/// waiting for it. This retries until the file settles, and gives up with the
/// original error if it never does.
Future<void> ensureIsarCore() {
  return _initialized ??= _initialize().catchError((Object error) {
    // Let the next caller try again rather than caching a failure forever.
    _initialized = null;
    throw error;
  });
}

Future<void>? _initialized;

Future<void> _initialize() async {
  const attempts = 6;
  for (var attempt = 1;; attempt++) {
    try {
      await Isar.initializeIsarCore(download: true);
      return;
    } catch (_) {
      if (attempt >= attempts) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
    }
  }
}
