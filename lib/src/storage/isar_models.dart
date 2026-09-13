import 'package:isar/isar.dart';
import '../queue_entry.dart';

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

  /// Indexed so a store can tell whether an id is already used by another
  /// queue. Entry ids are unique across the storage, matching SQLite, where
  /// the entry id is the table's primary key.
  @Index()
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
  /// Deliberately not a unique index. Databases written by earlier versions
  /// may already hold duplicate rows for one entry, and Isar refuses to open a
  /// database whose data violates a unique index, which would turn an upgrade
  /// into a startup failure. `store` upserts through this index instead, and
  /// `removeDuplicateEntries` collapses rows an earlier version left behind.
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
