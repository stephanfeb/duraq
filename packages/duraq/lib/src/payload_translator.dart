import 'dart:convert';

import 'codec.dart';
import 'errors.dart';

/// Moves payloads between the type a queue declares and the JSON the storage
/// holds, and turns every way that can fail into a [PayloadCodecException].
///
/// Internal. `Queue` and `DeadLetterQueue` both read entries written by the
/// same producer, so they have to agree on how a payload is rebuilt.
class PayloadTranslator<T> {
  /// The queue whose payloads these are, named in any error.
  final String queueName;

  /// Null means payloads are stored as JSON directly.
  final QueueCodec<T>? codec;

  const PayloadTranslator(this.queueName, this.codec);

  /// Converts a payload into something the storage can hold.
  Object? encode(T value) => codec == null ? value : codec!.encode(value);

  /// Rebuilds a payload coming out of the storage.
  T decode(Object? stored) {
    final codec = this.codec;
    if (codec != null) {
      try {
        return codec.decode(stored);
      } on PayloadCodecException {
        rethrow;
      } catch (e) {
        throw PayloadCodecException.decoding(queueName, T, cause: e);
      }
    }

    if (stored is T) return stored;
    throw PayloadCodecException.mismatch(queueName, T, stored);
  }

  /// Runs [write], reporting a payload the storage cannot hold as an error that
  /// names the queue and the type rather than the failing conversion.
  Future<void> guardWrite(Future<void> Function() write) async {
    try {
      await write();
    } on JsonUnsupportedObjectError catch (e) {
      throw PayloadCodecException.encoding(
        queueName,
        T,
        hasCodec: codec != null,
        cause: e,
      );
    }
  }
}
