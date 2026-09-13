import 'package:duraq/duraq.dart';
import 'package:test/test.dart';

import 'storage_backend.dart';

/// Regression tests for M7.
///
/// `count` included entries scheduled for the future and entries waiting out a
/// retry backoff, so a queue could report a length of two and hand out nothing.
/// Anything scaling on that figure scales up for work that is not due.

void readySuite(String backend, StorageOpener open) {
    group('$backend ready counts', () {
      late StorageInterface storage;
      late Future<void> Function() close;

      setUp(() async {
        final opened = await open();
        storage = opened.storage;
        close = opened.close;
      });
      tearDown(() => close());

      Future<void> store(
        String id, {
        DateTime? scheduledFor,
        DateTime? nextRetryAt,
        DateTime? expiresAt,
      }) =>
          storage.store(
            'jobs',
            QueueEntry<String>(
              id: id,
              data: 'payload-$id',
              createdAt: DateTime.now(),
              scheduledFor: scheduledFor,
              nextRetryAt: nextRetryAt,
              expiresAt: expiresAt,
            ),
          );

      final future = DateTime.now().add(const Duration(days: 1));

      test('a queue of work that is not due reports nothing ready', () async {
        await store('later', scheduledFor: future);
        await store('backoff', nextRetryAt: future);

        expect(await storage.count('jobs'), equals(2),
            reason: 'both are waiting in the queue');
        expect(await storage.countReady('jobs'), equals(0),
            reason: 'neither can be handed out');
        expect(await storage.retrieve('jobs'), isNull,
            reason: 'which is what countReady has to agree with');
      });

      test('counts only the entries retrieve would consider', () async {
        await store('ready-1');
        await store('ready-2');
        await store('later', scheduledFor: future);
        await store('backoff', nextRetryAt: future);

        expect(await storage.count('jobs'), equals(4));
        expect(await storage.countReady('jobs'), equals(2));
      });

      test('a claimed entry counts in neither', () async {
        await store('e1');
        await store('e2');

        await storage.retrieve('jobs');

        expect(await storage.countReady('jobs'), equals(1));
        expect(await storage.count('jobs'), equals(1),
            reason: 'claiming moves an entry out of pending');
      });

      test('an expired entry counts in neither', () async {
        await store('gone',
            expiresAt: DateTime.now().subtract(const Duration(minutes: 1)));

        expect(await storage.count('jobs'), equals(0));
        expect(await storage.countReady('jobs'), equals(0));
      });

      test('an entry due exactly now is ready', () async {
        final now = DateTime.now();
        await store('due', scheduledFor: now.subtract(const Duration(seconds: 1)));

        expect(await storage.countReady('jobs'), equals(1));
      });

      test('an unknown queue is empty rather than an error', () async {
        expect(await storage.count('nothing-here'), equals(0));
        expect(await storage.countReady('nothing-here'), equals(0));
      });

      test('ready count agrees with what the queue hands out', () async {
        await store('a');
        await store('b');
        await store('later', scheduledFor: future);

        final queue = Queue<String>('jobs', storage);
        expect(await queue.length, equals(3));
        expect(await queue.readyLength, equals(2));

        var handed = 0;
        while (await queue.processNext((_) {})) {
          handed++;
        }

        expect(handed, equals(2), reason: 'exactly what readyLength promised');
        expect(await queue.readyLength, equals(0));
        expect(await queue.length, equals(1),
            reason: 'the entry due tomorrow is still waiting');
      });
    });
  }
