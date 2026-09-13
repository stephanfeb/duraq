import 'package:duraq/duraq.dart';
import 'package:test/test.dart';

/// Helpers shared by the retry and reclaim suites in both packages.
///
/// They live here rather than inside one test's `main()` so that `duraq_isar`
/// can hold its backend to the same behaviour without a second copy that drifts.
QueueEntry<String> entry(
  String id, {
  DateTime? nextRetryAt,
  int priority = 0,
}) =>
    QueueEntry<String>(
      id: id,
      data: 'payload-$id',
      createdAt: DateTime.now(),
      nextRetryAt: nextRetryAt,
      priority: priority,
    );

/// Retrieves as soon as an entry becomes available, giving up after [limit].
///
/// Polling rather than sleeping for a fixed margin keeps the test honest
/// about what it is asserting and stops it failing on a loaded machine.
Future<QueueEntry<dynamic>?> retrieveWithin(
  StorageInterface storage,
  String queueName,
  Duration limit,
) async {
  final deadline = DateTime.now().add(limit);
  while (DateTime.now().isBefore(deadline)) {
    final entry = await storage.retrieve(queueName);
    if (entry != null) return entry;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return null;
}

/// Drives one failing attempt through the queue and returns the delay the
/// policy actually chose, so timing assertions do not depend on jitter.
Future<Duration> failOnceAndReadDelay(
  StorageInterface storage,
  Queue<String> queue,
  String queueName,
) async {
  try {
    await queue.processNext((_) => throw StateError('simulated failure'));
    fail('the processor should have thrown');
  } on StateError {
    // expected
  }

  final stored = (await storage.retrieveAll(queueName)).single;
  expect(stored.status, equals(EntryStatus.pending));
  expect(stored.attempts, equals(1));
  expect(stored.nextRetryAt, isNotNull);
  return stored.nextRetryAt!.difference(DateTime.now());
}
