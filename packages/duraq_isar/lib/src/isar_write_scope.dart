import 'dart:async';

import 'package:isar/isar.dart';

/// Runs write operations inside a single Isar write transaction.
///
/// Isar has no nested transactions, so an operation that is already running
/// inside one must join it rather than opening another. Membership is tracked
/// through the [Zone] the body runs in, which follows `await` boundaries inside
/// that body without leaking to unrelated callers.
///
/// This is what lets `transaction()` give real atomicity: the whole body runs
/// in one Isar write transaction, and the individual storage operations inside
/// it join that transaction instead of committing separately.
class IsarWriteScope {
  static const Object _zoneKey = #duraqIsarWriteScope;

  const IsarWriteScope._();

  /// Whether the current execution context is already inside a write
  /// transaction opened for [isar] through [run].
  static bool isActive(Isar isar) => identical(Zone.current[_zoneKey], isar);

  /// Runs [action] inside a write transaction on [isar], joining the
  /// transaction already in progress if there is one.
  static Future<T> run<T>(Isar isar, Future<T> Function() action) {
    if (isActive(isar)) return action();
    return isar.writeTxn(
      () => runZoned(action, zoneValues: {_zoneKey: isar}),
    );
  }
}
