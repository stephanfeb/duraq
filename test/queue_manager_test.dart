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
  });
}
