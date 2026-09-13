import 'dart:async';

import 'package:isar/isar.dart';

/// Prepares the Isar native core for a test suite.
///
/// `Isar.initializeIsarCore(download: true)` downloads the library next to the
/// running script, which under `dart test` is one temporary directory shared by
/// every suite in the run. Seven suites use Isar, they start together, and they
/// all try to write that one file: a suite that reads it mid-download fails
/// with "slice 0 extends beyond end of file, fat file, but missing compatible
/// architecture", which reads like a platform mismatch and is really a race.
///
/// The download is the same file whoever wins, so losing the race only means
/// waiting for it. This retries until the file settles, and gives up with the
/// original error if it never does.
///
/// Once per process the successful result is remembered, so suites that call it
/// in several `setUp`s pay for it once.
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
      // Long enough for another suite's download to finish, short enough that
      // a genuinely broken library still reports quickly.
      await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
    }
  }
}
