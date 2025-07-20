# TTL Support

DuraQ provides Time To Live (TTL) support for queue entries, allowing entries to automatically expire after a specified duration.

## Overview

TTL support enables:
- Automatic entry expiration
- Cleanup of expired entries
- TTL-based queue management
- Temporary entry storage

## Usage

### Basic TTL

```dart
final queue = manager.queue<String>('cache');

// Entry expires in 1 hour
await queue.enqueue(
  'Temporary data',
  ttl: Duration(hours: 1),
);

// Entry expires at specific time
await queue.enqueue(
  'Time-sensitive data',
  expiresAt: DateTime.now().add(Duration(minutes: 30)),
);
```

### TTL Patterns

1. **Cache-like Storage**
   ```dart
   final cacheQueue = manager.queue<CacheEntry>('cache');
   
   await cacheQueue.enqueue(
     CacheEntry(key: 'user-123', data: userData),
     ttl: Duration(minutes: 30),
   );
   ```

2. **Time-sensitive Messages**
   ```dart
   final notificationQueue = manager.queue<Notification>('notifications');
   
   await notificationQueue.enqueue(
     Notification(
       type: 'promotion',
       message: 'Flash sale ending soon!',
     ),
     ttl: Duration(hours: 2), // Promotion duration
   );
   ```

3. **Scheduled Cleanup**
   ```dart
   final tempQueue = manager.queue<TempData>('temp');
   
   // Data only valid for current day
   await tempQueue.enqueue(
     TempData(content: 'Daily report'),
     expiresAt: DateTime.now().add(Duration(days: 1)),
   );
   ```

## Implementation Details

### Entry Configuration

```dart
class QueueEntry<T> {
  /// When this entry expires (null means never)
  final DateTime? expiresAt;

  /// Whether this entry has expired
  bool get isExpired => 
    expiresAt != null && DateTime.now().isAfter(expiresAt!);

  // Constructor with TTL
  QueueEntry({
    required this.id,
    required this.data,
    Duration? ttl,  // TTL duration
  }) : expiresAt = ttl != null ? 
         DateTime.now().add(ttl) : null;

  // Constructor with specific expiration
  QueueEntry.withExpiration({
    required this.id,
    required this.data,
    required this.expiresAt,
  });
}
```

### Storage Implementation

The SQLite storage:
- Stores expiration timestamps
- Automatically marks expired entries
- Provides cleanup mechanisms
- Excludes expired entries from retrieval

## Features

### Automatic Expiration

Entries are automatically marked as expired when:
- Their TTL has elapsed
- They are retrieved after expiration
- During cleanup operations

### Cleanup Process

```dart
// Manual cleanup
final removed = await storage.cleanupExpiredEntries();
print('Removed $removed expired entries');

// Automatic cleanup (recommended setup)
Timer.periodic(Duration(hours: 1), (_) {
  storage.cleanupExpiredEntries();
});
```

### Expiration Policies

1. **Soft Expiration**
   - Entry marked as expired
   - Remains in storage
   - Available for inspection

2. **Hard Expiration**
   - Entry physically removed
   - Occurs 24 hours after expiration
   - Not recoverable

## Best Practices

1. **TTL Selection**
   ```dart
   // Define common TTLs
   abstract class QueueTTL {
     static const short = Duration(minutes: 30);
     static const medium = Duration(hours: 4);
     static const long = Duration(days: 1);
   }
   
   // Use in code
   await queue.enqueue(data, ttl: QueueTTL.medium);
   ```

2. **Cleanup Management**
   ```dart
   class QueueManager {
     final SQLiteStorage storage;
     Timer? _cleanupTimer;
     
     void startCleanup({
       Duration interval = const Duration(hours: 1),
     }) {
       _cleanupTimer?.cancel();
       _cleanupTimer = Timer.periodic(interval, (_) {
         storage.cleanupExpiredEntries();
       });
     }
     
     void dispose() {
       _cleanupTimer?.cancel();
       storage.dispose();
     }
   }
   ```

3. **Error Handling**
   ```dart
   Future<void> processEntry(QueueEntry entry) async {
     if (entry.isExpired) {
       await queue.markExpired(entry.id);
       return;
     }
     
     // Process entry...
   }
   ```

## Examples

### Cache Implementation

```dart
class CacheQueue<T> {
  final Queue<T> queue;
  
  Future<void> set(String key, T value, Duration ttl) async {
    await queue.enqueue(
      value,
      id: key,
      ttl: ttl,
    );
  }
  
  Future<T?> get(String key) async {
    final entry = await queue.getEntry(key);
    if (entry == null || entry.isExpired) {
      return null;
    }
    return entry.data;
  }
}
```

### Time-sensitive Processing

```dart
class TimeboxedProcessor {
  final Queue<Job> queue;
  
  Future<void> processTimeboxed() async {
    while (true) {
      final entry = await queue.dequeue();
      if (entry == null) break;
      
      if (entry.isExpired) {
        await queue.markExpired(entry.id);
        continue;
      }
      
      await processJob(entry.data);
    }
  }
}
```

## Limitations

1. No TTL update after creation
2. No TTL extension mechanism
3. No automatic cleanup scheduling
4. No TTL events/notifications 