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

/// Thrown when a payload cannot cross the boundary between the type a queue
/// declares and the JSON the storage holds.
///
/// Three things raise it: a payload that `jsonEncode` cannot represent and no
/// codec to convert it, a codec that threw, and an entry whose stored payload
/// is not the type the queue was asked for. Each replaces an error that named
/// only the failing conversion — `JsonUnsupportedObjectError`, or a bare
/// `TypeError` about `String` and `int` — with one that names the queue, the
/// type involved, and what to do about it.
class PayloadCodecException extends DuraQException {
  /// The queue whose payload could not be converted.
  final String queueName;

  /// The element type the queue was declared with.
  final Type payloadType;

  PayloadCodecException._(
    this.queueName,
    this.payloadType,
    String message, {
    Object? cause,
  }) : super(message, cause: cause);

  /// A payload could not be written.
  factory PayloadCodecException.encoding(
    String queueName,
    Type payloadType, {
    required bool hasCodec,
    Object? cause,
  }) =>
      PayloadCodecException._(
        queueName,
        payloadType,
        hasCodec
            ? 'The codec for queue "$queueName" returned something that '
                'cannot be stored as JSON. Its encode must return numbers, '
                'strings, booleans, null, or lists and maps of those.'
            : 'Payloads of type $payloadType cannot be stored as JSON. Give '
                'the queue a QueueCodec to convert them, or enqueue a type '
                'jsonEncode accepts.',
        cause: cause,
      );

  /// A codec threw while rebuilding a payload.
  factory PayloadCodecException.decoding(
    String queueName,
    Type payloadType, {
    Object? cause,
  }) =>
      PayloadCodecException._(
        queueName,
        payloadType,
        'The codec for queue "$queueName" could not rebuild a payload of '
        'type $payloadType from what was stored.',
        cause: cause,
      );

  /// A stored payload is not the type the queue declares.
  factory PayloadCodecException.mismatch(
    String queueName,
    Type payloadType,
    Object? stored,
  ) =>
      PayloadCodecException._(
        queueName,
        payloadType,
        'Queue "$queueName" holds a payload of type ${stored.runtimeType} '
        'where $payloadType was expected. Either the queue was written through '
        'a different element type, or it needs a QueueCodec to rebuild the '
        'payload.',
      );

  @override
  String toString() => 'PayloadCodecException: $message';
}

/// Thrown when an operation names an entry the storage does not hold.
///
/// A status update for an id that is not there used to report success, so a
/// typo, a stale id, or an entry already removed by a retention pass all looked
/// exactly like work completing normally.
///
/// This is not raised when a change is discarded because the caller's lease has
/// expired: the entry exists, and someone else holds the claim on it. That case
/// stays silent by design — see `updateEntryStatus`.
class EntryNotFoundException extends DuraQException {
  /// The queue the entry was looked for in.
  final String queueName;

  /// The id that was not found.
  final String entryId;

  EntryNotFoundException(this.queueName, this.entryId)
      : super(
          'Queue "$queueName" holds no entry with id "$entryId". It may have '
          'been removed by a retention pass, or the id may be wrong.',
        );

  @override
  String toString() => 'EntryNotFoundException: $message';
}
