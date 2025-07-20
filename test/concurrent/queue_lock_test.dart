import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:duraq/src/concurrent/queue_lock.dart';
import 'dart:io';

void main() {
  late Database db;
  late QueueLock lock;
  late File dbFile;

  setUp(() async {
    dbFile = File('test/test_locks.db');
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
    db = sqlite3.open(dbFile.path);
    lock = QueueLock(db);
  });

  tearDown(() async {
    db.dispose();
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
  });

  group('QueueLock Tests', () {
    test('should acquire lock successfully', () async {
      final lockId = await lock.tryAcquire('test-queue', 'entry-1');
      expect(lockId, isNotNull);
      expect(await lock.isLocked('test-queue', 'entry-1'), isTrue);
    });

    test('should not acquire lock when already locked', () async {
      final lockId1 = await lock.tryAcquire('test-queue', 'entry-1');
      expect(lockId1, isNotNull);

      final lockId2 = await lock.tryAcquire('test-queue', 'entry-1');
      expect(lockId2, isNull);
    });

    test('should release lock successfully', () async {
      final lockId = await lock.tryAcquire('test-queue', 'entry-1');
      expect(lockId, isNotNull);

      final released = await lock.release('test-queue', 'entry-1', lockId!);
      expect(released, isTrue);
      expect(await lock.isLocked('test-queue', 'entry-1'), isFalse);
    });

    test('should not release lock with wrong lock ID', () async {
      final lockId = await lock.tryAcquire('test-queue', 'entry-1');
      expect(lockId, isNotNull);

      final released = await lock.release('test-queue', 'entry-1', 'wrong-id');
      expect(released, isFalse);
      expect(await lock.isLocked('test-queue', 'entry-1'), isTrue);
    });

    test('should cleanup expired locks', () async {
      // Create a lock with very short duration
      final lockId = await lock.tryAcquire(
        'test-queue',
        'entry-1',
        lockDuration: Duration(milliseconds: 1),
      );
      expect(lockId, isNotNull);

      // Wait for lock to expire
      await Future.delayed(Duration(milliseconds: 10));

      // Check that lock is cleaned up
      expect(await lock.isLocked('test-queue', 'entry-1'), isFalse);

      // Should be able to acquire new lock
      final newLockId = await lock.tryAcquire('test-queue', 'entry-1');
      expect(newLockId, isNotNull);
    });

    test('should track active lock count', () async {
      expect(await lock.activeLockCount(), equals(0));

      await lock.tryAcquire('test-queue', 'entry-1');
      expect(await lock.activeLockCount(), equals(1));

      await lock.tryAcquire('test-queue', 'entry-2');
      expect(await lock.activeLockCount(), equals(2));
    });

    test('should release all locks', () async {
      await lock.tryAcquire('test-queue', 'entry-1');
      await lock.tryAcquire('test-queue', 'entry-2');
      expect(await lock.activeLockCount(), equals(2));

      final released = await lock.releaseAllLocks();
      expect(released, equals(2));
      expect(await lock.activeLockCount(), equals(0));
    });

    test('should handle concurrent lock attempts', () async {
      // Simulate concurrent lock attempts
      final futures = await Future.wait([
        lock.tryAcquire('test-queue', 'entry-1'),
        lock.tryAcquire('test-queue', 'entry-1'),
        lock.tryAcquire('test-queue', 'entry-1'),
      ]);

      // Only one should succeed
      final successCount = futures.where((id) => id != null).length;
      expect(successCount, equals(1));
    });
  });
} 