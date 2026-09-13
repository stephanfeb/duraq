import 'codec.dart';
import 'queue.dart';
import 'storage/storage_interface.dart';

/// Manages multiple queues
class QueueManager {
  final StorageInterface storage;

  /// Cached queues, keyed by name *and* element type.
  ///
  /// Keying on the name alone meant the first caller's type won for the life of
  /// the process: asking for the same queue with a different type threw a cast
  /// error from inside the cache, and a queue first touched untyped could never
  /// be fetched typed. Two views of one queue are legitimate — an admin tool
  /// reading `dynamic` while a worker reads `Invoice` — so each gets its own
  /// instance over the same stored entries.
  final Map<(String, Type), Queue<dynamic>> _queues = {};

  QueueManager(this.storage);

  /// Gets or creates a queue with the given name.
  ///
  /// Asking twice for the same name and type returns the same instance, so a
  /// [codec] is only read the first time a name and type are asked for. Pass it
  /// on every call, or build the queue directly, rather than relying on which
  /// call happens to come first.
  Queue<T> queue<T>(String name, {QueueCodec<T>? codec}) =>
      _queues.putIfAbsent(
        (name, T),
        () => Queue<T>(name, storage, codec: codec),
      ) as Queue<T>;

  /// Lists all available queues
  Future<List<String>> listQueues() async {
    return await storage.listQueues();
  }

  /// Removes a queue and all its entries
  Future<void> removeQueue(String name) async {
    await storage.removeQueue(name);
    // Every typed view of the queue, not just the one that matches some
    // incidental type argument.
    _queues.removeWhere((key, _) => key.$1 == name);
  }
}
