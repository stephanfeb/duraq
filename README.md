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
    
    // Process items
    final email = await emailQueue.dequeue();
    if (email != null) {
      await processEmail(email);
    }
    
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
- **Priority Support**: Priority-based queue processing
- **TTL Support**: Automatic entry expiration
- **Scheduled Execution**: Delay processing until a specific time
- **Extensible**: Custom storage backend support

[View Full Features Documentation](features.md)

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
- Transaction support
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
- ACID compliant with automatic transactions
- Native indexing for better performance
- Type-safe queries
- Automatic schema migration
- Cross-platform support
- Real-time query capabilities
- Memory efficient with lazy loading
- Built-in compression
- **Shared Isar instance support** - allows multiple components to use the same database
- **External lifecycle management** - caller controls when to open/close the database

### Upcoming Storage Options
- File system storage
- Memory storage
- Custom storage implementations

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

// Nested transactions
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
await queue.processNext((data) async {
  try {
    await processItem(data);
  } catch (e) {
    // Failed attempts will be retried according to policy
    // After maxAttempts, item moves to dead letter queue
    rethrow;
  }
});
```

## Examples

### Transaction Support

DuraQ provides robust transaction support with ACID guarantees:

1. **Atomicity**: All operations in a transaction either succeed or fail together
2. **Consistency**: The database remains in a valid state before and after the transaction
3. **Isolation**: Concurrent transactions don't interfere with each other
4. **Durability**: Once committed, changes persist even after system failures

#### Transaction Methods

- `transaction<T>(Future<T> Function() operations)`: Executes operations in a transaction
- `beginTransaction()`: Starts a manual transaction
- `commitTransaction()`: Commits a manual transaction
- `rollbackTransaction()`: Rolls back a manual transaction

#### Features

- Automatic commit/rollback handling
- Nested transaction support using savepoints
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

// Process items with automatic retry
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

### Basic Queue Operations
```dart
// Create a queue
final queue = manager.queue<String>('notifications');

// Add items
await queue.enqueue('Notification 1');
await queue.enqueue('Notification 2');

// Process items
while (true) {
  final item = await queue.dequeue();
  if (item == null) break;
  
  await processNotification(item);
}
```

### Multiple Queue Types
```dart
// Email queue
final emailQueue = manager.queue<EmailMessage>('emails');
await emailQueue.enqueue(EmailMessage(...));

// Job queue
final jobQueue = manager.queue<BackgroundJob>('jobs');
await jobQueue.enqueue(BackgroundJob(...));
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
await queue.processNext((data) async {
  if (!await processItem(data)) {
    throw ProcessingError('Failed to process item');
  }
});
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
// Retry a specific entry
final deadLetter = await dlq.retrieve();
if (deadLetter != null) {
  // Move back to main queue for retry
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
- Entry retry capability
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
    // Retry temporary failures
    await dlq.retry(entry.id);
  } else if (entry.attempts < 5) {
    // Retry entries with few attempts
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
// Schedule an entry for future processing
final scheduledTime = DateTime.now().add(Duration(hours: 1));
final entry = QueueEntry<String>(
  id: 'scheduled-task-1',
  data: 'Process me later',
  createdAt: DateTime.now(),
  scheduledFor: scheduledTime,
);

await queue.enqueue(entry);

// The entry won't be retrieved until the scheduled time
final nextEntry = await queue.dequeue(); // Returns null if no entries are ready
```

#### Features

- Schedule entries for future processing
- Entries remain in queue but won't be retrieved before their scheduled time
- Combines with priority support (priority order applies once scheduled time is reached)
- Automatic handling of timezone and daylight saving changes
- Perfect for:
  - Delayed email notifications
  - Scheduled background jobs
  - Time-based workflow triggers
  - Deferred processing

#### Example Use Cases

1. **Delayed Notifications**
```dart
final reminderTime = DateTime.now().add(Duration(days: 1));
await notificationQueue.enqueue(QueueEntry(
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

await jobQueue.enqueue(QueueEntry(
  id: 'nightly-job-1',
  data: 'Run nightly maintenance',
  createdAt: DateTime.now(),
  scheduledFor: midnightTonight,
));
```

3. **Time-based Workflow**
```dart
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
    await workflowQueue.enqueue(step);
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

// Each entry will only be processed by one consumer
final entry1 = await consumer1.queue<String>('jobs').dequeue();
final entry2 = await consumer2.queue<String>('jobs').dequeue();

// Entries are automatically locked while being processed
// Other consumers won't receive the same entry until it's completed or failed
```

#### Features

- Entry-level locking for safe concurrent processing
- Automatic lock cleanup for expired locks
- Lock timeout support to prevent stuck entries
- Combines with other features:
  - Priority-based processing
  - Scheduled execution
  - Transaction support
  - Retry policies

#### Example Use Cases

1. **Multiple Workers**
```dart
void startWorker(String name, Storage storage) async {
  final queue = QueueManager(storage).queue<Job>('jobs');
  
  while (true) {
    final entry = await queue.dequeue();
    if (entry == null) {
      await Future.delayed(Duration(seconds: 1));
      continue;
    }
    
    try {
      await processJob(entry.data);
      await queue.markCompleted(entry.id);
    } catch (e) {
      await queue.markFailed(entry.id, error: e.toString());
    }
  }
}

// Start multiple workers
final storage = SQLiteStorage(dbPath: 'queue.db');
startWorker('worker1', storage);
startWorker('worker2', storage);
startWorker('worker3', storage);
```

2. **Distributed Processing**
```dart
// Workers can run on different machines
// SQLite with WAL mode supports concurrent access
final worker1 = SQLiteStorage(dbPath: '/shared/queue.db');
final worker2 = SQLiteStorage(dbPath: '/shared/queue.db');

// Each worker gets unique entries
final entry1 = await worker1.retrieve('jobs'); // Gets first available entry
final entry2 = await worker2.retrieve('jobs'); // Gets next available entry
```

3. **Safe Concurrent Updates**
```dart
final queue = QueueManager(storage).queue<Order>('orders');

// Multiple processors can safely update entries
await Future.wait([
  processOrders(queue, processor1),
  processOrders(queue, processor2),
  processOrders(queue, processor3),
]);

// Each entry is processed exactly once
async void processOrders(Queue<Order> queue, OrderProcessor processor) {
  while (true) {
    final entry = await queue.dequeue();
    if (entry == null) break;
    
    try {
      await processor.process(entry.data);
      await queue.markCompleted(entry.id);
    } catch (e) {
      await queue.markFailed(entry.id, error: e.toString());
    }
  }
}
```

#### Best Practices

1. **Lock Timeouts**
```dart
// Configure appropriate lock timeout
final storage = SQLiteStorage(
  dbPath: 'queue.db',
  lockDuration: Duration(minutes: 30), // Default is 5 minutes
);
```

2. **Error Handling**
```dart
try {
  final entry = await queue.dequeue();
  if (entry != null) {
    await processEntry(entry);
    await queue.markCompleted(entry.id);
  }
} catch (e) {
  // Entry lock is automatically released on failure
  await queue.markFailed(entry.id, error: e.toString());
}
```

3. **Health Monitoring**
```dart
// Periodically check for stuck entries
final stuckEntries = await storage.getEntriesByStatus(
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

// Get detailed health information
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

Contributions are welcome! Please read our contributing guidelines and submit pull requests to our repository.

## License

MIT

## See Also

- [Features Documentation](features.md)
- [API Documentation](https://pub.dev/documentation/duraq)
- [GitHub Repository](https://github.com/yourusername/duraq)
