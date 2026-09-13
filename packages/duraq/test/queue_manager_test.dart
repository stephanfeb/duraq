import 'package:duraq/duraq.dart';
import 'package:test/test.dart';

import 'utils/mock_storage.dart';

void main() {
  group('QueueManager', () {
    late MockStorage storage;
    late QueueManager manager;

    setUp(() {
      storage = MockStorage();
      manager = QueueManager(storage);
    });

    test('creates new queue with correct type', () {
      final stringQueue = manager.queue<String>('string-queue');
      final intQueue = manager.queue<int>('int-queue');

      expect(stringQueue, isA<Queue<String>>());
      expect(intQueue, isA<Queue<int>>());
    });

    test('reuses existing queue instance', () {
      final queue1 = manager.queue<String>('test-queue');
      final queue2 = manager.queue<String>('test-queue');

      expect(identical(queue1, queue2), isTrue);
    });

    test('listQueues returns queues from storage', () async {
      // Create some queues in storage by adding entries
      final queue1 = manager.queue<String>('queue1');
      final queue2 = manager.queue<int>('queue2');
      
      await queue1.enqueue('test1');
      await queue2.enqueue(42);

      final queues = await manager.listQueues();
      expect(queues, containsAll(['queue1', 'queue2']));
    });

    test('removeQueue removes queue from storage and cache', () async {
      // Create a queue and add an entry
      final queue = manager.queue<String>('test-queue');
      await queue.enqueue('test-data');

      // Verify queue exists
      var queues = await manager.listQueues();
      expect(queues, contains('test-queue'));

      // Remove the queue
      await manager.removeQueue('test-queue');

      // Verify queue is removed from storage
      queues = await manager.listQueues();
      expect(queues, isNot(contains('test-queue')));

      // Verify a new queue instance is created if accessed again
      final newQueue = manager.queue<String>('test-queue');
      expect(identical(queue, newQueue), isFalse);
    });

    test('removeQueue handles non-existent queue gracefully', () async {
      await expectLater(
        manager.removeQueue('non-existent-queue'),
        completes,
      );
    });

    // Regression tests for M2. The cache was keyed by name alone and the
    // result cast to the caller's type, so the first caller's type won for the
    // life of the process and every later caller got a _TypeError out of the
    // cache.
    group('typed views of one queue', () {
      test('the same name can be read as two different types', () {
        final asString = manager.queue<String>('mixed');
        final asInt = manager.queue<int>('mixed');

        expect(asString, isA<Queue<String>>());
        expect(asInt, isA<Queue<int>>());
      });

      test('a queue first touched untyped can still be fetched typed', () {
        manager.queue<dynamic>('logs');

        expect(manager.queue<String>('logs'), isA<Queue<String>>());
      });

      test('each name and type pair gets one instance', () {
        expect(
          identical(manager.queue<String>('q'), manager.queue<String>('q')),
          isTrue,
        );
        expect(
          identical(manager.queue<String>('q'), manager.queue<int>('q')),
          isFalse,
          reason: 'different element types are different queue objects',
        );
      });

      test('typed views read the same stored entries', () async {
        await manager.queue<String>('shared').enqueue('written as a String');

        // An admin tool reading `dynamic` sees what a worker wrote.
        expect(
          await manager.queue<dynamic>('shared').dequeue(),
          equals('written as a String'),
        );
      });

      test('removeQueue forgets every typed view of the name', () async {
        final typed = manager.queue<String>('doomed');
        final untyped = manager.queue<dynamic>('doomed');

        await manager.removeQueue('doomed');

        expect(identical(manager.queue<String>('doomed'), typed), isFalse);
        expect(identical(manager.queue<dynamic>('doomed'), untyped), isFalse);
      });
    });
  });
}
