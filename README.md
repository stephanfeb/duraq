# DuraQ

A robust, durable queuing system implemented in Dart, providing persistent queue management with multiple storage backend support.

## Overview

DuraQ is designed to provide a reliable queuing system with:
- Type-safe queue operations
- Persistent storage options
- Multiple queue support
- Entry tracking and monitoring
- Extensible storage backends

## Quick Start

1. Add to your `pubspec.yaml`:
```yaml
dependencies:
  duraq: ^0.0.1
```

2. Create a queue manager with SQLite storage:
```dart
import 'package:duraq/duraq.dart';
import 'package:path/path.dart' as path;

void main() async {
  // Initialize storage
  final dbPath = path.join(Directory.current.path, 'queue.db');
  final storage = SQLiteStorage(dbPath: dbPath);

  // Create queue manager
  final manager = QueueManager(storage);

  // Get a typed queue
  final emailQueue = manager.queue<String>('emails');

  try {
    // Enqueue items
    await emailQueue.enqueue('Welcome email to user@example.com');

    // Process items. processNext keeps the entry until the work returns, so
    // a crash mid-send redelivers it rather than losing it.
    await emailQueue.processNext(processEmail);

    // Check queue status
    final remaining = await emailQueue.length;
    print('Remaining emails: $remaining');
  } finally {
    // Clean up resources
    storage.dispose();
  }
}
```

## Features

- **Type-safe Queues**: Generic support for any data type
- **Multiple Queues**: Manage different queue types in one manager
- **Persistent Storage**: Built-in SQLite support with ACID compliance
- **Entry Tracking**: Monitor attempts, creation time, and status
- **Transaction Support**: Atomic operations with nested transaction support
- **Retry Policies**: Configurable retry strategies with exponential backoff
- **Priority Support**: Priority-based queue processing (lower value = higher priority)
- **TTL Support**: Automatic entry expiration
- **Scheduled Execution**: Delay processing until a specific time
- **Dead Letter Queue**: Automatic handling of permanently failed entries
- **Health Checks**: Monitor storage, metrics, and queue health
- **Concurrent Processing**: Entry-level locking for safe multi-consumer access
- **Crash Recovery**: Entries claimed by a consumer that dies are handed back to
  the queue once their lease expires
- **Retention**: One maintenance call reclaims, expires, and prunes finished
  entries so the database does not grow forever
- **Extensible**: Custom storage backend support via `StorageInterface`

## Storage Backends

### SQLite Storage (Built-in)
```dart
final storage = SQLiteStorage(dbPath: 'path/to/queue.db');
```

Features:
- Persistent across restarts
- ACID compliant
- Automatic schema management
- FIFO guarantee
- Data integrity
- Transaction support with savepoints
- Priority-based retrieval
- TTL support

### Isar Storage
```dart
// Initialize Isar with required schemas
await Isar.initializeIsarCore(download: true);
final isar = await Isar.open([
  ...IsarStorage.requiredSchemas,
  // Add your other schemas here if needed
], directory: 'path/to/db');

// Create storage with external Isar instance
final storage = IsarStorage(isar);

// Use the storage
final manager = QueueManager(storage);

// Clean up (caller manages Isar lifecycle)
await storage.dispose(); // Releases locks but doesn't close Isar
await isar.close(); // Caller closes Isar
```

Features:
- High-performance NoSQL database
- Persistent across restarts
- Native indexing for better performance
- Type-safe queries
- Cross-platform support
- Memory efficient with lazy loading
- **Shared Isar instance support** - allows multiple components to use the same database
- **External lifecycle management** - caller controls when to open/close the database

> **Transactions**: `transaction()` runs its body in a single Isar write
> transaction, so operations inside it commit together or not at all. The manual
> `beginTransaction`/`commitTransaction`/`rollbackTransaction` calls throw
> `UnsupportedError` on this backend: an Isar write transaction takes its work as
> a callback and cannot be opened in one call and closed in another.

> **Upgrading an existing Isar database**: versions before 1.0.2 could store more
> than one row for the same entry, which let the same job be processed twice.
> Run the one-off cleanup once after upgrading:
>
> ```dart
> final removed = await storage.removeDuplicateEntries();
> ```
>
> New stores cannot create duplicates. The schema also changed to add the indexes
> the queries need and drop the ones nothing used; existing databases migrate
> when they are opened.

### Upcoming Storage Options
- File system storage
- Custom storage implementations via `StorageInterface`

## Best Practices

1. **Resource Management**
```dart
final storage = SQLiteStorage(dbPath: 'queue.db');
try {
  // Use storage
} finally {
  storage.dispose(); // Always dispose
}
```

2. **Type Safety**
```dart
// Prefer specific types
final emailQueue = manager.queue<EmailMessage>('emails');
final jobQueue = manager.queue<BackgroundJob>('jobs');
```

3. **Error Handling**
```dart
try {
  await queue.enqueue(item);
} catch (e) {
  // Handle storage errors
}
```

4. **Transaction Usage**
```dart
// Simple transaction
await storage.transaction(() async {
  await queue.enqueue(item1);
  await queue.enqueue(item2);
  return null;
}); // Automatically commits or rolls back

// Nested transactions (SQLite uses savepoints)
await storage.transaction(() async {
  await queue.enqueue(item1);

  await storage.transaction(() async {
    await queue.enqueue(item2);
    return null;
  }); // Inner transaction

  return null;
}); // Outer transaction

// Manual transaction control
await storage.beginTransaction();
try {
  await queue.enqueue(item1);
  await queue.enqueue(item2);
  await storage.commitTransaction();
} catch (e) {
  await storage.rollbackTransaction();
  rethrow;
}
```

5. **Retry Policies**
```dart
// Create a queue with exponential backoff retry
final queue = Queue<String>(
  'my-queue',
  storage,
  retryPolicy: ExponentialBackoff(
    baseDelay: Duration(milliseconds: 100),
    maxDelay: Duration(seconds: 30),
    maxAttempts: 5,
  ),
);

// Process items with automatic retry
try {
  await queue.processNext((data) async {
    await processItem(data);
    // If this throws, the entry is retried according to policy
    // After maxAttempts, the entry moves to the dead letter queue
  });
} catch (e) {
  print('Processing failed: $e');
}
```

## Examples

### Basic Queue Operations
```dart
// Create a queue
final queue = manager.queue<String>('notifications');

// Add items
await queue.enqueue('Notification 1');
await queue.enqueue('Notification 2');

// dequeue() returns the raw data (T?), not a QueueEntry, and removes the entry
// as it hands it over. If this loop dies partway, the item it was holding is
// gone with it.
while (true) {
  final item = await queue.dequeue();
  if (item == null) break;

  await processNotification(item);
}

// processNext() keeps the entry until the callback returns, retries it under
// the queue's retry policy if the callback throws, and gives it to another
// consumer if this one dies. Prefer it for work that must not be lost.
while (await queue.processNext(processNotification)) {}
```

### Delivery Guarantees

| | `dequeue()` | `processNext()` |
| --- | --- | --- |
| Delivery | At most once | At least once |
| Entry is removed | As it is handed to you | After the callback returns |
| Callback throws | Not applicable | Retried, then dead-lettered |
| Consumer dies mid-work | Item is lost | Entry is reclaimed and redelivered |

Pick `dequeue()` when losing an item is cheaper than doing it twice, and
`processNext()` when it is not.

### Multiple Queue Types
```dart
// Email queue
final emailQueue = manager.queue<EmailMessage>('emails');
await emailQueue.enqueue(EmailMessage(...));

// Job queue
final jobQueue = manager.queue<BackgroundJob>('jobs');
await jobQueue.enqueue(BackgroundJob(...));
```

The same queue can be read through more than one element type. A worker reads
its own payload type while an admin tool reads `dynamic` over the same entries:

```dart
final typed = manager.queue<EmailMessage>('emails');
final raw = manager.queue<dynamic>('emails');   // same entries, no type argument
```

### Payload Types and Codecs

Payloads are stored as JSON. Without a codec a queue can hold only what
`jsonEncode` accepts — numbers, strings, booleans, null, and lists and maps of
those — regardless of what its type argument says. A domain object that does not
define `toJson()` throws `PayloadCodecException` at enqueue, naming the type and
what to do about it.

Give the queue a codec and the restriction lifts:

```dart
final invoices = Queue<Invoice>(
  'invoices',
  storage,
  codec: QueueCodec.from(
    encode: (invoice) => invoice.toJson(),
    decode: (stored) => Invoice.fromJson(stored! as Map<String, dynamic>),
  ),
);

await invoices.enqueue(Invoice(customer: 'acme', cents: 1999));
final invoice = await invoices.dequeue();   // an Invoice, not a Map
```

`decode` receives exactly what `jsonDecode` produced, so maps arrive as
`Map<String, dynamic>` and every number as `int` or `double` whatever went in.
Both directions must be pure: an entry can be decoded in a later run of the
program, long after it was written.

Pass the same codec to a `DeadLetterQueue` reading the same entries:

```dart
final dead = DeadLetterQueue<Invoice>('invoices', storage, codec: invoiceCodec);
```

A queue read through the wrong element type also reports
`PayloadCodecException`, naming the queue and both types, rather than failing as
a cast error deep in the storage.

### Transaction Support

DuraQ provides robust transaction support (ACID guarantees with SQLite):

1. **Atomicity**: All operations in a transaction either succeed or fail together
2. **Consistency**: The database remains in a valid state before and after the transaction
3. **Isolation**: Concurrent calls to `transaction()` run one at a time, so they cannot
   commit or roll back each other's work
4. **Durability**: Once committed, changes persist even after system failures

> **Manual transactions are single-caller.** `beginTransaction()` takes exclusive
> access to the storage and holds it until `commitTransaction()` or
> `rollbackTransaction()` closes it, so it must always be closed. While one is
> open, other operations on that storage instance join it rather than queueing,
> which means the manual API gives no isolation between concurrent callers.
> Prefer `transaction()`, which closes itself even when the body throws.

#### Transaction Methods

- `transaction<T>(Future<T> Function() operations)`: Executes operations in a transaction
- `beginTransaction()`: Starts a manual transaction
- `commitTransaction()`: Commits a manual transaction
- `rollbackTransaction()`: Rolls back a manual transaction

#### Features

- Automatic commit/rollback handling
- Nested transaction support using savepoints (SQLite)
- Manual transaction control when needed
- Error handling with automatic rollback

#### Example Use Cases

1. **Atomic Multi-Queue Operations**
```dart
await storage.transaction(() async {
  await emailQueue.enqueue(welcomeEmail);
  await notificationQueue.enqueue(welcomeNotification);
  await analyticsQueue.enqueue(userSignupEvent);
  return null;
});
```

2. **Batch Processing with Rollback**
```dart
await storage.transaction(() async {
  for (final job in jobs) {
    if (!isValid(job)) {
      throw ValidationError(); // Rolls back all enqueued jobs
    }
    await jobQueue.enqueue(job);
  }
  return null;
});
```

3. **Complex Queue Operations**
```dart
await storage.transaction(() async {
  // Process high-priority queue
  final highPriorityItem = await highPriorityQueue.dequeue();
  if (highPriorityItem != null) {
    await processQueue.enqueue(highPriorityItem);
  }

  // Process normal queue
  final normalItem = await normalQueue.dequeue();
  if (normalItem != null) {
    await processQueue.enqueue(normalItem);
  }

  return null;
});
```

### Crash Recovery

Retrieving an entry claims it for `leaseDuration` (five minutes by default). If
the consumer completes or fails the entry, the claim is released immediately. If
the consumer dies without doing either, the claim expires and the entry is
handed back to the queue on the next retrieval, with its attempt count
incremented.

```dart
final storage = SQLiteStorage(
  dbPath: 'queue.db',
  leaseDuration: Duration(minutes: 2),  // how long a consumer may hold an entry
  maxDeliveryAttempts: 5,               // deliveries before the entry is parked
);

// At startup, take back anything the previous run left claimed.
final recovered = await storage.reclaimStaleEntries();
print('recovered $recovered entries from the last run');
```

Set `leaseDuration` longer than your slowest job. A consumer that runs past its
lease loses the entry: whatever it reports when it finishes is discarded, because
the entry now belongs to whoever picked it up next, and the job runs again. That
is the at-least-once behaviour a visibility timeout gives you, but it is worth
sizing the lease so it stays rare. An entry whose lease expires
`maxDeliveryAttempts` times is moved to the dead letter queue instead of being
delivered again, so a job that crashes its consumer cannot cycle forever.

### Multiple Processes

One SQLite file can be used by several processes or isolates at once. Each one
opens its own `SQLiteStorage`; a `Database` handle cannot be shared across
isolates. Entry leases do the rest: a claimed entry is not offered to anyone
else until its lease expires, whichever process is holding it.

```dart
final storage = SQLiteStorage(
  dbPath: 'queue.db',
  busyTimeout: Duration(seconds: 5),  // how long to wait for the write lock
);
```

Only one process can write at a time. When another one is mid-write, a write
waits and retries until `busyTimeout` runs out, then throws
`StorageBusyException`. Nothing was written when that happens, so retrying the
call is safe. The waiting is done in short slices, so timers and other work in
your isolate keep running while a write waits its turn.

For Isar, pass the same `Isar` instance to each component in the process; Isar
handles access from several isolates itself.

### Maintenance and Retention

Nothing is deleted on its own. A queue that runs for months otherwise keeps every
job it has ever processed, so run one maintenance pass on a schedule that suits
your volume, or at startup:

```dart
final report = await storage.runMaintenance();
print('reclaimed ${report.reclaimed}, expired ${report.expired}, '
      'removed ${report.removed}');
```

A pass does three things: it returns entries whose consumer died to the queue, it
marks entries that outlived their deadline as expired, and it deletes finished
entries older than the retention policy allows. Unfinished work is never deleted.

```dart
await storage.runMaintenance(
  policy: RetentionPolicy(
    completed: Duration(days: 7),
    failed: Duration(days: 7),
    deadLetter: Duration(days: 30),  // these still need a person to look at
    expired: Duration(days: 1),
  ),
  queueName: 'emails',  // optional, defaults to every queue
);
```

Pass `RetentionPolicy.keepEverything()` to reclaim and expire without deleting
anything.

### Storing an Entry Twice

Entry ids are unique across the storage, not per queue. `enqueue` generates one,
so it cannot collide; `enqueueEntry` takes an entry you built yourself, which
can. By default a collision throws `DuplicateEntryException`:

```dart
try {
  await queue.enqueueEntry(entry);
} on DuplicateEntryException catch (e) {
  print('${e.entryId} is already queued');
}

// A producer retrying a call it got no answer for wants the enqueue to be
// idempotent instead:
await queue.enqueueEntry(entry, onConflict: StoreConflict.ignore);

// Restating an entry the caller owns:
await queue.enqueueEntry(entry, onConflict: StoreConflict.replace);
```

### Retry Policies

DuraQ includes built-in retry support with configurable policies:

1. **Exponential Backoff**
```dart
// Configure retry policy
final retryPolicy = ExponentialBackoff(
  baseDelay: Duration(milliseconds: 100), // Initial delay
  maxDelay: Duration(seconds: 30),        // Maximum delay
  maxAttempts: 5,                         // Maximum retry attempts
);

// Create queue with retry policy
final queue = Queue<String>('retry-queue', storage, retryPolicy: retryPolicy);

// processNext handles retry logic automatically
await queue.processNext((data) async {
  await processWithRetry(data);
});
```

2. **Custom Retry Policies**
```dart
class CustomRetryPolicy implements RetryPolicy {
  @override
  int get maxAttempts => 3;

  @override
  bool shouldRetry(int attempts, [Object? error]) {
    // Custom retry logic
    return attempts < maxAttempts && error is RetryableError;
  }

  @override
  Duration getRetryDelay(int attempts) {
    // Custom delay calculation
    return Duration(seconds: attempts * 5);
  }

  @override
  bool shouldMoveToDeadLetter(int attempts, [Object? error]) {
    // Custom dead letter queue logic
    return attempts >= maxAttempts || error is NonRetryableError;
  }
}
```

3. **Error Handling with Retries**
```dart
try {
  await queue.processNext((data) async {
    if (!await processItem(data)) {
      throw RetryableError('Processing failed, will retry');
    }
  });
} catch (e) {
  // Failed attempts are automatically retried
  // After maxAttempts, moves to dead letter queue
  print('Processing failed: $e');
}
```

### Dead Letter Queue

DuraQ provides built-in dead letter queue support for handling failed entries:

1. **Automatic Failed Entry Movement**
```dart
// Create a queue with retry policy
final queue = Queue<String>(
  'my-queue',
  storage,
  retryPolicy: ExponentialBackoff(maxAttempts: 3),
);

// Failed entries move to dead letter queue after max attempts
try {
  await queue.processNext((data) async {
    if (!await processItem(data)) {
      throw ProcessingError('Failed to process item');
    }
  });
} catch (e) {
  // Entry has been moved to dead letter or scheduled for retry
}
```

2. **Dead Letter Queue Management**
```dart
// Create a dead letter queue for a specific queue
final dlq = DeadLetterQueue<String>('my-queue', storage);

// List dead letter entries with pagination
final entries = await dlq.list(limit: 10, offset: 0);
for (final entry in entries) {
  print('Failed entry: ${entry.data}');
  print('Error: ${entry.errorMessage}');
  print('Attempts: ${entry.attempts}');
}

// Get dead letter queue length
final count = await dlq.length;
print('Dead letter entries: $count');
```

3. **Entry Recovery**
```dart
// Retry a specific entry (resets attempts to 0, moves back to pending)
final deadLetter = await dlq.retrieve();
if (deadLetter != null) {
  await dlq.retry(deadLetter.id);
}

// Remove an entry permanently
await dlq.remove(deadLetter.id);
```

4. **Cleanup and Maintenance**
```dart
// Purge old entries
final purged = await dlq.purgeOldEntries(Duration(days: 7));
print('Purged $purged old entries');
```

#### Features

- Automatic movement of failed entries after retry exhaustion
- Pagination support for listing entries
- Entry retry capability (resets attempt counter)
- Permanent entry removal
- Automatic cleanup of old entries
- Error message preservation
- Attempt count tracking

#### Best Practices

1. **Regular Monitoring**
```dart
// Check dead letter queue periodically
final dlq = DeadLetterQueue<String>('my-queue', storage);
final count = await dlq.length;
if (count > 0) {
  // Alert operations team
  notifyOps('Dead letter queue has $count entries');
}
```

2. **Cleanup Strategy**
```dart
// Implement regular cleanup
final cleanupJob = Timer.periodic(Duration(days: 1), (_) async {
  final dlq = DeadLetterQueue<String>('my-queue', storage);

  // Keep entries for 30 days
  final purged = await dlq.purgeOldEntries(Duration(days: 30));

  // Log cleanup results
  logger.info('Purged $purged old dead letter entries');
});
```

3. **Error Analysis**
```dart
// Analyze failed entries
final entries = await dlq.list();
final errorCounts = <String, int>{};

for (final entry in entries) {
  errorCounts[entry.errorMessage ?? 'Unknown'] =
    (errorCounts[entry.errorMessage] ?? 0) + 1;
}

// Report error distribution
for (final error in errorCounts.entries) {
  print('${error.key}: ${error.value} occurrences');
}
```

4. **Retry Strategy**
```dart
// Implement selective retry
final entries = await dlq.list();
for (final entry in entries) {
  if (entry.errorMessage?.contains('Temporary failure') ?? false) {
    // Retry temporary failures (resets attempts to 0)
    await dlq.retry(entry.id);
  } else {
    // Remove permanently failed entries
    await dlq.remove(entry.id);
  }
}
```

### Scheduled Execution

DuraQ supports scheduling entries for future processing:

```dart
// Schedule an entry for future processing using enqueueEntry
final scheduledTime = DateTime.now().add(Duration(hours: 1));
final entry = QueueEntry<String>(
  id: 'scheduled-task-1',
  data: 'Process me later',
  createdAt: DateTime.now(),
  scheduledFor: scheduledTime,
);

await queue.enqueueEntry(entry);

// The entry won't be retrieved until the scheduled time
final nextItem = await queue.dequeue(); // Returns null if no entries are ready
```

#### Features

- Schedule entries for future processing
- Entries remain in queue but won't be retrieved before their scheduled time
- Combines with priority support (priority order applies once scheduled time is reached)
- Perfect for:
  - Delayed email notifications
  - Scheduled background jobs
  - Time-based workflow triggers
  - Deferred processing

#### Example Use Cases

1. **Delayed Notifications**
```dart
final reminderTime = DateTime.now().add(Duration(days: 1));
await notificationQueue.enqueueEntry(QueueEntry(
  id: 'reminder-1',
  data: 'Follow-up reminder email',
  createdAt: DateTime.now(),
  scheduledFor: reminderTime,
));
```

2. **Scheduled Tasks**
```dart
final midnightTonight = DateTime.now().copyWith(
  hour: 0,
  minute: 0,
  second: 0,
  millisecond: 0,
).add(Duration(days: 1));

await jobQueue.enqueueEntry(QueueEntry(
  id: 'nightly-job-1',
  data: 'Run nightly maintenance',
  createdAt: DateTime.now(),
  scheduledFor: midnightTonight,
));
```

3. **Time-based Workflow**
```dart
final now = DateTime.now();
final workflow = [
  QueueEntry(
    id: 'step1',
    data: 'Send welcome email',
    createdAt: now,
    scheduledFor: now,
  ),
  QueueEntry(
    id: 'step2',
    data: 'Send follow-up survey',
    createdAt: now,
    scheduledFor: now.add(Duration(days: 7)),
  ),
  QueueEntry(
    id: 'step3',
    data: 'Send engagement reminder',
    createdAt: now,
    scheduledFor: now.add(Duration(days: 14)),
  ),
];

await storage.transaction(() async {
  for (final step in workflow) {
    await workflowQueue.enqueueEntry(step);
  }
  return null;
});
```

### Concurrent Processing

DuraQ provides built-in support for concurrent processing with entry-level locking:

```dart
// Multiple consumers can safely process queue entries
final consumer1 = QueueManager(storage);
final consumer2 = QueueManager(storage);

// Each consumer gets a different entry - entries are locked while claimed
await consumer1.queue<String>('jobs').processNext(handleJob);
await consumer2.queue<String>('jobs').processNext(handleJob);
```

#### Features

- Entry-level locking for safe concurrent processing
- Automatic lock cleanup for expired locks (default: 5 minute timeout)
- Combines with other features:
  - Priority-based processing
  - Scheduled execution
  - Transaction support
  - Retry policies

#### Example Use Cases

1. **Multiple Workers**
```dart
void startWorker(String name, SQLiteStorage storage) async {
  final queue = Queue<String>('jobs', storage);

  while (true) {
    try {
      final processed = await queue.processNext((data) async {
        await processJob(data);
      });
      if (!processed) {
        await Future.delayed(Duration(seconds: 1));
      }
    } catch (e) {
      // processNext handles retry/dead-letter automatically
      print('$name: Processing failed: $e');
    }
  }
}

// Start multiple workers sharing the same storage
final storage = SQLiteStorage(dbPath: 'queue.db');
startWorker('worker1', storage);
startWorker('worker2', storage);
startWorker('worker3', storage);
```

2. **Safe Concurrent Processing**
```dart
final queue = Queue<String>('orders', storage);

// Multiple processors can safely run in parallel
await Future.wait([
  processOrders(queue),
  processOrders(queue),
  processOrders(queue),
]);

Future<void> processOrders(Queue<String> queue) async {
  while (true) {
    final processed = await queue.processNext((data) async {
      await fulfillOrder(data);
    });
    if (!processed) break; // No more items
  }
}
```

3. **Health Monitoring**
```dart
// Periodically check for stuck entries using SQLiteStorage directly
final sqliteStorage = storage as SQLiteStorage;
final stuckEntries = await sqliteStorage.getEntriesByStatus(
  'jobs',
  EntryStatus.processing,
);

for (final entry in stuckEntries) {
  final processingTime = DateTime.now().difference(entry.lastUpdatedAt);
  if (processingTime > Duration(hours: 1)) {
    // Alert operations about stuck entry
    notifyOps('Entry ${entry.id} stuck in processing');
  }
}
```

> **Note**: `getEntriesByStatus()` is available on `SQLiteStorage` and `IsarStorage` directly, but is not part of the `StorageInterface` contract.

## Health Checks

DuraQ provides comprehensive health monitoring capabilities to ensure your queue system is operating correctly. The health check system monitors three main components:

1. **Storage Health**: Verifies that the storage backend is responsive and functioning properly.
2. **Metrics Health**: Ensures the metrics collection system is operational.
3. **Queue Health**: Monitors queue performance metrics like error rates and processing times.

### Usage

```dart
// Create health checks
final healthChecks = HealthCheckAggregator([
  StorageHealthCheck(storage),
  MetricsHealthCheck(metrics),
  QueueHealthCheck(
    storage,
    metrics,
    errorRateWindow: Duration(minutes: 5),
    maxErrorRate: 0.1, // 10% threshold
  ),
]);

// Check overall health
final status = await healthChecks.getOverallStatus();
if (status == HealthStatus.healthy) {
  print('All systems operational');
}

// Get detailed health information (checks run in parallel)
final results = await healthChecks.checkAll();
for (final result in results.values) {
  print('${result.component}: ${result.status}');
  print('Message: ${result.message}');
  print('Details: ${result.details}');
}
```

### Health Status Levels

- **Healthy**: All components are functioning normally
- **Degraded**: System is operational but showing signs of stress (e.g., high error rate)
- **Unhealthy**: One or more components have failed

### Monitored Metrics

- Error rates
- Queue size
- Average processing time
- Storage responsiveness
- Metrics system status

## Contributing

Contributions are welcome. One command checks everything that has to hold:

```bash
tool/verify.sh
```

It runs `dart analyze --fatal-infos --fatal-warnings` and the test suite, and
takes a few seconds. The GitHub workflow runs the same script, so a green run
locally and a green run on CI mean the same thing.

Install the pre-push hook once and it runs for you before every push:

```bash
tool/install-hooks.sh
```

The hook lives in `.githooks/` and is version controlled rather than copied into
`.git/hooks`. Skip it for a single push with `git push --no-verify`.

The suite uses real databases and real elapsed time, so a single green run is
weaker evidence than it looks. To hunt timing flakes, run it repeatedly:

```bash
tool/verify.sh --flake 5
```

Lint configuration lives in `analysis_options.yaml`, with two rules relaxed for
the test tree in `test/analysis_options.yaml`. Generated Isar code is excluded
from analysis; it is not ours to fix.

## License

MIT

## See Also

- [Priority Queues](docs/features/priority_queues.md)
- [Status Tracking](docs/features/status_tracking.md)
- [TTL Support](docs/features/ttl_support.md)
- [API Documentation](https://pub.dev/documentation/duraq)
- [GitHub Repository](https://github.com/stephanfeb/duraq)
