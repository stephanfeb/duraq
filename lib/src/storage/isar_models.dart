import 'package:isar/isar.dart';
import '../queue_entry.dart';

part 'isar_models.g.dart';

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
@collection
class QueueEntryCollection {
  Id id = Isar.autoIncrement;
  
  @Index()
  late String entryId;
  
  @Index()
  late String queueName;
  
  late String data; // JSON-encoded data
  late DateTime createdAt;
  late DateTime lastUpdatedAt;
  
  @Index()
  DateTime? expiresAt;
  
  @Index()
  DateTime? scheduledFor;
  
  @Index()
  DateTime? nextRetryAt;
  
  @Index()
  late int attempts;
  
  @Index()
  late int priority;
  
  @Index()
  @Enumerated(EnumType.name)
  late EntryStatus status;
  
  String? errorMessage;
  
  // Composite index for efficient retrieval queries (queueName + status + priority)
  @Index(composite: [CompositeIndex('status'), CompositeIndex('priority')])
  String get retrievalKey => '$queueName-${status.name}';
  
  // Index for TTL cleanup
  @Index(name: 'expiration_index')
  int? get expirationTimestamp => expiresAt?.millisecondsSinceEpoch;
  
  // Index for scheduled execution
  @Index(name: 'scheduled_index')
  int? get scheduledTimestamp => scheduledFor?.millisecondsSinceEpoch;
  
  // Index for retry scheduling
  @Index(name: 'retry_index')
  int? get retryTimestamp => nextRetryAt?.millisecondsSinceEpoch;
}

/// Isar collection for queue entry locks (concurrent processing)
@collection
class QueueLockCollection {
  Id id = Isar.autoIncrement;
  
  @Index()
  late String queueName;
  
  @Index()
  late String entryId;
  
  @Index(unique: true)
  late String lockId;
  
  late DateTime acquiredAt;
  
  @Index()
  late DateTime expiresAt;
  
  // Composite index for lock lookup
  @Index(composite: [CompositeIndex('queueName'), CompositeIndex('entryId')], unique: true)
  String get lockKey => '$queueName-$entryId';
  
  // Index for cleanup of expired locks
  @Index(name: 'lock_expiration_index')
  int get expirationTimestamp => expiresAt.millisecondsSinceEpoch;
}
