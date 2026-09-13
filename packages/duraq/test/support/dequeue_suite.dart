import 'package:duraq/duraq.dart';
import 'package:test/test.dart';

import 'storage_backend.dart';

/// Regression tests for M1.
///
/// `dequeue` was documented as retrieving and removing an item, and removed
/// nothing. It claimed the entry, returned the payload, and left the row in
/// `processing` with no way for the caller to acknowledge it. Once the lease
/// expired the entry was handed out again, so every dequeued item came back.

void dequeueSuite(String backend, StorageOpener open) {
    group('$backend dequeue', () {
      late StorageInterface storage;
      late Future<void> Function() close;

      Future<void> useStorage(Duration lease) async {
        final opened = await open(leaseDuration: lease);
        storage = opened.storage;
        close = opened.close;
      }

      setUp(() => useStorage(const Duration(minutes: 5)));
      tearDown(() => close());

      test('removes the entry it returns', () async {
        final queue = Queue<String>('jobs', storage);
        await queue.enqueue('a');
        await queue.enqueue('b');

        expect(await queue.dequeue(), equals('a'));

        final remaining = await storage.retrieveAll('jobs');
        expect(remaining, hasLength(1),
            reason: 'the dequeued entry should be gone, not left processing');
        expect(remaining.single.data, equals('b'));
      });

      test('does not hand the same item out again once the lease lapses',
          () async {
        await close();
        await useStorage(const Duration(milliseconds: 100));

        final queue = Queue<String>('jobs', storage);
        await queue.enqueue('only');
        expect(await queue.dequeue(), equals('only'));

        // Long enough for a lease to expire and the entry to be reclaimed,
        // which is what used to redeliver it.
        await Future<void>.delayed(const Duration(milliseconds: 400));

        expect(await queue.dequeue(), isNull);
        expect(await storage.retrieveAll('jobs'), isEmpty);
      });

      test('empties the queue rather than draining into itself', () async {
        final queue = Queue<String>('jobs', storage);
        for (var i = 0; i < 5; i++) {
          await queue.enqueue('item-$i');
        }

        final taken = <String>[];
        for (var i = 0; i < 5; i++) {
          taken.add((await queue.dequeue())!);
        }

        expect(taken, equals(['item-0', 'item-1', 'item-2', 'item-3', 'item-4']));
        expect(await queue.dequeue(), isNull);
        expect(await storage.retrieveAll('jobs'), isEmpty);
      });

      test('returns null on an empty queue', () async {
        expect(await Queue<String>('jobs', storage).dequeue(), isNull);
      });

      test('leaves no lock behind on the id it removed', () async {
        final queue = Queue<String>('jobs', storage);
        await queue.enqueueEntry(QueueEntry<String>(
          id: 'reused-id',
          data: 'first',
          createdAt: DateTime.now(),
        ));
        expect(await queue.dequeue(), equals('first'));

        // The lock is keyed by entry id. If removing the entry left it behind,
        // this id stays unclaimable until the lease runs out.
        await queue.enqueueEntry(QueueEntry<String>(
          id: 'reused-id',
          data: 'second',
          createdAt: DateTime.now(),
        ));
        expect(await queue.dequeue(), equals('second'));
      });

      test('processNext still keeps the entry until the work is done',
          () async {
        final queue = Queue<String>('jobs', storage);
        await queue.enqueue('work');

        await queue.processNext((_) async {
          // Mid-flight the entry is still there, which is what makes
          // processNext recoverable and dequeue not.
          final inFlight = await storage.retrieveAll('jobs');
          expect(inFlight.single.status, equals(EntryStatus.processing));
        });

        final after = (await storage.retrieveAll('jobs')).single;
        expect(after.status, equals(EntryStatus.completed));
      });
    });
  }
