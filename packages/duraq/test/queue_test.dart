import 'package:test/test.dart';
import 'package:duraq/duraq.dart';
import 'utils/mock_storage.dart';

void main() {
  group('Queue', () {
    late MockStorage storage;
    late Queue<String> queue;

    setUp(() {
      storage = MockStorage();
      queue = Queue<String>('test-queue', storage);
    });

    test('has correct name', () {
      expect(queue.name, equals('test-queue'));
    });

    test('enqueues items', () async {
      await queue.enqueue('test1');
      expect(await queue.length, equals(1));

      await queue.enqueue('test2');
      expect(await queue.length, equals(2));
    });

    test('dequeues items in order', () async {
      await queue.enqueue('test1');
      await queue.enqueue('test2');

      expect(await queue.dequeue(), equals('test1'));
      expect(await queue.dequeue(), equals('test2'));
      expect(await queue.dequeue(), isNull);
    });

    test('processes items with callback', () async {
      await queue.enqueue('test1');
      
      var processed = '';
      await queue.processNext((data) {
        processed = data;
      });

      expect(processed, equals('test1'));
      
      // Entry should be marked as completed
      final entries = await storage.listDeadLetters<String>('test-queue');
      expect(entries.isEmpty, isTrue);
    });

    test('handles processing errors', () async {
      await queue.enqueue('test1');
      
      var error = '';
      try {
        await queue.processNext((data) {
          throw 'Processing error';
        });
      } catch (e) {
        error = e.toString();
      }

      expect(error, equals('Processing error'));
      
      // Entry should be marked as dead letter
      final entries = await storage.listDeadLetters<String>('test-queue');
      expect(entries.length, equals(1));
      expect(entries.first.data, equals('test1'));
      expect(entries.first.status, equals(EntryStatus.deadLetter));
    });
  });
} 