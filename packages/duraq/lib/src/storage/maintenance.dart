import '../queue_entry.dart';

/// How long entries that are finished with are kept before maintenance removes
/// them.
///
/// A queue that runs for months otherwise keeps every job it has ever
/// processed. A `null` duration means entries with that status are kept
/// indefinitely, which is the right answer for an audit trail and the wrong one
/// for a database that has to stay small.
class RetentionPolicy {
  /// How long a completed entry is kept.
  final Duration? completed;

  /// How long an entry that failed without being retried is kept.
  final Duration? failed;

  /// How long a dead lettered entry is kept. Longer by default than the rest,
  /// because these are the ones a person still has to look at.
  final Duration? deadLetter;

  /// How long an entry that outlived its own deadline is kept.
  final Duration? expired;

  const RetentionPolicy({
    this.completed = const Duration(days: 7),
    this.failed = const Duration(days: 7),
    this.deadLetter = const Duration(days: 30),
    this.expired = const Duration(days: 1),
  });

  /// Keeps every entry forever. Maintenance will still reclaim stranded
  /// entries and mark expired ones, but will delete nothing.
  const RetentionPolicy.keepEverything()
      : completed = null,
        failed = null,
        deadLetter = null,
        expired = null;

  /// The retention for [status], or null if entries with that status are kept.
  Duration? forStatus(EntryStatus status) {
    switch (status) {
      case EntryStatus.completed:
        return completed;
      case EntryStatus.failed:
        return failed;
      case EntryStatus.deadLetter:
        return deadLetter;
      case EntryStatus.expired:
        return expired;
      case EntryStatus.pending:
      case EntryStatus.processing:
        // Unfinished work is never deleted by retention.
        return null;
    }
  }

  /// The statuses this policy removes, paired with their retention.
  Iterable<MapEntry<EntryStatus, Duration>> get removable sync* {
    for (final status in EntryStatus.values) {
      final age = forStatus(status);
      if (age != null) yield MapEntry(status, age);
    }
  }
}

/// What one maintenance pass did.
class MaintenanceReport {
  /// Entries whose consumer died and which were returned to the queue.
  final int reclaimed;

  /// Entries that outlived their deadline and were marked expired.
  final int expired;

  /// Finished entries deleted under the retention policy.
  final int removed;

  const MaintenanceReport({
    this.reclaimed = 0,
    this.expired = 0,
    this.removed = 0,
  });

  /// Whether the pass changed anything at all.
  bool get isEmpty => reclaimed == 0 && expired == 0 && removed == 0;

  @override
  String toString() => 'MaintenanceReport(reclaimed: $reclaimed, '
      'expired: $expired, removed: $removed)';
}
