import '../codec.dart';
import '../payload_translator.dart';
import '../queue_entry.dart';
import '../storage/storage_interface.dart';

/// Handles failed queue entries that have exceeded their retry attempts
class DeadLetterQueue<T> {
  /// The name of the source queue
  final String sourceQueueName;

  /// The storage backend
  final StorageInterface _storage;

  /// Converts payloads back from what the storage holds.
  ///
  /// Must match the codec the source queue was written through: these are the
  /// same entries, moved aside after failing.
  final QueueCodec<T>? codec;

  final PayloadTranslator<T> _payload;

  /// Creates a new dead letter queue for a specific source queue
  DeadLetterQueue(this.sourceQueueName, this._storage, {this.codec})
      : _payload = PayloadTranslator<T>(sourceQueueName, codec);

  /// Retrieves a dead letter entry
  Future<QueueEntry<T>?> retrieve() async {
    final entry = await _storage.retrieveDeadLetter<dynamic>(sourceQueueName);
    if (entry == null) return null;
    return entry.withData(_payload.decode(entry.data));
  }

  /// Lists all dead letter entries
  Future<List<QueueEntry<T>>> list({int? limit, int? offset}) async {
    final entries = await _storage.listDeadLetters<dynamic>(
      sourceQueueName,
      limit: limit,
      offset: offset,
    );
    return [
      for (final entry in entries) entry.withData(_payload.decode(entry.data)),
    ];
  }

  /// Retries a dead letter entry by moving it back to the source queue
  Future<void> retry(String entryId) async {
    await _storage.retryDeadLetter(sourceQueueName, entryId);
  }

  /// Removes a dead letter entry permanently
  Future<void> remove(String entryId) async {
    await _storage.removeDeadLetter(sourceQueueName, entryId);
  }

  /// Purges all dead letter entries older than the specified duration
  Future<int> purgeOldEntries(Duration age) async {
    final cutoff = DateTime.now().subtract(age);
    return await _storage.purgeDeadLetters(sourceQueueName, cutoff);
  }

  /// Returns the number of dead letter entries
  Future<int> get length => _storage.countDeadLetters(sourceQueueName);
}
