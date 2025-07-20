import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

import '../queue_entry.dart';
import '../concurrent.dart';
import 'storage_interface.dart';

/// SQLite-based implementation of StorageInterface
class SQLiteStorage implements StorageInterface {
  late final Database _db;
  final String dbPath;
  
  /// Queue lock manager
  late final QueueLock _lock;
  
  /// Tracks the current transaction depth
  int _transactionDepth = 0;
  
  /// Whether the database has been disposed
  bool _isDisposed = false;

  /// Default lock duration for queue entries
  static const defaultLockDuration = Duration(minutes: 5);

  SQLiteStorage({required this.dbPath}) {
    _initDatabase();
  }

  void _initDatabase() {
    // Ensure directory exists
    final dir = Directory(path.dirname(dbPath));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    // Open database with extended options
    _db = sqlite3.open(
      dbPath,
      mode: OpenMode.readWriteCreate,
    );

    // Enable foreign keys and WAL mode for better concurrency
    _db.execute('PRAGMA foreign_keys = ON');
    _db.execute('PRAGMA journal_mode = WAL');
    
    // Initialize lock manager
    _lock = QueueLock(_db);
    
    _createTables();
  }

  void _createTables() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS queues (
        name TEXT PRIMARY KEY
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS queue_entries (
        id TEXT PRIMARY KEY,
        queue_name TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        expires_at INTEGER,
        scheduled_for INTEGER,
        next_retry_at INTEGER,
        attempts INTEGER NOT NULL DEFAULT 0,
        priority INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        error_message TEXT,
        FOREIGN KEY (queue_name) REFERENCES queues(name)
      )
    ''');

    // Add index for efficient priority-based retrieval
    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_queue_entries_retrieval 
      ON queue_entries(queue_name, status, priority, created_at)
    ''');

    // Add index for TTL cleanup
    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_queue_entries_expiration
      ON queue_entries(expires_at)
      WHERE expires_at IS NOT NULL
    ''');

    // Add index for retry scheduling
    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_queue_entries_retry
      ON queue_entries(next_retry_at)
      WHERE next_retry_at IS NOT NULL
    ''');

    // Add index for scheduled execution
    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_queue_entries_scheduled
      ON queue_entries(scheduled_for)
      WHERE scheduled_for IS NOT NULL
    ''');
  }

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('Cannot use disposed SQLiteStorage');
    }
  }

  @override
  Future<void> beginTransaction() async {
    _checkDisposed();
    if (_transactionDepth == 0) {
      _db.execute('BEGIN IMMEDIATE TRANSACTION');
    } else {
      _db.execute('SAVEPOINT transaction_$_transactionDepth');
    }
    _transactionDepth++;
  }

  @override
  Future<void> commitTransaction() async {
    _checkDisposed();
    if (_transactionDepth == 0) {
      throw StateError('No transaction to commit');
    }

    _transactionDepth--;
    if (_transactionDepth == 0) {
      _db.execute('COMMIT');
    } else {
      _db.execute('RELEASE SAVEPOINT transaction_$_transactionDepth');
    }
  }

  @override
  Future<void> rollbackTransaction() async {
    _checkDisposed();
    if (_transactionDepth == 0) {
      throw StateError('No transaction to rollback');
    }

    _transactionDepth--;
    if (_transactionDepth == 0) {
      _db.execute('ROLLBACK');
    } else {
      _db.execute('ROLLBACK TO SAVEPOINT transaction_$_transactionDepth');
    }
  }

  @override
  Future<T> transaction<T>(Future<T> Function() operations) async {
    _checkDisposed();
    await beginTransaction();
    try {
      final result = await operations();
      await commitTransaction();
      return result;
    } catch (e) {
      if (_transactionDepth > 0) {
        await rollbackTransaction();
      }
      rethrow;
    }
  }

  @override
  Future<void> store(String queueName, QueueEntry entry) async {
    _checkDisposed();
    
    // If we're already in a transaction, just execute the statements
    if (_transactionDepth > 0) {
      _storeInternal(queueName, entry);
      return;
    }

    // Otherwise, wrap in a transaction
    await transaction(() async {
      _storeInternal(queueName, entry);
      return null;
    });
  }

  /// Internal method to store an entry without transaction handling
  void _storeInternal(String queueName, QueueEntry entry) {
    // Ensure queue exists
    _db.execute(
      'INSERT OR IGNORE INTO queues (name) VALUES (?)',
      [queueName],
    );

    // If entry is already expired, store it as expired
    final status = entry.isExpired ? EntryStatus.expired : entry.status;

    // Store entry
    _db.execute(
      '''
      INSERT INTO queue_entries (
        id, queue_name, data, created_at, updated_at, expires_at,
        scheduled_for, attempts, priority, status, error_message
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        entry.id,
        queueName,
        jsonEncode({'data': entry.data}),
        entry.createdAt.millisecondsSinceEpoch,
        entry.lastUpdatedAt.millisecondsSinceEpoch,
        entry.expiresAt?.millisecondsSinceEpoch,
        entry.scheduledFor?.millisecondsSinceEpoch,
        entry.attempts,
        entry.priority,
        status.name,
        entry.errorMessage,
      ],
    );
  }

  @override
  Future<QueueEntry?> retrieve(String queueName) async {
    _checkDisposed();
    
    // If we're already in a transaction, just execute the statements
    if (_transactionDepth > 0) {
      return _retrieveInternal(queueName);
    }

    // Otherwise, wrap in a transaction
    return transaction(() async {
      return _retrieveInternal(queueName);
    });
  }

  /// Internal method to retrieve an entry without transaction handling
  Future<QueueEntry?> _retrieveInternal(String queueName) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // First, mark expired entries
    _db.execute(
      '''
      UPDATE queue_entries 
      SET status = ?, updated_at = ?
      WHERE queue_name = ? 
      AND status = ?
      AND expires_at IS NOT NULL 
      AND expires_at <= ?
      ''',
      [
        EntryStatus.expired.name,
        now,
        queueName,
        EntryStatus.pending.name,
        now,
      ],
    );

    // Find the next available entry
    final result = _db.select(
      '''
      SELECT * FROM queue_entries
      WHERE queue_name = ? 
      AND status = ?
      AND (expires_at IS NULL OR expires_at > ?)
      AND (scheduled_for IS NULL OR scheduled_for <= ?)
      ORDER BY priority ASC, created_at ASC
      LIMIT 1
      ''',
      [
        queueName,
        EntryStatus.pending.name,
        now,
        now,
      ],
    );

    if (result.isEmpty) {
      return null;
    }

    final row = result.first;
    final entryId = row['id'] as String;

    // Try to acquire a lock on the entry
    final lockId = await _lock.tryAcquire(
      queueName,
      entryId,
      lockDuration: defaultLockDuration,
    );

    // If we couldn't acquire the lock, try the next entry
    if (lockId == null) {
      return _retrieveInternal(queueName);
    }

    final data = jsonDecode(row['data'] as String)['data'];
    
    // Update the entry status to processing
    _db.execute(
      '''
      UPDATE queue_entries 
      SET status = ?, updated_at = ?
      WHERE id = ?
      ''',
      [
        EntryStatus.processing.name,
        now,
        entryId,
      ],
    );

    return QueueEntry(
      id: entryId,
      data: data,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      attempts: row['attempts'] as int,
      priority: row['priority'] as int,
      status: EntryStatus.processing,
      errorMessage: row['error_message'] as String?,
      expiresAt: row['expires_at'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(row['expires_at'] as int)
        : null,
      nextRetryAt: row['next_retry_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch(row['next_retry_at'] as int)
        : null,
    );
  }

  /// Removes expired entries from the queue
  Future<int> cleanupExpiredEntries() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // First count how many entries will be deleted
    final countResult = _db.select(
      '''
      SELECT COUNT(*) as count
      FROM queue_entries 
      WHERE status = ? 
      AND updated_at <= ?
      ''',
      [
        EntryStatus.expired.name,
        now - Duration(hours: 24).inMilliseconds,
      ],
    );
    final count = countResult.first['count'] as int;

    // Mark entries as expired
    _db.execute(
      '''
      UPDATE queue_entries 
      SET status = ?, updated_at = ?
      WHERE status = ?
      AND expires_at IS NOT NULL 
      AND expires_at <= ?
      ''',
      [
        EntryStatus.expired.name,
        now,
        EntryStatus.pending.name,
        now,
      ],
    );

    // Remove expired entries older than 24 hours
    _db.execute(
      '''
      DELETE FROM queue_entries 
      WHERE status = ? 
      AND updated_at <= ?
      ''',
      [
        EntryStatus.expired.name,
        now - Duration(hours: 24).inMilliseconds,
      ],
    );

    return count;
  }

  @override
  Future<int> count(String queueName) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = _db.select(
      '''
      SELECT COUNT(*) as count 
      FROM queue_entries 
      WHERE queue_name = ? 
      AND status = ?
      AND (expires_at IS NULL OR expires_at > ?)
      ''',
      [queueName, EntryStatus.pending.name, now],
    );
    return result.first['count'] as int;
  }

  @override
  Future<List<String>> listQueues() async {
    final result = _db.select('SELECT name FROM queues');
    return result.map((row) => row['name'] as String).toList();
  }

  @override
  Future<void> removeQueue(String queueName) async {
    await transaction(() async {
      _db.execute(
        'DELETE FROM queue_entries WHERE queue_name = ?',
        [queueName],
      );
      _db.execute(
        'DELETE FROM queues WHERE name = ?',
        [queueName],
      );
      return null;
    });
  }

  @override
  Future<void> removeEntry(String queueName, String entryId) async {
    _db.execute(
      'DELETE FROM queue_entries WHERE queue_name = ? AND id = ?',
      [queueName, entryId],
    );
  }

  /// Updates the status of a queue entry
  @override
  Future<void> updateEntryStatus(
    String queueName,
    String entryId,
    EntryStatus status, {
    String? errorMessage,
    DateTime? nextRetryAt,
  }) async {
    _checkDisposed();

    // Release the lock if the entry is completed or failed
    if (status == EntryStatus.completed || status == EntryStatus.failed) {
      await _lock.release(queueName, entryId, '${queueName}_${entryId}_*');
    }

    _db.execute(
      '''
      UPDATE queue_entries 
      SET status = ?, updated_at = ?, error_message = ?, next_retry_at = ?
      WHERE queue_name = ? AND id = ?
      ''',
      [
        status.name,
        DateTime.now().millisecondsSinceEpoch,
        errorMessage,
        nextRetryAt?.millisecondsSinceEpoch,
        queueName,
        entryId,
      ],
    );
  }

  /// Retrieves all entries with a specific status from a queue
  Future<List<QueueEntry>> getEntriesByStatus(
    String queueName,
    EntryStatus status,
  ) async {
    final result = _db.select(
      '''
      SELECT * FROM queue_entries
      WHERE queue_name = ? AND status = ?
      ORDER BY priority ASC, created_at ASC
      ''',
      [queueName, status.name],
    );

    return result.map((row) {
      final data = jsonDecode(row['data'] as String)['data'];
      return QueueEntry(
        id: row['id'] as String,
        data: data,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        attempts: row['attempts'] as int,
        priority: row['priority'] as int,
        status: status,
        errorMessage: row['error_message'] as String?,
      );
    }).toList();
  }

  /// Disposes of the storage
  void dispose() {
    if (!_isDisposed) {
      if (_transactionDepth > 0) {
        try {
          _db.execute('ROLLBACK');
        } catch (_) {
          // Ignore errors during disposal
        }
        _transactionDepth = 0;
      }
      
      // Release all locks before disposing
      _lock.releaseAllLocks();
      
      _db.dispose();
      _isDisposed = true;
    }
  }

  @override
  Future<QueueEntry<T>?> retrieveDeadLetter<T>(String queueName) async {
    _checkDisposed();
    final result = _db.select(
      '''
      SELECT * FROM queue_entries
      WHERE queue_name = ? AND status = ?
      ORDER BY updated_at ASC
      LIMIT 1
      ''',
      [queueName, EntryStatus.deadLetter.name],
    );

    if (result.isEmpty) return null;

    final row = result.first;
    final data = jsonDecode(row['data'] as String)['data'];
    return QueueEntry<T>(
      id: row['id'] as String,
      data: data as T,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      attempts: row['attempts'] as int,
      priority: row['priority'] as int,
      status: EntryStatus.deadLetter,
      errorMessage: row['error_message'] as String?,
      expiresAt: row['expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['expires_at'] as int)
          : null,
      nextRetryAt: row['next_retry_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['next_retry_at'] as int)
          : null,
    );
  }

  @override
  Future<List<QueueEntry<T>>> listDeadLetters<T>(
    String queueName, {
    int? limit,
    int? offset,
  }) async {
    _checkDisposed();
    final result = _db.select(
      '''
      SELECT * FROM queue_entries
      WHERE queue_name = ? AND status = ?
      ORDER BY updated_at ASC
      LIMIT ? OFFSET ?
      ''',
      [
        queueName,
        EntryStatus.deadLetter.name,
        limit ?? 100,
        offset ?? 0,
      ],
    );

    return result.map((row) {
      final data = jsonDecode(row['data'] as String)['data'];
      return QueueEntry<T>(
        id: row['id'] as String,
        data: data as T,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
        attempts: row['attempts'] as int,
        priority: row['priority'] as int,
        status: EntryStatus.deadLetter,
        errorMessage: row['error_message'] as String?,
        expiresAt: row['expires_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(row['expires_at'] as int)
            : null,
        nextRetryAt: row['next_retry_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(row['next_retry_at'] as int)
            : null,
      );
    }).toList();
  }

  @override
  Future<void> retryDeadLetter(String queueName, String entryId) async {
    _checkDisposed();
    await transaction(() async {
      final result = _db.select(
        '''
        SELECT * FROM queue_entries
        WHERE queue_name = ? AND id = ? AND status = ?
        ''',
        [queueName, entryId, EntryStatus.deadLetter.name],
      );

      if (result.isEmpty) return;

      _db.execute(
        '''
        UPDATE queue_entries
        SET status = ?, updated_at = ?, next_retry_at = NULL
        WHERE queue_name = ? AND id = ?
        ''',
        [
          EntryStatus.pending.name,
          DateTime.now().millisecondsSinceEpoch,
          queueName,
          entryId,
        ],
      );
      return null;
    });
  }

  @override
  Future<void> removeDeadLetter(String queueName, String entryId) async {
    _checkDisposed();
    _db.execute(
      '''
      DELETE FROM queue_entries
      WHERE queue_name = ? AND id = ? AND status = ?
      ''',
      [queueName, entryId, EntryStatus.deadLetter.name],
    );
  }

  @override
  Future<int> purgeDeadLetters(String queueName, DateTime cutoff) async {
    _checkDisposed();
    final timestamp = cutoff.millisecondsSinceEpoch;
    
    // First count how many entries will be deleted
    final countResult = _db.select(
      '''
      SELECT COUNT(*) as count
      FROM queue_entries
      WHERE queue_name = ? AND status = ? AND updated_at < ?
      ''',
      [queueName, EntryStatus.deadLetter.name, timestamp],
    );
    final count = countResult.first['count'] as int;

    // Then delete them
    _db.execute(
      '''
      DELETE FROM queue_entries
      WHERE queue_name = ? AND status = ? AND updated_at < ?
      ''',
      [queueName, EntryStatus.deadLetter.name, timestamp],
    );

    return count;
  }

  @override
  Future<int> countDeadLetters(String queueName) async {
    _checkDisposed();
    final result = _db.select(
      '''
      SELECT COUNT(*) as count
      FROM queue_entries
      WHERE queue_name = ? AND status = ?
      ''',
      [queueName, EntryStatus.deadLetter.name],
    );
    return result.first['count'] as int;
  }

  @override
  Future<List<QueueEntry>> retrieveAll(String queueName) async {
    _checkDisposed();
    
    final result = _db.select(
      '''
      SELECT * FROM queue_entries 
      WHERE queue_name = ?
      ORDER BY priority DESC, created_at ASC
      ''',
      [queueName],
    );
    
    return result.map((row) => QueueEntry(
      id: row['id'] as String,
      data: jsonDecode(row['data'] as String)['data'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      expiresAt: row['expires_at'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(row['expires_at'] as int)
        : null,
      scheduledFor: row['scheduled_for'] != null
        ? DateTime.fromMillisecondsSinceEpoch(row['scheduled_for'] as int)
        : null,
      attempts: row['attempts'] as int,
      priority: row['priority'] as int,
      status: EntryStatus.values.byName(row['status'] as String),
      errorMessage: row['error_message'] as String?,
    )).toList();
  }

  @override
  Future<void> ping() async {
    _checkDisposed();
    try {
      _db.execute('SELECT 1');
    } catch (e) {
      throw Exception('SQLite storage is not responsive: ${e.toString()}');
    }
  }
} 