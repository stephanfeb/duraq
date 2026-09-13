/// Translates a payload between the type a queue hands you and a form the
/// storage can persist.
///
/// Payloads are stored as JSON. Without a codec that limits a queue to what
/// `jsonEncode` accepts — numbers, strings, booleans, null, and lists and maps
/// of those — and a `Queue<Invoice>` fails at enqueue with
/// `JsonUnsupportedObjectError` from inside the storage, despite its type
/// argument saying otherwise. A codec makes the boundary explicit and lifts the
/// restriction:
///
/// ```dart
/// final invoices = Queue<Invoice>(
///   'invoices',
///   storage,
///   codec: QueueCodec.from(
///     encode: (invoice) => invoice.toJson(),
///     decode: (stored) => Invoice.fromJson(stored! as Map<String, dynamic>),
///   ),
/// );
/// ```
///
/// [encode] must return something `jsonEncode` accepts. [decode] receives
/// exactly what `jsonDecode` produced, so a `Map` comes back as
/// `Map<String, dynamic>` and every number as `int` or `double` regardless of
/// what went in.
///
/// Both directions must be pure and must not depend on state that could be gone
/// by the time the entry is read: an entry can be decoded in a later run of the
/// program, by a different consumer, long after it was written.
abstract class QueueCodec<T> {
  const QueueCodec();

  /// Creates a codec from a pair of functions, for the common case where the
  /// payload already knows how to convert itself.
  factory QueueCodec.from({
    required Object? Function(T value) encode,
    required T Function(Object? stored) decode,
  }) = _FunctionCodec<T>;

  /// Converts [value] into something the storage can persist as JSON.
  Object? encode(T value);

  /// Rebuilds a payload from what [encode] produced.
  T decode(Object? stored);
}

class _FunctionCodec<T> implements QueueCodec<T> {
  final Object? Function(T value) _encode;
  final T Function(Object? stored) _decode;

  const _FunctionCodec({
    required Object? Function(T value) encode,
    required T Function(Object? stored) decode,
  })  : _encode = encode,
        _decode = decode;

  @override
  Object? encode(T value) => _encode(value);

  @override
  T decode(Object? stored) => _decode(stored);
}
