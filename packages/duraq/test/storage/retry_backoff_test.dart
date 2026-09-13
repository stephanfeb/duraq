import 'dart:io';

import 'package:duraq/duraq.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../support/queue_helpers.dart';

/// Regression tests for C3, and for M4 which C3 depends on.
///
/// A failed entry goes back to pending with a `nextRetryAt` computed from the
/// retry policy. Retrieval must not offer that entry again until the delay has
/// passed, on either backend.
void main() {
  group('Retry backoff on SQLiteStorage', () {
    late SQLiteStorage storage;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('duraq_backoff_');
      storage = SQLiteStorage(
        dbPath: path.join(tempDir.path, 'duraq_test.db'),
      );
    });

    tearDown(() {
      storage.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('an entry waiting on a retry is not retrieved', () async {
      await storage.store(
        'test-queue',
        entry('waiting',
            nextRetryAt: DateTime.now().add(const Duration(hours: 1))),
      );

      expect(await storage.retrieve('test-queue'), isNull);
    });

    test('an entry whose retry time has passed is retrieved', () async {
      await storage.store(
        'test-queue',
        entry('due',
            nextRetryAt: DateTime.now().subtract(const Duration(seconds: 1))),
      );

      final retrieved = await storage.retrieve('test-queue');
      expect(retrieved?.id, equals('due'));
    });

    test('a waiting entry does not hide a due one behind it', () async {
      // The waiting entry sorts first on priority, so a retrieval that ignored
      // the retry gate would return it and starve the ready entry.
      await storage.store(
        'test-queue',
        entry('waiting',
            priority: 0,
            nextRetryAt: DateTime.now().add(const Duration(hours: 1))),
      );
      await storage.store('test-queue', entry('ready', priority: 1));

      final retrieved = await storage.retrieve('test-queue');
      expect(retrieved?.id, equals('ready'));
      expect(await storage.retrieve('test-queue'), isNull);
    });

    test('store persists nextRetryAt instead of dropping it', () async {
      final retryAt = DateTime.now().add(const Duration(minutes: 30));
      await storage.store('test-queue', entry('kept', nextRetryAt: retryAt));

      final stored = (await storage.retrieveAll('test-queue')).single;
      expect(stored.nextRetryAt, isNotNull);
      expect(
        stored.nextRetryAt!.millisecondsSinceEpoch,
        equals(retryAt.millisecondsSinceEpoch),
      );
    });

    test('a failed entry backs off, then becomes available again', () async {
      final queue = Queue<String>(
        'test-queue',
        storage,
        retryPolicy: ExponentialBackoff(
          baseDelay: const Duration(milliseconds: 150),
          maxAttempts: 3,
        ),
      );
      await queue.enqueue('work');

      final delay = await failOnceAndReadDelay(storage, queue, 'test-queue');
      expect(delay, greaterThan(Duration.zero),
          reason: 'the policy should schedule the retry in the future');

      // Still inside the backoff window.
      expect(await storage.retrieve('test-queue'), isNull);

      final retried = await retrieveWithin(
        storage,
        'test-queue',
        delay + const Duration(seconds: 5),
      );
      expect(retried, isNotNull);
      expect(retried?.attempts, equals(1));
    });

    test('a dead letter retry clears the backoff', () async {
      await storage.store(
        'test-queue',
        entry('failed',
            nextRetryAt: DateTime.now().add(const Duration(hours: 1))),
      );
      await storage.updateEntryStatus(
        'test-queue',
        'failed',
        EntryStatus.deadLetter,
        nextRetryAt: DateTime.now().add(const Duration(hours: 1)),
      );

      await storage.retryDeadLetter('test-queue', 'failed');

      final retrieved = await storage.retrieve('test-queue');
      expect(retrieved?.id, equals('failed'));
    });
  });

}
