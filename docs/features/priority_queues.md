# Priority Queues

DuraQ supports priority-based queuing, allowing more important entries to be processed before less important ones.

## Overview

Priority queuing ensures that entries with higher priority (lower priority numbers) are retrieved before entries with lower priority, regardless of their creation time. Within the same priority level, entries are processed in FIFO (First-In-First-Out) order.

## Usage

### Basic Priority Queue

```dart
final queue = manager.queue<String>('notifications');

// High priority message (priority -1)
await queue.enqueue(
  'Critical system alert',
  priority: -1,
);

// Normal priority message (default priority 0)
await queue.enqueue(
  'Regular notification',
);

// Low priority message (priority 1)
await queue.enqueue(
  'Background task notification',
  priority: 1,
);
```

### Priority Levels

- **Negative numbers**: High priority (processed first)
- **Zero**: Normal priority (default)
- **Positive numbers**: Low priority (processed last)

Example priority scheme:
```dart
const priorities = {
  critical: -2,    // Critical alerts
  high: -1,        // High priority notifications
  normal: 0,       // Regular messages (default)
  low: 1,          // Background tasks
  bulk: 2,         // Bulk operations
};
```

## Implementation Details

### Queue Entry

Each queue entry includes a priority field:
```dart
final entry = QueueEntry<String>(
  id: 'msg-123',
  data: 'High priority message',
  priority: -1,
  createdAt: DateTime.now(),
);
```

### Storage

The SQLite storage implementation:
- Uses an index for efficient priority-based retrieval
- Orders entries by priority first, then creation time
- Maintains FIFO order within the same priority level

### Retrieval Order

Entries are retrieved in the following order:
1. Highest priority (lowest number) first
2. Within same priority, oldest entries first
3. Lower priority entries only after higher priority queue is empty

## Best Practices

1. **Priority Levels**
   - Keep priority range small (-2 to 2 is often sufficient)
   - Document priority levels in your application
   - Use constants for priority values

2. **Default Priority**
   - Use priority 0 as default for regular entries
   - Reserve negative priorities for truly urgent items
   - Use positive priorities for background/bulk processing

3. **Priority Design**
   ```dart
   // Define priority constants
   abstract class QueuePriority {
     static const critical = -2;
     static const high = -1;
     static const normal = 0;
     static const low = 1;
     static const bulk = 2;
   }

   // Use in code
   await queue.enqueue(
     'Critical alert',
     priority: QueuePriority.critical,
   );
   ```

## Examples

### Priority-based Processing

```dart
// Create a queue
final notificationQueue = manager.queue<Notification>('notifications');

// Enqueue items with different priorities
await notificationQueue.enqueue(
  Notification(type: 'system_alert', message: 'Server crash detected'),
  priority: -2,
);

await notificationQueue.enqueue(
  Notification(type: 'user_message', message: 'New friend request'),
  priority: 0,
);

await notificationQueue.enqueue(
  Notification(type: 'analytics', message: 'Daily stats ready'),
  priority: 1,
);

// Process queue (will handle system alert first)
while (true) {
  final notification = await notificationQueue.dequeue();
  if (notification == null) break;
  
  await processNotification(notification);
}
```

### Mixed Priority Processing

```dart
// Process different types with appropriate priorities
Future<void> enqueueNotification(Notification notification) async {
  final priority = switch (notification.type) {
    'system_alert' => QueuePriority.critical,
    'user_message' => QueuePriority.normal,
    'analytics' => QueuePriority.low,
    _ => QueuePriority.normal,
  };

  await notificationQueue.enqueue(notification, priority: priority);
}
```

## Limitations

1. Priority cannot be changed after entry creation
2. No sub-priorities within the same priority level
3. No dynamic priority adjustment based on waiting time 