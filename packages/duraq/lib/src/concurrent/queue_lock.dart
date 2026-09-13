import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

/// Represents a lock on a queue entry
class QueueLock {
  /// The database connection
  final Database _db;

  /// The lock table name
  final String _tableName;

  /// Lock ids acquired through this instance, keyed by queue name and entry id.
  ///
  /// Locks taken by another process, isolate, or storage instance are not in
  /// here, which is what keeps [releaseAllLocks] from freeing entries that are
  /// still being processed elsewhere.
  final Map<String, String> _ownedLocks = {};

  static const _uuid = Uuid();

  String _ownerKey(String queueName, String entryId) => '$queueName\u0000$entryId';

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
    // The id has to be unique per acquisition, not per millisecond. Built from
    // the clock alone, two claims of the same entry inside one millisecond got
    // the same id, and a consumer holding the older one was then accepted as
    // the current holder — which is exactly what the ownership check exists to
    // prevent.
    final lockId = '${queueName}_${entryId}_${now.millisecondsSinceEpoch}_'
        '${_uuid.v4()}';
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
        _ownedLocks[_ownerKey(queueName, entryId)] = lockId;
        return lockId;
      } finally {
        // sqlite3 3.0 renamed this to close(), which does not exist in the
        // 2.x this package still supports. Switch when the floor moves past
        // 3.0.
        // ignore: deprecated_member_use
        stmt.dispose();
      }
    } on SqliteException catch (e) {
      // A primary key conflict is the entry already being locked, which is the
      // answer this method exists to give. Everything else — a broken schema, a
      // full disk, a database that went away — is a storage failure, and
      // reporting it as contention sent the caller on to the next candidate
      // and made a failing database look like an empty queue.
      if (e.extendedResultCode == _constraintPrimaryKey ||
          e.extendedResultCode == _constraintUnique) {
        return null;
      }
      rethrow;
    }
  }

  /// SQLITE_CONSTRAINT_PRIMARYKEY: another holder has this entry.
  static const int _constraintPrimaryKey = 1555;

  /// SQLITE_CONSTRAINT_UNIQUE, for a lock table indexed differently.
  static const int _constraintUnique = 2067;

  /// Releases a lock on an entry.
  ///
  /// Pass [lockId] to release only that particular lock. Without it any lock on
  /// the entry is released, including one taken by another consumer after this
  /// one's lease expired.
  Future<bool> release(String queueName, String entryId, {String? lockId}) async {
    final stmt = _db.prepare(lockId == null
        ? '''
      DELETE FROM $_tableName
      WHERE queue_name = ?
      AND entry_id = ?
    '''
        : '''
      DELETE FROM $_tableName
      WHERE queue_name = ?
      AND entry_id = ?
      AND lock_id = ?
    ''');
    try {
      stmt.execute([queueName, entryId, if (lockId != null) lockId]);
      final changes = _db.updatedRows;
      final key = _ownerKey(queueName, entryId);
      if (lockId == null || _ownedLocks[key] == lockId) {
        _ownedLocks.remove(key);
      }
      return changes > 0;
    } finally {
      // ignore: deprecated_member_use
      stmt.dispose();
    }
  }

  /// Whether [lockId] is the lock currently held on the entry.
  ///
  /// False once the lease has expired, even if the row is still there, because
  /// an expired lease no longer entitles its holder to anything.
  Future<bool> isHeldBy(String queueName, String entryId, String lockId) async {
    final result = _db.select(
      '''
      SELECT lock_id FROM $_tableName
      WHERE queue_name = ?
      AND entry_id = ?
      AND expires_at > ?
      ''',
      [queueName, entryId, DateTime.now().millisecondsSinceEpoch],
    );
    return result.isNotEmpty && result.first['lock_id'] == lockId;
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
      // ignore: deprecated_member_use
      stmt.dispose();
    }
  }

  /// Returns the number of currently held locks
  Future<int> activeLockCount() async {
    await _cleanupExpiredLocks();
    final result = _db.select('SELECT COUNT(*) as count FROM $_tableName');
    return result.first['count'] as int;
  }

  /// Releases every lock this instance is holding.
  ///
  /// Locks held by other processes, isolates, or storage instances are left
  /// alone; releasing those would hand their in-flight entries to another
  /// consumer while they are still being processed.
  Future<int> releaseAllLocks() async {
    if (_ownedLocks.isEmpty) return 0;

    final stmt = _db.prepare('''
      DELETE FROM $_tableName
      WHERE lock_id = ?
    ''');
    var released = 0;
    try {
      for (final lockId in _ownedLocks.values) {
        stmt.execute([lockId]);
        released += _db.updatedRows;
      }
    } finally {
      // ignore: deprecated_member_use
      stmt.dispose();
    }
    _ownedLocks.clear();
    return released;
  }
}