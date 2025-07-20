import 'dart:async';
import 'package:isar/isar.dart';
import 'isar_models.dart';

/// Isar-based implementation of queue entry locking
class IsarQueueLock {
  final Isar _isar;

  IsarQueueLock(this._isar);

  /// Attempts to acquire a lock on an entry
  /// Returns the lock ID if successful, null if the entry is already locked
  Future<String?> tryAcquire(
    String queueName,
    String entryId, {
    Duration lockDuration = const Duration(minutes: 5),
  }) async {
    final now = DateTime.now();
    final lockId = '${queueName}_${entryId}_${now.millisecondsSinceEpoch}';
    final expiresAt = now.add(lockDuration);

    try {
      // Clean up expired locks first (without transaction)
      await _cleanupExpiredLocksSync();

      // Check if lock already exists
      final existingLock = await _isar.queueLockCollections
          .filter()
          .queueNameEqualTo(queueName)
          .and()
          .entryIdEqualTo(entryId)
          .findFirst();

      if (existingLock != null) {
        return null; // Entry already locked
      }

      // Create new lock
      final lock = QueueLockCollection()
        ..queueName = queueName
        ..entryId = entryId
        ..lockId = lockId
        ..acquiredAt = now
        ..expiresAt = expiresAt;

      await _isar.queueLockCollections.put(lock);
      return lockId;
    } catch (e) {
      // If operation fails, the entry is already locked
      return null;
    }
  }

  /// Releases a lock by its ID
  Future<bool> release(String queueName, String entryId, String lockId) async {
    try {
      late bool deleted;
      await _isar.writeTxn(() async {
        final lock = await _isar.queueLockCollections
            .filter()
            .queueNameEqualTo(queueName)
            .and()
            .entryIdEqualTo(entryId)
            .and()
            .lockIdEqualTo(lockId)
            .findFirst();

        if (lock != null) {
          deleted = await _isar.queueLockCollections.delete(lock.id);
        } else {
          deleted = false;
        }
      });
      return deleted;
    } catch (e) {
      return false;
    }
  }

  /// Checks if an entry is currently locked
  Future<bool> isLocked(String queueName, String entryId) async {
    await _cleanupExpiredLocksSync();

    final lock = await _isar.queueLockCollections
        .filter()
        .queueNameEqualTo(queueName)
        .and()
        .entryIdEqualTo(entryId)
        .findFirst();

    return lock != null;
  }

  /// Cleans up expired locks (with transaction)
  Future<void> _cleanupExpiredLocks() async {
    final now = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.queueLockCollections
          .where()
          .expiresAtLessThan(now)
          .deleteAll();
    });
  }

  /// Cleans up expired locks synchronously (without starting new transaction)
  Future<void> _cleanupExpiredLocksSync() async {
    final now = DateTime.now();
    await _isar.queueLockCollections
        .where()
        .expiresAtLessThan(now)
        .deleteAll();
  }

  /// Returns the number of currently held locks
  Future<int> activeLockCount() async {
    await _cleanupExpiredLocks();
    return await _isar.queueLockCollections.count();
  }

  /// Forcefully releases all locks
  Future<int> releaseAllLocks() async {
    late int count;
    await _isar.writeTxn(() async {
      count = await _isar.queueLockCollections.count();
      await _isar.queueLockCollections.clear();
    });
    return count;
  }
}
