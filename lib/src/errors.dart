/// Base class for errors raised by DuraQ itself.
///
/// Storage backends translate driver-specific failures into these, so callers
/// can handle them without catching `SqliteException`, `IsarError`, or whatever
/// a custom backend happens to throw.
class DuraQException implements Exception {
  /// What went wrong, in terms of the queue rather than the driver.
  final String message;

  /// The driver error this was translated from, when there was one.
  final Object? cause;

  const DuraQException(this.message, {this.cause});

  @override
  String toString() => 'DuraQException: $message';
}

/// Thrown when another process or isolate held the database's write lock for
/// longer than the configured wait.
///
/// Only SQLite raises this, and only when several processes share one database
/// file. Raising the storage's `busyTimeout` gives a contended writer longer to
/// get in; the work itself is untouched, so retrying the call is safe.
class StorageBusyException extends DuraQException {
  /// How long the write lock was waited for before giving up.
  final Duration waited;

  StorageBusyException(this.waited, {Object? cause})
      : super(
          'Could not get the database write lock within '
          '${waited.inMilliseconds}ms. Another process or isolate is holding '
          'it. Raise busyTimeout if writes from several processes are '
          'expected to overlap.',
          cause: cause,
        );

  @override
  String toString() => 'StorageBusyException: $message';
}

/// Thrown when storing an entry whose id is already in the storage.
///
/// Raised by `store` under [StoreConflict.fail], which is the default. Pass
/// [StoreConflict.replace] to overwrite the existing entry, or
/// [StoreConflict.ignore] to keep it, when a repeated store is expected. That
/// is the usual case for a producer that retries an enqueue it did not get an
/// answer for.
///
/// The entry payload is deliberately not part of the message: a duplicate id is
/// often logged, and the payload may be sensitive.
class DuplicateEntryException extends DuraQException {
  /// The queue the entry was being stored in.
  final String queueName;

  /// The id that was already present.
  final String entryId;

  DuplicateEntryException(this.queueName, this.entryId, {Object? cause})
      : super(
          'An entry with id "$entryId" is already stored. Pass '
          'StoreConflict.replace to overwrite it or StoreConflict.ignore to '
          'keep the existing entry.',
          cause: cause,
        );

  @override
  String toString() =>
      'DuplicateEntryException: queue "$queueName" already holds an entry '
      'with id "$entryId"';
}
