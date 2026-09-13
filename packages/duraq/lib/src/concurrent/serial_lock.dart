import 'dart:async';

/// Serializes asynchronous operations so that only one logical caller is inside
/// the critical section at a time.
///
/// Operations are admitted in the order they call [run], and each one runs to
/// completion before the next starts. Calls made from inside a running
/// operation are re-entrant: they execute immediately instead of queueing,
/// which is what lets an operation call other operations without deadlocking.
///
/// Re-entrancy is detected through the [Zone] the operation body runs in, so it
/// follows `await` boundaries within that body but does not leak to unrelated
/// callers that happen to run while the lock is held.
class SerialLock {
  static const Object _zoneKey = #duraqSerialLock;

  /// Completes when every operation admitted so far has finished.
  Future<void> _tail = Future<void>.value();

  /// Whether the current execution context is already inside this lock.
  bool get isHeldByCurrentContext => identical(Zone.current[_zoneKey], this);

  /// Runs [action] with exclusive access, queueing behind any operation that is
  /// already running. Returns whatever [action] returns.
  Future<T> run<T>(Future<T> Function() action) {
    if (isHeldByCurrentContext) return action();

    final release = Completer<void>();
    final predecessor = _tail;
    _tail = release.future;

    return predecessor
        .then((_) => runZoned(action, zoneValues: {_zoneKey: this}))
        .whenComplete(release.complete);
  }
}
