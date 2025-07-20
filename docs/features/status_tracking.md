# Status Tracking

DuraQ provides comprehensive status tracking for queue entries, allowing you to monitor the lifecycle of each entry from creation to completion.

## Status Types

Each queue entry can be in one of the following states:

```dart
enum EntryStatus {
  /// Entry is waiting to be processed
  pending,
  
  /// Entry is currently being processed
  processing,
  
  /// Entry has been processed successfully
  completed,
  
  /// Entry processing failed and may be retried
  failed,
  
  /// Entry has failed too many times and won't be retried
  dead,
  
  /// Entry has been cancelled
  cancelled,
  
  /// Entry has expired due to TTL
  expired,
}
```

## Usage

### Basic Status Tracking

```dart
final queue = manager.queue<String>('jobs');

// Create an entry (automatically gets pending status)
await queue.enqueue('Process user data');

// Retrieve and process (automatically sets to processing)
final entry = await queue.dequeue();

try {
  await processJob(entry.data);
  await queue.markCompleted(entry.id);
} catch (e) {
  await queue.markFailed(entry.id, error: e.toString());
}
```

### Status Transitions

1. **Normal Flow**:
   ```
   pending -> processing -> completed
   ```

2. **Error Flow**:
   ```
   pending -> processing -> failed -> pending (retry)
   pending -> processing -> failed -> dead (too many retries)
   ```

3. **Cancellation Flow**:
   ```
   pending -> cancelled
   processing -> cancelled
   ```

4. **Expiration Flow**:
   ```
   pending -> expired
   ```

## Implementation Details

### Status Tracking Fields

Each queue entry includes:
```dart
class QueueEntry<T> {
  // Current status
  EntryStatus status;
  
  // When the entry was last updated
  DateTime lastUpdatedAt;
  
  // Error information if failed
  String? errorMessage;
  
  // Number of processing attempts
  int attempts;
}
```

### Storage

The SQLite implementation:
- Maintains status in a dedicated column
- Tracks status change timestamps
- Preserves error messages
- Supports status-based queries

## Best Practices

1. **Error Handling**
   ```dart
   try {
     final entry = await queue.dequeue();
     if (entry != null) {
       try {
         await processEntry(entry);
         await queue.markCompleted(entry.id);
       } catch (e) {
         await queue.markFailed(entry.id, error: e.toString());
       }
     }
   } catch (e) {
     // Handle queue operation errors
   }
   ```

2. **Status Monitoring**
   ```dart
   // Get counts by status
   final pending = await queue.countByStatus(EntryStatus.pending);
   final failed = await queue.countByStatus(EntryStatus.failed);
   
   // Monitor failed entries
   final failedEntries = await queue.getEntriesByStatus(EntryStatus.failed);
   for (final entry in failedEntries) {
     log('Failed entry ${entry.id}: ${entry.errorMessage}');
   }
   ```

3. **Retry Management**
   ```dart
   Future<void> processWithRetry(QueueEntry entry, {int maxAttempts = 3}) async {
     if (entry.attempts >= maxAttempts) {
       await queue.markDead(entry.id);
       return;
     }
     
     try {
       await processEntry(entry);
       await queue.markCompleted(entry.id);
     } catch (e) {
       await queue.markFailed(entry.id, error: e.toString());
     }
   }
   ```

## Examples

### Status-based Processing

```dart
class JobProcessor {
  final Queue<Job> queue;
  
  Future<void> processJobs() async {
    while (true) {
      final entry = await queue.dequeue();
      if (entry == null) break;
      
      try {
        await processJob(entry.data);
        await queue.markCompleted(entry.id);
      } catch (e) {
        if (entry.attempts < 3) {
          await queue.markFailed(entry.id, error: e.toString());
        } else {
          await queue.markDead(entry.id);
          await notifyJobDead(entry);
        }
      }
    }
  }
}
```

### Status Monitoring

```dart
class QueueMonitor {
  final Queue<Job> queue;
  
  Future<QueueStats> getStats() async {
    return QueueStats(
      pending: await queue.countByStatus(EntryStatus.pending),
      processing: await queue.countByStatus(EntryStatus.processing),
      completed: await queue.countByStatus(EntryStatus.completed),
      failed: await queue.countByStatus(EntryStatus.failed),
      dead: await queue.countByStatus(EntryStatus.dead),
    );
  }
  
  Future<void> handleFailedJobs() async {
    final failed = await queue.getEntriesByStatus(EntryStatus.failed);
    for (final entry in failed) {
      if (entry.attempts < 3) {
        await queue.retry(entry.id);
      } else {
        await queue.markDead(entry.id);
      }
    }
  }
}
```

## Limitations

1. No automatic status transitions (except for expiration)
2. No built-in retry mechanism
3. No status change notifications/webhooks
4. Status history not maintained 