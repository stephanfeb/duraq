import 'package:test/test.dart';
import 'package:duraq/duraq.dart';
import '../utils/mock_storage.dart';

void main() {
  group('DeadLetterQueue', () {
    late MockStorage storage;
    late DeadLetterQueue<String> dlq;
    late Queue<String> queue;

    setUp(() {
      storage = MockStorage();
      dlq = DeadLetterQueue<String>('test-queue', storage);
      queue = Queue<String>(
        'test-queue',
        storage,
        retryPolicy: ExponentialBackoff(maxAttempts: 1),
      );
    });

    test('handles dead letter entries correctly', () async {
      // Add an entry that will fail
      await queue.enqueue('test1');

      // Process and fail the entry
      try {
        await queue.processNext((data) {
          throw 'Processing error';
        });
      } catch (_) {}

      // Verify entry is in dead letter queue
      final deadLetters = await dlq.list();
      expect(deadLetters.length, equals(1));
      expect(deadLetters.first.data, equals('test1'));
      expect(deadLetters.first.status, equals(EntryStatus.deadLetter));
    });

    test('retries dead letter entries', () async {
      // Add and fail an entry
      await queue.enqueue('test1');
      try {
        await queue.processNext((data) {
          throw 'Processing error';
        });
      } catch (_) {}

      // Get the dead letter entry
      final deadLetter = await dlq.retrieve();
      expect(deadLetter, isNotNull);

      // Retry the entry
      await dlq.retry(deadLetter!.id);

      // Verify entry is back in main queue
      final retriedEntry = await queue.dequeue();
      expect(retriedEntry, equals('test1'));
    });

    test('removes dead letter entries', () async {
      // Add and fail an entry
      await queue.enqueue('test1');
      try {
        await queue.processNext((data) {
          throw 'Processing error';
        });
      } catch (_) {}

      // Get the dead letter entry
      final deadLetter = await dlq.retrieve();
      expect(deadLetter, isNotNull);

      // Remove the entry
      await dlq.remove(deadLetter!.id);

      // Verify entry is gone
      expect(await dlq.length, equals(0));
    });

    test('purges old dead letter entries', () async {
      // Add and fail multiple entries
      await queue.enqueue('test1');
      await queue.enqueue('test2');

      for (var i = 0; i < 2; i++) {
        try {
          await queue.processNext((data) {
            throw 'Processing error';
          });
        } catch (_) {}
      }

      // Verify both entries are in dead letter queue
      expect(await dlq.length, equals(2));

      // Purge entries older than now
      final purged = await dlq.purgeOldEntries(Duration.zero);
      expect(purged, equals(2));
      expect(await dlq.length, equals(0));
    });

    test('lists dead letter entries with pagination', () async {
      // Add and fail multiple entries
      for (var i = 0; i < 5; i++) {
        await queue.enqueue('test$i');
        try {
          await queue.processNext((data) {
            throw 'Processing error';
          });
        } catch (_) {}
      }

      // Test pagination
      final page1 = await dlq.list(limit: 2, offset: 0);
      expect(page1.length, equals(2));
      expect(page1[0].data, equals('test0'));
      expect(page1[1].data, equals('test1'));

      final page2 = await dlq.list(limit: 2, offset: 2);
      expect(page2.length, equals(2));
      expect(page2[0].data, equals('test2'));
      expect(page2[1].data, equals('test3'));

      final page3 = await dlq.list(limit: 2, offset: 4);
      expect(page3.length, equals(1));
      expect(page3[0].data, equals('test4'));
    });
  });
} 