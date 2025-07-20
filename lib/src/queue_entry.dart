/// Status of a queue entry
enum EntryStatus {
  pending,
  processing,
  completed,
  failed,
  expired,
  deadLetter,
}

/// Represents an entry in a queue
class QueueEntry<T> {
  /// Unique identifier for this entry
  final String id;

  /// The data stored in this entry
  final T data;

  /// When this entry was created
  final DateTime createdAt;

  /// When this entry was last updated
  final DateTime lastUpdatedAt;

  /// When this entry expires (optional)
  final DateTime? expiresAt;

  /// When this entry should be processed (optional)
  final DateTime? scheduledFor;

  /// Number of processing attempts
  final int attempts;

  /// Priority of this entry (lower is higher priority)
  final int priority;

  /// Current status of this entry
  final EntryStatus status;

  /// Error message if the entry failed
  final String? errorMessage;

  /// Next retry attempt scheduled for
  final DateTime? nextRetryAt;

  /// Creates a new queue entry
  QueueEntry({
    required this.id,
    required this.data,
    required this.createdAt,
    DateTime? lastUpdatedAt,
    this.expiresAt,
    this.scheduledFor,
    this.attempts = 0,
    this.priority = 0,
    this.status = EntryStatus.pending,
    this.errorMessage,
    this.nextRetryAt,
  }) : lastUpdatedAt = lastUpdatedAt ?? createdAt;

  /// Whether this entry has expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Whether this entry is ready to be processed
  bool get isScheduledForNow {
    if (scheduledFor == null) return true;
    return DateTime.now().isAfter(scheduledFor!);
  }

  /// Creates a copy of this entry with updated fields
  QueueEntry<T> copyWith({
    String? id,
    T? data,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
    DateTime? expiresAt,
    DateTime? scheduledFor,
    int? attempts,
    int? priority,
    EntryStatus? status,
    String? errorMessage,
    DateTime? nextRetryAt,
  }) {
    return QueueEntry<T>(
      id: id ?? this.id,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      attempts: attempts ?? this.attempts,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
    );
  }

  /// Creates a failed copy of this entry
  QueueEntry<T> markFailed(String error) {
    return copyWith(
      status: EntryStatus.failed,
      errorMessage: error,
      attempts: attempts + 1,
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Creates a completed copy of this entry
  QueueEntry<T> markCompleted() {
    return copyWith(
      status: EntryStatus.completed,
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Creates a copy of this entry scheduled for retry
  QueueEntry<T> scheduleRetry(DateTime retryAt) {
    return copyWith(
      status: EntryStatus.pending,
      nextRetryAt: retryAt,
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Creates a copy of this entry marked as dead letter
  QueueEntry<T> markDeadLetter() {
    return copyWith(
      status: EntryStatus.deadLetter,
      lastUpdatedAt: DateTime.now(),
    );
  }
} 