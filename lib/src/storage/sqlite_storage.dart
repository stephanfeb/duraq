import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

import '../errors.dart';
import '../queue_entry.dart';
import '../concurrent.dart';
import '../concurrent/serial_lock.dart';
import 'maintenance.dart';
import 'sqlite_schema.dart';
import 'storage_interface.dart';

/// SQLite-based implementation of StorageInterface
/// How hard SQLite works to make a commit survive the machine going down.
///
/// Maps onto SQLite's `synchronous` pragma. The trade is durability against
/// write throughput; none of these settings affect what a DuraQ process losing
/// *itself* survives, only what survives the operating system or the power
/// going away underneath it.
enum SqliteSynchronous {
  /// No syncing at all. Fastest, and a crash of the machine can leave the
  /// database corrupt, not merely missing recent work. Do not use this for a
  /// queue holding anything worth keeping.
  off('OFF', 0),

  /// Sync at checkpoints rather than every commit. The default, and the usual
  /// setting for write-ahead logging: the database stays consistent across a
  /// machine crash, but the most recent commits can be lost.
  normal('NORMAL', 1),

  /// Sync on every commit. A job that was accepted is on the disk before the
  /// call returns, at the cost of an fsync per commit.
  full('FULL', 2),

  /// Like [full], and also syncs the directory entry on commit. Slower still,
  /// and only meaningful on filesystems where that is not implied.
  extra('EXTRA', 3);

  const SqliteSynchronous(this.pragmaValue, this.pragmaCode);

  /// The value written into `PRAGMA synchronous`.
  final String pragmaValue;

  /// The number `PRAGMA synchronous` reads back as.
  final int pragmaCode;
}

class SQLiteStorage implements StorageInterface {
  late final Database _db;
  final String dbPath;
  
  /// Queue lock manager
  late final QueueLock _lock;

  /// Serializes operations so that only one logical caller is inside a
  /// transaction at a time. Without it, concurrent callers interleave at their
  /// `await` points and nest inside each other's transactions by accident.
  final SerialLock _serial = SerialLock();

  /// Held for the lifetime of a manually managed transaction, and completed
  /// when that transaction commits or rolls back.
  Completer<void>? _manualTransactionRelease;

  /// Tracks the current transaction depth
  int _transactionDepth = 0;
  
  /// Whether the database has been disposed
  bool _isDisposed = false;

  /// Default lock duration for queue entries
  static const defaultLockDuration = Duration(minutes: 5);

  /// Default number of times an entry may be delivered before it is treated as
  /// poisonous and moved to the dead letter queue.
  static const defaultMaxDeliveryAttempts = 5;

  /// How long a retrieved entry stays claimed before another consumer may take
  /// it. A consumer that dies without acknowledging its entry holds it for at
  /// most this long.
  final Duration leaseDuration;

  /// How many times an entry may be handed out before a lease that expires
  /// again sends it to the dead letter queue instead of back to pending. This
  /// is what stops a job that crashes its worker from cycling forever.
  final int maxDeliveryAttempts;

  /// Default time spent waiting for another process to release the write lock.
  static const defaultBusyTimeout = Duration(seconds: 5);

  /// How long to keep trying to start a write when another process or isolate
  /// holds the database's write lock.
  ///
  /// Only relevant when more than one process opens the same file. The wait is
  /// spent in short sleeps between attempts rather than one long block, so the
  /// isolate stays responsive while a contended write is waiting its turn.
  final Duration busyTimeout;

  /// The slice of [busyTimeout] SQLite itself is allowed to block on, per
  /// attempt. Kept short because the driver blocks the isolate while it waits.
  static const _busySlice = Duration(milliseconds: 50);

  /// How hard the database works to survive a crash of the machine.
  ///
  /// Defaults to [SqliteSynchronous.normal], which is what this package has
  /// always used and what write-ahead logging is usually run at. A DuraQ
  /// process that dies loses nothing at this setting: the operating system
  /// still holds the committed data. What it does not survive is the machine
  /// going down — an OS crash or a power cut can lose the most recent commits,
  /// which for a queue means jobs that were accepted disappearing.
  ///
  /// Raise it to [SqliteSynchronous.full] where losing an accepted job matters
  /// more than throughput. That costs an fsync per commit.
  final SqliteSynchronous synchronous;

  SQLiteStorage({
    required this.dbPath,
    this.leaseDuration = defaultLockDuration,
    this.maxDeliveryAttempts = defaultMaxDeliveryAttempts,
    this.busyTimeout = defaultBusyTimeout,
    this.synchronous = SqliteSynchronous.normal,
  }) {
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

    // Setting up the schema means writing, and another process may be doing
    // the same thing at the same moment. Wait out the whole budget here: this
    // runs once, and the constructor cannot wait asynchronously.
    _db.execute('PRAGMA busy_timeout = ${busyTimeout.inMilliseconds}');

    // Enable foreign keys and WAL mode for better concurrency
    _db.execute('PRAGMA foreign_keys = ON');
    _enableWalMode();

    // Unlike journal_mode, this is per connection rather than a property of
    // the file, so it is set on every open. PRAGMA takes no parameters, hence
    // the interpolation; the value comes from an enum, not from a caller.
    _db.execute('PRAGMA synchronous = ${synchronous.pragmaValue}');

    // Initialize lock manager
    _lock = QueueLock(_db);

    _applySchema();

    // From here on the waiting is done between attempts instead, so a
    // contended write never blocks the isolate for more than a slice.
    _db.execute('PRAGMA busy_timeout = ${_busySlice.inMilliseconds}');
  }

  /// Whether [e] means another connection is holding a lock we need.
  static bool _isContention(SqliteException e) =>
      e.resultCode == 5 || e.resultCode == 6; // SQLITE_BUSY, SQLITE_LOCKED

  /// The journal mode the database file is currently in.
  String _journalMode() =>
      (_db.select('PRAGMA journal_mode').first.values.first as String)
          .toLowerCase();

  /// Switches the file to write-ahead logging, which is what lets readers and
  /// a writer work at the same time.
  ///
  /// Unlike an ordinary write, this needs an exclusive lock and does not go
  /// through the busy handler, so two processes opening the same new file at
  /// the same moment can collide. The mode is a property of the file and
  /// persists, so whoever wins the race has done the work for everyone; this
  /// retries briefly and then accepts the mode the file is in rather than
  /// failing to construct.
  void _enableWalMode() {
    if (_journalMode() == 'wal') return;

    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        _db.execute('PRAGMA journal_mode = WAL');
        return;
      } on SqliteException catch (e) {
        if (!_isContention(e)) rethrow;
        if (_journalMode() == 'wal') return; // another process got there first
        sleep(const Duration(milliseconds: 20));
      }
    }
  }

  /// The schema this release writes and understands.
  ///
  /// Version 1 is the shape DuraQ has always had; it was simply never recorded
  /// until now. Raise this when the tables change, and add the step that gets a
  /// database there to the migrations below.
  static const int schemaVersion = 1;

  /// How this database is created and kept up to date.
  ///
  /// `migrations` is empty while there is only one version. It exists so the
  /// next schema change has somewhere to go.
  static final SqliteSchema _schema = SqliteSchema(
    targetVersion: schemaVersion,
    createCurrent: _createTablesIn,
    looksUnversioned: (db) => db
        .select(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
          ['queue_entries'],
        )
        .isNotEmpty,
    migrations: const {},
  );

  /// The synchronous setting this connection is running at.
  ///
  /// Read back from the database rather than reported from [synchronous],
  /// because the setting is per connection: opening the same file elsewhere
  /// says nothing about what this one is doing.
  SqliteSynchronous get activeSynchronous {
    final code = _db.select('PRAGMA synchronous').first.values.first as int;
    return SqliteSynchronous.values.firstWhere(
      (mode) => mode.pragmaCode == code,
      orElse: () => synchronous,
    );
  }

  /// The schema version recorded in the database file.
  ///
  /// Zero only for a file with no tables that has not been opened yet.
  int get storedSchemaVersion => SqliteSchema.versionOf(_db);

  void _applySchema() => _schema.applyTo(_db, label: dbPath);

  static void _createTablesIn(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS queues (
        name TEXT PRIMARY KEY
      )
    ''');

    db.execute('''
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
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_queue_entries_retrieval 
      ON queue_entries(queue_name, status, priority, created_at)
    ''');

    // Add index for TTL cleanup across every queue
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_queue_entries_expiration
      ON queue_entries(expires_at)
      WHERE expires_at IS NOT NULL
    ''');

    // Add index for the per-queue expiry sweep on the retrieval path. Without
    // the leading queue_name the planner prefers the retrieval index and the
    // sweep degrades into a scan of every pending entry in the queue. Partial,
    // so entries without a TTL cost nothing to maintain.
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_queue_entries_queue_expiration
      ON queue_entries(queue_name, expires_at)
      WHERE expires_at IS NOT NULL
    ''');

    // Add index for retry scheduling
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_queue_entries_retry
      ON queue_entries(next_retry_at)
      WHERE next_retry_at IS NOT NULL
    ''');

    // Add index for scheduled execution
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_queue_entries_scheduled
      ON queue_entries(scheduled_for)
      WHERE scheduled_for IS NOT NULL
    ''');
  }

  /// Whether the caller is already inside this storage's critical section,
  /// either through [transaction] or through a manually managed transaction.
  bool get _inTransactionContext =>
      _serial.isHeldByCurrentContext || _manualTransactionRelease != null;

  /// Runs [action] with exclusive access to the database, unless the caller is
  /// already inside the critical section, in which case it runs immediately.
  Future<T> _exclusive<T>(Future<T> Function() action) {
    if (_inTransactionContext) return action();
    return _serial.run(action);
  }

  /// Completes a manually managed transaction once its outermost level closes.
  void _releaseManualTransaction() {
    if (_transactionDepth == 0) {
      _manualTransactionRelease?.complete();
      _manualTransactionRelease = null;
    }
  }

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('Cannot use disposed SQLiteStorage');
    }
  }

  /// Converts a database row to a QueueEntry.
  /// If [statusOverride] is provided, it is used instead of the row's status.
  /// Turns a stored status string into an [EntryStatus].
  ///
  /// `EntryStatus.values.byName` throws `ArgumentError: Invalid argument (name):
  /// No enum value with that name`, which says nothing about which entry, which
  /// queue, or why. A status this release has no name for means a newer DuraQ
  /// wrote the row, and that is worth saying plainly.
  static EntryStatus _statusFromName(String name, String entryId) {
    for (final status in EntryStatus.values) {
      if (status.name == name) return status;
    }
    throw SchemaVersionException.unknownStatus(name, entryId, schemaVersion);
  }

  /// [leaseId] is set when the row is being handed to a consumer.
  QueueEntry<T> _rowToEntry<T>(
    Row row, {
    EntryStatus? statusOverride,
    String? leaseId,
  }) {
    return QueueEntry<T>(
      leaseId: leaseId,
      id: row['id'] as String,
      data: jsonDecode(row['data'] as String) as T,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      attempts: row['attempts'] as int,
      priority: row['priority'] as int,
      status: statusOverride ??
          _statusFromName(row['status'] as String, row['id'] as String),
      errorMessage: row['error_message'] as String?,
      expiresAt: row['expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['expires_at'] as int)
          : null,
      nextRetryAt: row['next_retry_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['next_retry_at'] as int)
          : null,
      scheduledFor: row['scheduled_for'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['scheduled_for'] as int)
          : null,
    );
  }

  /// Opens a transaction or savepoint. The caller must already hold the
  /// critical section.
  ///
  /// A savepoint needs no waiting: the write lock is already held. Starting an
  /// outermost transaction takes the write lock up front, which is where
  /// another process can be in the way, so that one is retried until
  /// [busyTimeout] runs out. Nothing has executed at that point, so retrying
  /// repeats no work.
  Future<void> _beginInternal() async {
    if (_transactionDepth > 0) {
      _db.execute('SAVEPOINT transaction_$_transactionDepth');
      _transactionDepth++;
      return;
    }

    final deadline = DateTime.now().add(busyTimeout);
    var backoff = const Duration(milliseconds: 2);

    while (true) {
      try {
        _db.execute('BEGIN IMMEDIATE TRANSACTION');
        _transactionDepth++;
        return;
      } on SqliteException catch (e) {
        if (!_isContention(e)) rethrow;
        if (!DateTime.now().isBefore(deadline)) {
          throw StorageBusyException(busyTimeout, cause: e);
        }
        await Future<void>.delayed(backoff);
        final next = backoff * 2;
        backoff = next > const Duration(milliseconds: 50)
            ? const Duration(milliseconds: 50)
            : next;
      }
    }
  }

  /// Starts a manually managed transaction.
  ///
  /// The transaction holds exclusive access to the storage until
  /// [commitTransaction] or [rollbackTransaction] closes it, so other callers
  /// queue behind it. Prefer [transaction], which releases the storage even if
  /// the body throws; a manual transaction that is never closed blocks every
  /// later operation.
  @override
  Future<void> beginTransaction() async {
    _checkDisposed();

    if (_inTransactionContext) {
      await _beginInternal();
      return;
    }

    final acquired = Completer<void>();
    final release = Completer<void>();
    unawaited(_serial.run(() async {
      acquired.complete();
      await release.future;
    }));
    await acquired.future;
    _manualTransactionRelease = release;

    try {
      await _beginInternal();
    } catch (_) {
      // Nothing was opened, so do not hold the storage hostage.
      _manualTransactionRelease = null;
      release.complete();
      rethrow;
    }
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
    _releaseManualTransaction();
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
    _releaseManualTransaction();
  }

  @override
  Future<T> transaction<T>(Future<T> Function() operations) {
    _checkDisposed();
    return _exclusive(() async {
      final depthAtEntry = _transactionDepth;
      await beginTransaction();
      try {
        final result = await operations();
        await commitTransaction();
        return result;
      } catch (e) {
        // Only unwind the levels this call opened; an outer transaction keeps
        // whatever it committed before this one started.
        if (_transactionDepth > depthAtEntry) {
          await rollbackTransaction();
        }
        rethrow;
      }
    });
  }

  @override
  Future<void> store(
    String queueName,
    QueueEntry<dynamic> entry, {
    StoreConflict onConflict = StoreConflict.fail,
  }) {
    _checkDisposed();
    return _exclusive(() async {
      // If we're already in a transaction, just execute the statements
      if (_transactionDepth > 0) {
        _storeInternal(queueName, entry, onConflict);
        return;
      }

      // Otherwise, wrap in a transaction
      await transaction(() async {
        _storeInternal(queueName, entry, onConflict);
        return null;
      });
    });
  }

  /// Internal method to store an entry without transaction handling
  void _storeInternal(
    String queueName,
    QueueEntry<dynamic> entry,
    StoreConflict onConflict,
  ) {
    // Ensure queue exists
    _db.execute(
      'INSERT OR IGNORE INTO queues (name) VALUES (?)',
      [queueName],
    );

    // If entry is already expired, store it as expired
    final status = entry.isExpired ? EntryStatus.expired : entry.status;

    // Store entry
    try {
      _db.execute(
        '''
      INSERT INTO queue_entries (
        id, queue_name, data, created_at, updated_at, expires_at,
        scheduled_for, next_retry_at, attempts, priority, status, error_message
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ${_conflictClause(onConflict)}
      ''',
        [
          entry.id,
          queueName,
          jsonEncode(entry.data),
          entry.createdAt.millisecondsSinceEpoch,
          entry.lastUpdatedAt.millisecondsSinceEpoch,
          entry.expiresAt?.millisecondsSinceEpoch,
          entry.scheduledFor?.millisecondsSinceEpoch,
          entry.nextRetryAt?.millisecondsSinceEpoch,
          entry.attempts,
          entry.priority,
          status.name,
          entry.errorMessage,
        ],
      );
    } on SqliteException catch (e) {
      // 1555 is a primary key collision, 2067 a unique index collision. Both
      // mean the id is taken; anything else is a real storage failure and the
      // driver error, which carries the statement and its parameters, must not
      // escape as one.
      if (e.extendedResultCode == 1555 || e.extendedResultCode == 2067) {
        throw DuplicateEntryException(queueName, entry.id, cause: e);
      }
      rethrow;
    }
  }

  /// The conflict handling appended to the insert for [onConflict].
  static String _conflictClause(StoreConflict onConflict) {
    switch (onConflict) {
      case StoreConflict.fail:
        return '';
      case StoreConflict.ignore:
        return 'ON CONFLICT(id) DO NOTHING';
      case StoreConflict.replace:
        return '''
      ON CONFLICT(id) DO UPDATE SET
        queue_name = excluded.queue_name,
        data = excluded.data,
        created_at = excluded.created_at,
        updated_at = excluded.updated_at,
        expires_at = excluded.expires_at,
        scheduled_for = excluded.scheduled_for,
        next_retry_at = excluded.next_retry_at,
        attempts = excluded.attempts,
        priority = excluded.priority,
        status = excluded.status,
        error_message = excluded.error_message
      ''';
    }
  }

  @override
  Future<QueueEntry<dynamic>?> retrieve(String queueName) {
    _checkDisposed();
    return _exclusive(() async {
      // If we're already in a transaction, just execute the statements
      if (_transactionDepth > 0) {
        return _retrieveInternal(queueName);
      }

      // Otherwise, wrap in a transaction
      return transaction(() async {
        return _retrieveInternal(queueName);
      });
    });
  }

  /// Marks pending entries whose deadline has passed as expired, for one queue
  /// or, when [queueName] is null, for every queue.
  ///
  /// Returns the number of entries marked.
  int _markExpiredInternal(String? queueName, int now) {
    if (queueName != null) {
      _db.execute(
        '''
        UPDATE queue_entries
        SET status = ?, updated_at = ?
        WHERE queue_name = ?
        AND status = ?
        AND expires_at IS NOT NULL
        AND expires_at <= ?
        ''',
        [EntryStatus.expired.name, now, queueName, EntryStatus.pending.name, now],
      );
    } else {
      _db.execute(
        '''
        UPDATE queue_entries
        SET status = ?, updated_at = ?
        WHERE status = ?
        AND expires_at IS NOT NULL
        AND expires_at <= ?
        ''',
        [EntryStatus.expired.name, now, EntryStatus.pending.name, now],
      );
    }
    return _db.updatedRows;
  }

  /// Returns entries whose lease has expired without being acknowledged.
  ///
  /// An entry is considered stranded when it is still `processing` but no live
  /// lock covers it, which is what happens when a consumer crashes, is killed,
  /// or takes an entry with `dequeue` and never acknowledges it. Entries that
  /// have been delivered [maxDeliveryAttempts] times go to the dead letter
  /// queue instead of back to the queue.
  ///
  /// Returns the number of entries returned to pending.
  int _reclaimStaleInternal(String? queueName, int now) {
    final queueFilter = queueName != null ? 'AND queue_name = ?' : '';
    final queueArgs = queueName != null ? [queueName] : const <Object?>[];

    // A lock that is still live means the entry is in flight somewhere, even if
    // that somewhere is another process.
    const heldElsewhere = '''
      AND NOT EXISTS (
        SELECT 1 FROM queue_locks l
        WHERE l.queue_name = queue_entries.queue_name
        AND l.entry_id = queue_entries.id
        AND l.expires_at > ?
      )
    ''';

    // Entries that have used up their deliveries are poisonous: park them.
    _db.execute(
      '''
      UPDATE queue_entries
      SET status = ?, attempts = attempts + 1, updated_at = ?, error_message = ?
      WHERE status = ?
      AND attempts + 1 >= ?
      $queueFilter
      $heldElsewhere
      ''',
      [
        EntryStatus.deadLetter.name,
        now,
        'Lease expired without acknowledgement after $maxDeliveryAttempts '
            'deliveries',
        EntryStatus.processing.name,
        maxDeliveryAttempts,
        ...queueArgs,
        now,
      ],
    );

    // Everything else goes back on the queue, available immediately.
    _db.execute(
      '''
      UPDATE queue_entries
      SET status = ?, attempts = attempts + 1, updated_at = ?, next_retry_at = NULL
      WHERE status = ?
      $queueFilter
      $heldElsewhere
      ''',
      [
        EntryStatus.pending.name,
        now,
        EntryStatus.processing.name,
        ...queueArgs,
        now,
      ],
    );

    return _db.updatedRows;
  }

  /// Returns entries whose lease expired without being acknowledged to the
  /// queue, so a crashed or killed consumer does not strand them.
  ///
  /// Retrieval does this for its own queue on every call. Call this directly at
  /// startup to recover entries left behind by a previous run, optionally for a
  /// single queue.
  ///
  /// Returns the number of entries returned to pending. Entries that have been
  /// delivered [maxDeliveryAttempts] times are moved to the dead letter queue
  /// instead and are not counted.
  Future<int> reclaimStaleEntries({String? queueName}) {
    _checkDisposed();
    return _exclusive(() => transaction(() async {
          return _reclaimStaleInternal(
            queueName,
            DateTime.now().millisecondsSinceEpoch,
          );
        }));
  }

  /// Internal method to retrieve an entry without transaction handling
  Future<QueueEntry<dynamic>?> _retrieveInternal(String queueName) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Take back anything a dead consumer left claimed before looking for work.
    _reclaimStaleInternal(queueName, now);

    // First, mark expired entries
    _markExpiredInternal(queueName, now);

    // Walk candidates in batches until we acquire a lock on one. Fetching one
    // row at a time with a growing OFFSET re-reads the head of the queue on
    // every attempt, which is quadratic when the first candidates are locked
    // by another consumer.
    const batchSize = 16;
    var offset = 0;
    while (true) {
      final candidates = _db.select(
        '''
        SELECT * FROM queue_entries
        WHERE queue_name = ?
        AND status = ?
        AND (expires_at IS NULL OR expires_at > ?)
        AND (scheduled_for IS NULL OR scheduled_for <= ?)
        AND (next_retry_at IS NULL OR next_retry_at <= ?)
        ORDER BY priority ASC, created_at ASC
        LIMIT ? OFFSET ?
        ''',
        [
          queueName,
          EntryStatus.pending.name,
          now,
          now,
          now,
          batchSize,
          offset,
        ],
      );

      if (candidates.isEmpty) {
        return null;
      }

      for (final row in candidates) {
        final entryId = row['id'] as String;

        // Try to acquire a lock on the entry
        final lockId = await _lock.tryAcquire(
          queueName,
          entryId,
          lockDuration: leaseDuration,
        );

        // If we couldn't acquire the lock, try the next entry
        if (lockId == null) continue;

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

        return _rowToEntry(
          row,
          statusOverride: EntryStatus.processing,
          leaseId: lockId,
        );
      }

      // Every candidate in this batch is locked elsewhere. If the batch came
      // back short there is nothing further to look at.
      if (candidates.length < batchSize) return null;
      offset += candidates.length;
    }
  }

  /// Removes expired entries from the queue
  Future<int> cleanupExpiredEntries() => _exclusive(_cleanupExpiredEntries);

  Future<int> _cleanupExpiredEntries() async {
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
  Future<int> count(String queueName) => _exclusive(() => _count(queueName));

  Future<int> _count(String queueName) async {
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
  Future<int> countReady(String queueName) => _exclusive(
        () => _countReady(queueName),
      );

  /// Mirrors the predicate [_retrieveInternal] selects candidates with, so the
  /// two cannot drift into disagreeing about what "ready" means.
  Future<int> _countReady(String queueName) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = _db.select(
      '''
      SELECT COUNT(*) as count
      FROM queue_entries
      WHERE queue_name = ?
      AND status = ?
      AND (expires_at IS NULL OR expires_at > ?)
      AND (scheduled_for IS NULL OR scheduled_for <= ?)
      AND (next_retry_at IS NULL OR next_retry_at <= ?)
      ''',
      [queueName, EntryStatus.pending.name, now, now, now],
    );
    return result.first['count'] as int;
  }

  @override
  Future<List<String>> listQueues() => _exclusive(_listQueues);

  Future<List<String>> _listQueues() async {
    final result = _db.select('SELECT name FROM queues');
    return result.map((row) => row['name'] as String).toList();
  }

  @override
  Future<void> removeQueue(String queueName) =>
      _exclusive(() => _removeQueue(queueName));

  Future<void> _removeQueue(String queueName) async {
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
  Future<void> removeEntry(String queueName, String entryId) =>
      _exclusive(() => _removeEntry(queueName, entryId));

  Future<void> _removeEntry(String queueName, String entryId) async {
    _db.execute(
      'DELETE FROM queue_entries WHERE queue_name = ? AND id = ?',
      [queueName, entryId],
    );
    // A lock outlives the entry it guards otherwise, and keeps a dead id
    // marked as claimed until its lease runs out.
    await _lock.release(queueName, entryId);
  }

  /// Updates the status of a queue entry
  @override
  Future<void> updateEntryStatus(
    String queueName,
    String entryId,
    EntryStatus status, {
    String? errorMessage,
    DateTime? nextRetryAt,
    int? attempts,
    String? leaseId,
  }) =>
      _exclusive(() => _updateEntryStatus(
            queueName,
            entryId,
            status,
            errorMessage: errorMessage,
            nextRetryAt: nextRetryAt,
            attempts: attempts,
            leaseId: leaseId,
          ));

  Future<void> _updateEntryStatus(
    String queueName,
    String entryId,
    EntryStatus status, {
    String? errorMessage,
    DateTime? nextRetryAt,
    int? attempts,
    String? leaseId,
  }) async {
    _checkDisposed();

    // A consumer whose lease expired while it was working no longer speaks for
    // this entry: whoever holds the claim now does. Discard the change rather
    // than applying it over their work.
    if (leaseId != null && !await _lock.isHeldBy(queueName, entryId, leaseId)) {
      return;
    }

    // Release the lock unless the entry is still being worked on. Anything
    // else — completed, failed, pending, dead lettered, expired — is finished
    // with its claim, and holding the lease past that point kept the entry
    // unclaimable for the rest of its duration. A dead letter retried inside
    // that window was silently not delivered.
    if (status != EntryStatus.processing) {
      await _lock.release(queueName, entryId, lockId: leaseId);
    }

    // Only the fields the caller named. Writing error_message and
    // next_retry_at on every update meant completing an entry wiped the error
    // that explained its last failure, and any caller that set a status
    // without restating the retry time cleared it.
    final assignments = <String>['status = ?', 'updated_at = ?'];
    final values = <Object?>[status.name, DateTime.now().millisecondsSinceEpoch];

    if (errorMessage != null) {
      assignments.add('error_message = ?');
      values.add(errorMessage);
    }

    if (nextRetryAt != null) {
      assignments.add('next_retry_at = ?');
      values.add(nextRetryAt.millisecondsSinceEpoch);
    } else if (status == EntryStatus.pending) {
      // Pending with no retry time means available now. Keeping an old
      // backoff here would withhold an entry the caller just made ready.
      assignments.add('next_retry_at = NULL');
    }

    if (attempts != null) {
      assignments.add('attempts = ?');
      values.add(attempts);
    }

    _db.execute(
      '''
      UPDATE queue_entries
      SET ${assignments.join(', ')}
      WHERE queue_name = ? AND id = ?
      ''',
      [...values, queueName, entryId],
    );

    if (_db.updatedRows == 0) {
      throw EntryNotFoundException(queueName, entryId);
    }
  }

  /// Retrieves all entries with a specific status from a queue
  Future<List<QueueEntry<dynamic>>> getEntriesByStatus(
    String queueName,
    EntryStatus status,
  ) =>
      _exclusive(() => _getEntriesByStatus(queueName, status));

  Future<List<QueueEntry<dynamic>>> _getEntriesByStatus(
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

    return result.map((row) => _rowToEntry(row, statusOverride: status)).toList();
  }

  /// Releases this storage's resources.
  ///
  /// The interface's teardown, so shutdown can be written without knowing
  /// which backend is underneath. Equivalent to [dispose] here, which stays
  /// for callers already using it.
  @override
  Future<void> close() async => dispose();

  /// Disposes of the storage
  void dispose() {
    if (!_isDisposed) {
      // Let anything queued behind a manual transaction proceed and fail fast
      // on the disposed check rather than waiting forever.
      _manualTransactionRelease?.complete();
      _manualTransactionRelease = null;

      if (_transactionDepth > 0) {
        try {
          _db.execute('ROLLBACK');
        } catch (_) {
          // Ignore errors during disposal
        }
        _transactionDepth = 0;
      }
      
      // Release the locks this instance holds before disposing. A contended
      // database must not turn a shutdown into an exception, and the release
      // reports failure through its future rather than by throwing, so the
      // error has to be handled there. Anything left behind expires on its own.
      unawaited(_lock.releaseAllLocks().catchError((Object _) => 0));

      try {
        _db.dispose();
      } catch (_) {
        // Nothing useful is left to do with a connection we are discarding.
      }
      _isDisposed = true;
    }
  }

  @override
  Future<QueueEntry<T>?> retrieveDeadLetter<T>(String queueName) =>
      _exclusive(() => _retrieveDeadLetter<T>(queueName));

  Future<QueueEntry<T>?> _retrieveDeadLetter<T>(String queueName) async {
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
    return _rowToEntry<T>(result.first);
  }

  @override
  Future<List<QueueEntry<T>>> listDeadLetters<T>(
    String queueName, {
    int? limit,
    int? offset,
  }) =>
      _exclusive(() =>
          _listDeadLetters<T>(queueName, limit: limit, offset: offset));

  Future<List<QueueEntry<T>>> _listDeadLetters<T>(
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

    return result.map((row) => _rowToEntry<T>(row)).toList();
  }

  @override
  Future<void> retryDeadLetter(String queueName, String entryId) =>
      _exclusive(() => _retryDeadLetter(queueName, entryId));

  Future<void> _retryDeadLetter(String queueName, String entryId) async {
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
        SET status = ?, updated_at = ?, next_retry_at = NULL, attempts = 0
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
  Future<void> removeDeadLetter(String queueName, String entryId) =>
      _exclusive(() => _removeDeadLetter(queueName, entryId));

  Future<void> _removeDeadLetter(String queueName, String entryId) async {
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
  Future<int> purgeDeadLetters(String queueName, DateTime cutoff) =>
      _exclusive(() => _purgeDeadLetters(queueName, cutoff));

  Future<int> _purgeDeadLetters(String queueName, DateTime cutoff) async {
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
  Future<int> countDeadLetters(String queueName) =>
      _exclusive(() => _countDeadLetters(queueName));

  Future<int> _countDeadLetters(String queueName) async {
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
  Future<List<QueueEntry<dynamic>>> retrieveAll(String queueName) =>
      _exclusive(() => _retrieveAll(queueName));

  Future<List<QueueEntry<dynamic>>> _retrieveAll(String queueName) async {
    _checkDisposed();
    
    final result = _db.select(
      '''
      SELECT * FROM queue_entries 
      WHERE queue_name = ?
      ORDER BY priority ASC, created_at ASC
      ''',
      [queueName],
    );
    
    return result.map((row) => _rowToEntry(row)).toList();
  }

  @override
  Future<MaintenanceReport> runMaintenance({
    RetentionPolicy policy = const RetentionPolicy(),
    String? queueName,
  }) {
    _checkDisposed();
    return _exclusive(() => transaction(() async {
          final now = DateTime.now().millisecondsSinceEpoch;

          final reclaimed = _reclaimStaleInternal(queueName, now);
          final expired = _markExpiredInternal(queueName, now);

          var removed = 0;
          for (final rule in policy.removable) {
            final cutoff = now - rule.value.inMilliseconds;
            if (queueName != null) {
              _db.execute(
                '''
                DELETE FROM queue_entries
                WHERE queue_name = ? AND status = ? AND updated_at < ?
                ''',
                [queueName, rule.key.name, cutoff],
              );
            } else {
              _db.execute(
                '''
                DELETE FROM queue_entries
                WHERE status = ? AND updated_at < ?
                ''',
                [rule.key.name, cutoff],
              );
            }
            removed += _db.updatedRows;
          }

          return MaintenanceReport(
            reclaimed: reclaimed,
            expired: expired,
            removed: removed,
          );
        }));
  }

  @override
  Future<void> ping() => _exclusive(_ping);

  Future<void> _ping() async {
    _checkDisposed();
    try {
      _db.execute('SELECT 1');
    } catch (e) {
      throw Exception('SQLite storage is not responsive: ${e.toString()}');
    }
  }
} 