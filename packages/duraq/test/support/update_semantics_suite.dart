import 'package:duraq/duraq.dart';
import 'package:test/test.dart';

import 'storage_backend.dart';

/// Regression tests for M6, M8 and M10.
///
/// M6: every status update wrote `error_message` and `next_retry_at`, with null
/// when the caller had not supplied them, so completing an entry erased the
/// error that explained its last failure. Nothing checked that a row matched,
/// so a wrong id reported success.
///
/// M8: the lock was released for completed, failed and pending only. A dead
/// lettered or expired entry kept its claim for the rest of the lease.
///
/// M10: any exception while taking a lock was reported as "already locked", so
/// a storage failure moved the scan on to the next candidate and a broken
/// database looked like an empty queue.

  QueueEntry<String> entry(String id) => QueueEntry<String>(
        id: id,
        data: 'payload-$id',
        createdAt: DateTime.now(),
      );

void updateSuite(String backend, StorageOpener open) {
    group('$backend status updates', () {
      late StorageInterface storage;
      late Future<void> Function() close;

      setUp(() async {
        final opened = await open(leaseDuration: const Duration(minutes: 5));
        storage = opened.storage;
        close = opened.close;
      });
      tearDown(() => close());

      Future<QueueEntry<dynamic>> stored(String queueName) async =>
          (await storage.retrieveAll(queueName)).single;

      test('keeps the error message when a later update omits it', () async {
        await storage.store('q', entry('e1'));
        await storage.updateEntryStatus(
          'q',
          'e1',
          EntryStatus.failed,
          errorMessage: 'disk on fire',
          attempts: 3,
        );

        await storage.updateEntryStatus('q', 'e1', EntryStatus.completed);

        final row = await stored('q');
        expect(row.status, equals(EntryStatus.completed));
        expect(row.errorMessage, equals('disk on fire'),
            reason: 'the reason it failed is not the completion to report');
        expect(row.attempts, equals(3));
      });

      test('keeps the retry time when a later update omits it', () async {
        final retryAt = DateTime.now().add(const Duration(hours: 1));
        await storage.store('q', entry('e1'));
        await storage.updateEntryStatus(
          'q',
          'e1',
          EntryStatus.failed,
          nextRetryAt: retryAt,
        );

        await storage.updateEntryStatus('q', 'e1', EntryStatus.failed,
            errorMessage: 'still broken');

        final row = await stored('q');
        expect(row.nextRetryAt, isNotNull);
        expect(row.nextRetryAt!.millisecondsSinceEpoch,
            equals(retryAt.millisecondsSinceEpoch));
        expect(row.errorMessage, equals('still broken'));
      });

      test('overwrites the fields it is given', () async {
        await storage.store('q', entry('e1'));
        await storage.updateEntryStatus('q', 'e1', EntryStatus.failed,
            errorMessage: 'first');
        await storage.updateEntryStatus('q', 'e1', EntryStatus.failed,
            errorMessage: 'second');

        expect((await stored('q')).errorMessage, equals('second'));
      });

      test('pending with no retry time means available now', () async {
        await storage.store('q', entry('e1'));
        await storage.updateEntryStatus(
          'q',
          'e1',
          EntryStatus.pending,
          nextRetryAt: DateTime.now().add(const Duration(hours: 1)),
        );
        expect(await storage.retrieve('q'), isNull, reason: 'backed off');

        // Making it pending again without a retry time makes it ready: keeping
        // the old backoff would withhold an entry the caller just released.
        await storage.updateEntryStatus('q', 'e1', EntryStatus.pending);

        expect((await stored('q')).nextRetryAt, isNull);
        expect((await storage.retrieve('q'))?.id, equals('e1'));
      });

      test('reports a status change for an id it does not hold', () async {
        await storage.store('q', entry('e1'));

        await expectLater(
          storage.updateEntryStatus('q', 'no-such-entry', EntryStatus.completed),
          throwsA(isA<EntryNotFoundException>()
              .having((e) => e.entryId, 'entryId', 'no-such-entry')
              .having((e) => e.queueName, 'queueName', 'q')),
        );
      });

      test('a change discarded for a stale lease stays silent', () async {
        await storage.store('q', entry('e1'));
        final claimed = await storage.retrieve('q');
        await storage.updateEntryStatus('q', 'e1', EntryStatus.pending);
        await storage.retrieve('q');

        // The entry exists and someone else holds it. That is a discard, not a
        // missing entry, and must not be reported as one.
        await expectLater(
          storage.updateEntryStatus('q', 'e1', EntryStatus.completed,
              leaseId: claimed!.leaseId),
          completes,
        );
        expect((await stored('q')).status, equals(EntryStatus.processing));
      });

      test('dead lettering releases the claim', () async {
        await storage.store('q', entry('e1'));
        final claimed = await storage.retrieve('q');
        await storage.updateEntryStatus(
          'q',
          'e1',
          EntryStatus.deadLetter,
          leaseId: claimed!.leaseId,
        );

        // Retrying a dead letter used to appear to do nothing: the entry went
        // back to pending still locked by the claim it died under, so the scan
        // skipped it until the lease ran out.
        await storage.retryDeadLetter('q', 'e1');
        expect((await storage.retrieve('q'))?.id, equals('e1'));
      });

      test('expiring releases the claim', () async {
        await storage.store('q', entry('e1'));
        final claimed = await storage.retrieve('q');
        await storage.updateEntryStatus(
          'q',
          'e1',
          EntryStatus.expired,
          leaseId: claimed!.leaseId,
        );

        // With the claim gone, the lease it was held under no longer speaks
        // for the entry, so an update made under it is discarded. Going
        // through pending would not show this: pending always released.
        await storage.updateEntryStatus(
          'q',
          'e1',
          EntryStatus.completed,
          leaseId: claimed.leaseId,
        );
        expect((await stored('q')).status, equals(EntryStatus.expired));

        // And it can be put back into circulation.
        await storage.updateEntryStatus('q', 'e1', EntryStatus.pending);
        expect((await storage.retrieve('q'))?.id, equals('e1'));
      });

      test('an entry still processing keeps its claim', () async {
        await storage.store('q', entry('e1'));
        final claimed = await storage.retrieve('q');
        await storage.updateEntryStatus(
          'q',
          'e1',
          EntryStatus.processing,
          attempts: 1,
          leaseId: claimed!.leaseId,
        );

        // Its holder is still working: the entry must not be offered again,
        // and the lease it was claimed under must still be the live one.
        expect(await storage.retrieve('q'), isNull);
        await storage.updateEntryStatus('q', 'e1', EntryStatus.completed,
            leaseId: claimed.leaseId);
        expect((await stored('q')).status, equals(EntryStatus.completed));
      });
    });
  }
