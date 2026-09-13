import 'dart:io';

import 'package:duraq/duraq.dart';
import 'package:duraq_isar/duraq_isar.dart';
import 'package:isar/isar.dart';
import 'package:test/test.dart';

import '../../duraq/test/support/queue_helpers.dart';
import 'support/isar_backend.dart';

/// The Isar half of the C3 retry-gate tests. The SQLite half lives in `duraq`.
void main() {
  group('Retry backoff on IsarStorage', () {
    late IsarStorage storage;
    late Isar isar;
    late String tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('duraq_backoff_isar_').path;
      await ensureIsarCore();
      isar = await Isar.open(
        IsarStorage.requiredSchemas,
        directory: tempDir,
        name: 'backoff_test',
      );
      storage = IsarStorage(isar);
    });

    tearDown(() async {
      await storage.dispose();
      await isar.close();
      try {
        await Directory(tempDir).delete(recursive: true);
      } catch (_) {
        // Ignore cleanup errors
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
      expect(delay, greaterThan(Duration.zero));

      expect(await storage.retrieve('test-queue'), isNull);

      final retried = await retrieveWithin(
        storage,
        'test-queue',
        delay + const Duration(seconds: 5),
      );
      expect(retried, isNotNull);
      expect(retried?.attempts, equals(1));
    });
  });
}
