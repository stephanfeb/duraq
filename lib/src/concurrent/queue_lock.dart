import 'dart:async';
import 'package:sqlite3/sqlite3.dart';

/// Represents a lock on a queue entry
class QueueLock {
  /// The database connection
  final Database _db;

  /// The lock table name
  final String _tableName;

  /// Creates a new queue lock manager
  QueueLock(this._db, {String tableName = 'queue_locks'}) : _tableName = tableName {
    _createLockTable();
  }

  /// Creates the lock table if it doesn't exist
  void _createLockTable() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        queue_name TEXT NOT NULL,
        entry_id TEXT NOT NULL,
        lock_id TEXT NOT NULL,
        acquired_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        PRIMARY KEY (queue_name, entry_id)
      )
    ''');

    // Add index for lock cleanup
    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_${_tableName}_expiration
      ON $_tableName(expires_at)
    ''');
  }

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

    // First, clean up expired locks
    await _cleanupExpiredLocks();

    try {
      // Insert the lock record
      final stmt = _db.prepare('''
        INSERT INTO $_tableName (
          queue_name, entry_id, lock_id, acquired_at, expires_at
        )
        VALUES (?, ?, ?, ?, ?)
      ''');
      try {
        stmt.execute([
          queueName,
          entryId,
          lockId,
          now.millisecondsSinceEpoch,
          expiresAt.millisecondsSinceEpoch,
        ]);
        return lockId;
      } finally {
        stmt.dispose();
      }
    } catch (e) {
      // If insert fails, the entry is already locked
      return null;
    }
  }

  /// Releases a lock by its ID
  Future<bool> release(String queueName, String entryId, String lockId) async {
    final stmt = _db.prepare('''
      DELETE FROM $_tableName
      WHERE queue_name = ?
      AND entry_id = ?
      AND lock_id = ?
    ''');
    try {
      stmt.execute([queueName, entryId, lockId]);
      final changes = _db.getUpdatedRows();
      return changes > 0;
    } finally {
      stmt.dispose();
    }
  }

  /// Checks if an entry is currently locked
  Future<bool> isLocked(String queueName, String entryId) async {
    await _cleanupExpiredLocks();

    final result = _db.select(
      '''
      SELECT COUNT(*) as count
      FROM $_tableName
      WHERE queue_name = ?
      AND entry_id = ?
      ''',
      [queueName, entryId],
    );
    return (result.first['count'] as int) > 0;
  }

  /// Cleans up expired locks
  Future<void> _cleanupExpiredLocks() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stmt = _db.prepare('''
      DELETE FROM $_tableName
      WHERE expires_at <= ?
    ''');
    try {
      stmt.execute([now]);
    } finally {
      stmt.dispose();
    }
  }

  /// Returns the number of currently held locks
  Future<int> activeLockCount() async {
    await _cleanupExpiredLocks();
    final result = _db.select('SELECT COUNT(*) as count FROM $_tableName');
    return result.first['count'] as int;
  }

  /// Forcefully releases all locks
  Future<int> releaseAllLocks() async {
    final stmt = _db.prepare('DELETE FROM $_tableName');
    try {
      stmt.execute([]);
      return _db.getUpdatedRows();
    } finally {
      stmt.dispose();
    }
  }
} 