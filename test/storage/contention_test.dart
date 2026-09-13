import 'dart:async';
import 'dart:io';

import 'package:duraq/duraq.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// Regression tests for H3.
///
/// Write-ahead logging invites more than one process to open the same file, but
/// the busy timeout was left at zero, so a second writer got an immediate
/// "database is locked" instead of waiting its turn, and a shutdown could throw
/// the same way.
void main() {
  group('SQLiteStorage under write contention', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('duraq_contention_');
      dbPath = path.join(tempDir.path, 'duraq_test.db');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    /// A second connection to the same file, as another process would have.
    SQLiteStorage connect({Duration? busyTimeout}) {
      final storage = SQLiteStorage(
        dbPath: dbPath,
        busyTimeout: busyTimeout ?? SQLiteStorage.defaultBusyTimeout,
      );
      addTearDown(storage.dispose); // dispose is idempotent
      return storage;
    }

    QueueEntry<String> entry(String id) => QueueEntry<String>(
          id: id,
          data: 'payload-$id',
          createdAt: DateTime.now(),
        );

    test('two connections can both write to the same file', () async {
      final first = connect();
      final second = connect();

      for (var i = 0; i < 25; i++) {
        await first.store('test-queue', entry('a$i'));
        await second.store('test-queue', entry('b$i'));
      }

      expect(await first.count('test-queue'), equals(50));
      expect(await second.count('test-queue'), equals(50));
    });

    test('a write waits for the other connection instead of failing',
        () async {
      final holder = connect();
      final waiter = connect(busyTimeout: const Duration(seconds: 5));

      // Holding a transaction open holds the database's write lock.
      await holder.beginTransaction();
      await holder.store('test-queue', entry('held'));

      final blocked = waiter.store('test-queue', entry('waiting'));
      await Future<void>.delayed(const Duration(milliseconds: 150));

      await holder.commitTransaction();
      await blocked.timeout(const Duration(seconds: 5));

      expect(await waiter.count('test-queue'), equals(2));
    });

    test('waiting for the lock leaves the isolate responsive', () async {
      final holder = connect();
      final waiter = connect(busyTimeout: const Duration(seconds: 5));

      await holder.beginTransaction();
      await holder.store('test-queue', entry('held'));

      var ticks = 0;
      final ticker = Timer.periodic(
        const Duration(milliseconds: 20),
        (_) => ticks++,
      );

      final blocked = waiter.store('test-queue', entry('waiting'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await holder.commitTransaction();
      await blocked;
      ticker.cancel();

      // The driver blocks the isolate while it waits, so the wait is spent in
      // short slices. Other work has to keep running in between.
      //
      // The bar is deliberately low. What this proves is that the isolate is
      // not held for the whole wait: a blocking implementation scores exactly
      // zero here, whatever the machine is doing. How far above zero the count
      // lands is a function of load, and asserting on that is what made this
      // test flaky under a parallel run.
      expect(ticks, greaterThanOrEqualTo(2),
          reason: 'timers should still fire while a write waits its turn');
    });

    test('giving up reports a StorageBusyException, not a driver error',
        () async {
      final holder = connect();
      final waiter = connect(busyTimeout: const Duration(milliseconds: 150));

      await holder.beginTransaction();
      await holder.store('test-queue', entry('held'));

      try {
        await waiter.store('test-queue', entry('waiting'));
        fail('the contended write should have given up');
      } on StorageBusyException catch (e) {
        expect(e, isA<DuraQException>());
        expect(e.waited, equals(const Duration(milliseconds: 150)));
        expect(e.message, contains('busyTimeout'));
      }

      await holder.commitTransaction();
    });

    test('the storage still works after a contended write gave up', () async {
      final holder = connect();
      final waiter = connect(busyTimeout: const Duration(milliseconds: 100));

      await holder.beginTransaction();
      await holder.store('test-queue', entry('held'));
      await expectLater(
        waiter.store('test-queue', entry('rejected')),
        throwsA(isA<StorageBusyException>()),
      );
      await holder.commitTransaction();

      await waiter
          .store('test-queue', entry('accepted'))
          .timeout(const Duration(seconds: 5));
      expect(await waiter.count('test-queue'), equals(2));
    });

    test('disposing does not throw while another connection holds the lock',
        () async {
      final holder = connect();
      final other = connect(busyTimeout: const Duration(milliseconds: 100));

      await other.store('test-queue', entry('claimed'));
      await other.retrieve('test-queue');

      await holder.beginTransaction();
      await holder.store('test-queue', entry('held'));

      // Shutting down has to release what it can and stay quiet about the rest.
      expect(other.dispose, returnsNormally);

      await holder.commitTransaction();
    });
  });
}
