import 'dart:async';
import 'package:isar/isar.dart';
import 'isar_models.dart';
import 'isar_write_scope.dart';

/// Isar-based implementation of queue entry locking
class IsarQueueLock {
  final Isar _isar;

  /// Lock ids acquired through this instance, keyed by queue name and entry id.
  ///
  /// Locks taken elsewhere are not in here, which is what keeps
  /// [releaseAllLocks] from freeing entries that are still being processed by
  /// another consumer.
  final Map<String, String> _ownedLocks = {};

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
      return await IsarWriteScope.run(_isar, () async {
        // Clean up expired locks first
        await _isar.queueLockCollections
            .where()
            .expiresAtLessThan(now)
            .deleteAll();

        // Check if lock already exists
        final existingLock = await _isar.queueLockCollections
            .where()
            .lockKeyEqualTo(lockKeyFor(queueName, entryId))
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
        _ownedLocks[lockKeyFor(queueName, entryId)] = lockId;
        return lockId;
      });
    } catch (e) {
      // If operation fails, the entry is already locked
      return null;
    }
  }

  /// Releases a lock on an entry.
  ///
  /// Pass [lockId] to release only that particular lock. Without it any lock on
  /// the entry is released, including one taken by another consumer after this
  /// one's lease expired.
  Future<bool> release(String queueName, String entryId, {String? lockId}) async {
    try {
      final key = lockKeyFor(queueName, entryId);
      final deletedCount = await IsarWriteScope.run(_isar, () async {
        final held = await _isar.queueLockCollections
            .where()
            .lockKeyEqualTo(key)
            .findFirst();
        if (held == null) return 0;
        if (lockId != null && held.lockId != lockId) return 0;
        return await _isar.queueLockCollections.delete(held.id) ? 1 : 0;
      });
      if (lockId == null || _ownedLocks[key] == lockId) {
        _ownedLocks.remove(key);
      }
      return deletedCount > 0;
    } catch (e) {
      return false;
    }
  }

  /// Whether [lockId] is the lock currently held on the entry.
  ///
  /// False once the lease has expired, even if the row is still there, because
  /// an expired lease no longer entitles its holder to anything.
  Future<bool> isHeldBy(String queueName, String entryId, String lockId) async {
    final held = await _isar.queueLockCollections
        .where()
        .lockKeyEqualTo(lockKeyFor(queueName, entryId))
        .filter()
        .expiresAtGreaterThan(DateTime.now())
        .findFirst();
    return held != null && held.lockId == lockId;
  }

  /// Checks if an entry is currently locked
  Future<bool> isLocked(String queueName, String entryId) async {
    await _cleanupExpiredLocks();

    final lock = await _isar.queueLockCollections
        .where()
        .lockKeyEqualTo(lockKeyFor(queueName, entryId))
        .findFirst();

    return lock != null;
  }

  /// Cleans up expired locks
  Future<void> _cleanupExpiredLocks() async {
    final now = DateTime.now();
    await IsarWriteScope.run(_isar, () async {
      await _isar.queueLockCollections
          .where()
          .expiresAtLessThan(now)
          .deleteAll();
    });
  }

  /// Returns the number of currently held locks
  Future<int> activeLockCount() async {
    await _cleanupExpiredLocks();
    return await _isar.queueLockCollections.count();
  }

  /// Releases every lock this instance is holding.
  ///
  /// Locks held by other consumers are left alone; releasing those would hand
  /// their in-flight entries to someone else while they are still working.
  Future<int> releaseAllLocks() async {
    if (_ownedLocks.isEmpty) return 0;

    final lockIds = _ownedLocks.values.toList();
    final released = await IsarWriteScope.run(_isar, () async {
      var count = 0;
      for (final lockId in lockIds) {
        count += await _isar.queueLockCollections
            .where()
            .lockIdEqualTo(lockId)
            .deleteAll();
      }
      return count;
    });
    _ownedLocks.clear();
    return released;
  }
}
