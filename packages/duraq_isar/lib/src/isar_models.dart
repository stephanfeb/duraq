import 'package:isar/isar.dart';
import 'package:duraq/duraq.dart';

part 'isar_models.g.dart';

/// Separates the parts of a composite key so that a queue named `a-b` holding
/// entry `c` cannot collide with queue `a` holding entry `b-c`.
const _keySeparator = '\u001f'; // ASCII unit separator

/// The index value identifying one entry. Queries must build the key the same
/// way the indexed getter does, so both go through here.
String entryKeyFor(String queueName, String entryId) =>
    '$queueName$_keySeparator$entryId';

/// The index value covering every entry of one status in one queue.
String queueStatusKeyFor(String queueName, EntryStatus status) =>
    '$queueName$_keySeparator${status.name}';

/// The index value identifying the lock on one entry.
String lockKeyFor(String queueName, String entryId) =>
    '$queueName$_keySeparator$entryId';

/// Isar collection for queue metadata
@collection
class QueueCollection {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String name;

  late DateTime createdAt;
  late DateTime lastUpdatedAt;
}

/// Isar collection for queue entries
///
/// The indexes here exist to serve the queries this package actually runs.
/// Every query goes through [entryKey], [queueStatusKey], or [status]; indexing
/// anything else costs write time on each store and buys nothing on read.
@collection
class QueueEntryCollection {
  Id id = Isar.autoIncrement;

  /// Not indexed on its own. It was, so that a store could tell whether an id
  /// was already used by *another* queue, back when ids had to be unique across
  /// the whole database. Ids are per queue now, so every lookup goes through
  /// [entryKey] and an index here would cost write time and buy nothing.
  late String entryId;

  /// Indexed with [expiresAt] so the expiry sweep on the retrieval path is a
  /// seek over the entries of one queue that actually carry a deadline,
  /// instead of a walk over everything pending in it.
  @Index(composite: [CompositeIndex('expiresAt')])
  late String queueName;

  late String data; // JSON-encoded data
  late DateTime createdAt;
  late DateTime lastUpdatedAt;

  DateTime? expiresAt;

  DateTime? scheduledFor;

  DateTime? nextRetryAt;

  late int attempts;

  late int priority;

  /// Indexed on its own so stranded entries can be reclaimed across every
  /// queue at once, which is what startup recovery does.
  @Index()
  @Enumerated(EnumType.name)
  late EntryStatus status;

  String? errorMessage;

  /// The identity of an entry: one row per queue and entry id.
  ///
  /// Deliberately not a unique index, and it cannot become one. Isar applies
  /// indexes at `Isar.open`, before any migration can run, so a release that
  /// marked this unique would fail to open a database holding duplicates —
  /// measured, not assumed — with `IsarError: Unique index violated`. The
  /// caller owns that `Isar.open` call and shares the instance with their own
  /// collections, so the failure would take out their whole database, not just
  /// the queue. `store` upserts through this index instead,
  /// `removeDuplicateEntries` collapses rows an earlier version left behind,
  /// and `isar_semantics_test.dart` asserts the invariant the index would have
  /// enforced. See the Isar entry index decision in `docs/audit/`.
  @Index()
  String get entryKey => entryKeyFor(queueName, entryId);

  /// Drives retrieval and counting: everything with one status in one queue,
  /// held in the order retrieval wants it, so reads need no in-memory sort.
  @Index(composite: [CompositeIndex('priority'), CompositeIndex('createdAt')])
  String get queueStatusKey => queueStatusKeyFor(queueName, status);
}

/// Isar collection for queue entry locks (concurrent processing)
@collection
class QueueLockCollection {
  Id id = Isar.autoIncrement;

  late String queueName;

  late String entryId;

  /// Identifies the holder, so a lock manager can release its own locks
  /// without touching locks held by another consumer.
  @Index(unique: true)
  late String lockId;

  late DateTime acquiredAt;

  /// Indexed for expiry sweeps.
  @Index()
  late DateTime expiresAt;

  /// One lock per queue and entry.
  @Index(unique: true)
  String get lockKey => lockKeyFor(queueName, entryId);
}

/// Isar collection recording the schema this database was written for.
///
/// Isar migrates its own structure — adding a collection, an index or a field
/// is handled for us — but nothing recorded which release's *data* conventions
/// a database follows, so a change of meaning had no way to reach databases
/// already in the field, and a database written by a newer release was opened
/// as if nothing had changed. This is the SQLite `user_version` pragma's
/// counterpart, which Isar has no equivalent of.
///
/// Exactly one row, at [metaRowId].
@collection
class QueueMetaCollection {
  /// The single row's id. Fixed rather than auto-incremented, so writing the
  /// version is an upsert and two writers cannot create two rows.
  Id id = metaRowId;

  /// The schema version the database is at.
  late int schemaVersion;

  /// When that version was recorded.
  late DateTime updatedAt;
}

/// The id of the single row in [QueueMetaCollection].
const Id metaRowId = 1;
