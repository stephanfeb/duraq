import 'queue.dart';
import 'storage/storage_interface.dart';

/// Manages multiple queues
class QueueManager {
  final StorageInterface storage;
  final Map<String, Queue> _queues = {};

  QueueManager(this.storage);

  /// Gets or creates a queue with the given name
  Queue<T> queue<T>(String name) {
    return _queues.putIfAbsent(
      name,
      () => Queue<T>(name, storage),
    ) as Queue<T>;
  }

  /// Lists all available queues
  Future<List<String>> listQueues() async {
    return await storage.listQueues();
  }

  /// Removes a queue and all its entries
  Future<void> removeQueue(String name) async {
    await storage.removeQueue(name);
    _queues.remove(name); // Also remove from in-memory cache
  }
}
