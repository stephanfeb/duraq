import 'package:test/test.dart';
import 'package:duraq/duraq.dart';

void main() {
  group('QueueEntry', () {
    test('creates with required fields', () {
      final now = DateTime.now();
      final entry = QueueEntry<String>(
        id: 'test',
        data: 'test data',
        createdAt: now,
      );

      expect(entry.id, equals('test'));
      expect(entry.data, equals('test data'));
      expect(entry.createdAt, equals(now));
      expect(entry.attempts, equals(0));
      expect(entry.priority, equals(0));
      expect(entry.status, equals(EntryStatus.pending));
      expect(entry.errorMessage, isNull);
      expect(entry.expiresAt, isNull);
      expect(entry.nextRetryAt, isNull);
    });

    test('creates with all fields', () {
      final now = DateTime.now();
      final entry = QueueEntry<String>(
        id: 'test',
        data: 'test data',
        createdAt: now,
        lastUpdatedAt: now.add(Duration(minutes: 1)),
        attempts: 2,
        priority: 1,
        status: EntryStatus.failed,
        errorMessage: 'test error',
        expiresAt: now.add(Duration(hours: 1)),
        nextRetryAt: now.add(Duration(minutes: 5)),
      );

      expect(entry.id, equals('test'));
      expect(entry.data, equals('test data'));
      expect(entry.createdAt, equals(now));
      expect(entry.lastUpdatedAt, equals(now.add(Duration(minutes: 1))));
      expect(entry.attempts, equals(2));
      expect(entry.priority, equals(1));
      expect(entry.status, equals(EntryStatus.failed));
      expect(entry.errorMessage, equals('test error'));
      expect(entry.expiresAt, equals(now.add(Duration(hours: 1))));
      expect(entry.nextRetryAt, equals(now.add(Duration(minutes: 5))));
    });

    test('handles expiration correctly', () {
      final now = DateTime.now();
      
      final notExpired = QueueEntry<String>(
        id: 'test1',
        data: 'test data',
        createdAt: now,
        expiresAt: now.add(Duration(hours: 1)),
      );
      expect(notExpired.isExpired, isFalse);

      final expired = QueueEntry<String>(
        id: 'test2',
        data: 'test data',
        createdAt: now.subtract(Duration(hours: 2)),
        expiresAt: now.subtract(Duration(hours: 1)),
      );
      expect(expired.isExpired, isTrue);
    });

    test('copies with updated fields', () {
      final now = DateTime.now();
      final entry = QueueEntry<String>(
        id: 'test',
        data: 'test data',
        createdAt: now,
      );

      final updated = entry.copyWith(
        status: EntryStatus.failed,
        errorMessage: 'test error',
        attempts: 1,
      );

      expect(updated.id, equals('test'));
      expect(updated.data, equals('test data'));
      expect(updated.createdAt, equals(now));
      expect(updated.status, equals(EntryStatus.failed));
      expect(updated.errorMessage, equals('test error'));
      expect(updated.attempts, equals(1));
    });

    test('marks as failed', () {
      final now = DateTime.now();
      final entry = QueueEntry<String>(
        id: 'test',
        data: 'test data',
        createdAt: now,
      );

      final failed = entry.markFailed('test error');

      expect(failed.status, equals(EntryStatus.failed));
      expect(failed.errorMessage, equals('test error'));
      expect(failed.attempts, equals(1));
      expect(failed.lastUpdatedAt.isAfter(now), isTrue);
    });

    test('marks as completed', () {
      final now = DateTime.now();
      final entry = QueueEntry<String>(
        id: 'test',
        data: 'test data',
        createdAt: now,
      );

      final completed = entry.markCompleted();

      expect(completed.status, equals(EntryStatus.completed));
      expect(completed.lastUpdatedAt.isAfter(now), isTrue);
    });

    test('schedules retry', () {
      final now = DateTime.now();
      final entry = QueueEntry<String>(
        id: 'test',
        data: 'test data',
        createdAt: now,
        status: EntryStatus.failed,
      );

      final retryTime = now.add(Duration(minutes: 5));
      final scheduled = entry.scheduleRetry(retryTime);

      expect(scheduled.status, equals(EntryStatus.pending));
      expect(scheduled.nextRetryAt, equals(retryTime));
      expect(scheduled.lastUpdatedAt.isAfter(now), isTrue);
    });

    test('marks as dead letter', () {
      final now = DateTime.now();
      final entry = QueueEntry<String>(
        id: 'test',
        data: 'test data',
        createdAt: now,
        status: EntryStatus.failed,
      );

      final deadLetter = entry.markDeadLetter();

      expect(deadLetter.status, equals(EntryStatus.deadLetter));
      expect(deadLetter.lastUpdatedAt.isAfter(now), isTrue);
    });
  });
} 