import 'package:test/test.dart';
import 'package:duraq/src/retry/exponential_backoff.dart';

void main() {
  group('ExponentialBackoff', () {
    test('respects max attempts', () {
      final policy = ExponentialBackoff(maxAttempts: 3);
      
      expect(policy.shouldRetry(0), isTrue);
      expect(policy.shouldRetry(1), isTrue);
      expect(policy.shouldRetry(2), isTrue);
      expect(policy.shouldRetry(3), isFalse);
      expect(policy.shouldRetry(4), isFalse);
    });

    test('generates increasing delays', () {
      final policy = ExponentialBackoff(
        baseDelay: Duration(milliseconds: 100),
        maxDelay: Duration(seconds: 30),
      );

      final delay1 = policy.getRetryDelay(0);
      final delay2 = policy.getRetryDelay(1);
      final delay3 = policy.getRetryDelay(2);

      expect(delay2.inMilliseconds > delay1.inMilliseconds, isTrue);
      expect(delay3.inMilliseconds > delay2.inMilliseconds, isTrue);
    });

    test('respects max delay', () {
      final policy = ExponentialBackoff(
        baseDelay: Duration(milliseconds: 100),
        maxDelay: Duration(seconds: 1),
      );

      // With these parameters, by attempt 5 we would exceed maxDelay
      // without the limit
      final delay = policy.getRetryDelay(5);
      expect(delay.inSeconds <= 1, isTrue);
    });

    test('adds jitter to delays', () {
      final policy = ExponentialBackoff(
        baseDelay: Duration(milliseconds: 100),
      );

      // Get multiple delays for the same attempt
      final delays = List.generate(10, (_) => policy.getRetryDelay(1));

      // Verify they're not all the same (jitter is working)
      final uniqueDelays = delays.toSet();
      expect(uniqueDelays.length > 1, isTrue);

      // Verify they're within expected bounds
      final baseDelay = 100 * 2; // 100ms * 2^1
      for (final delay in delays) {
        // Should be between 75% and 100% of base delay
        expect(delay.inMilliseconds >= (baseDelay * 0.75).round(), isTrue);
        expect(delay.inMilliseconds <= baseDelay, isTrue);
      }
    });

    test('handles dead letter queue transition', () {
      final policy = ExponentialBackoff(maxAttempts: 3);
      
      expect(policy.shouldMoveToDeadLetter(0), isFalse);
      expect(policy.shouldMoveToDeadLetter(1), isFalse);
      expect(policy.shouldMoveToDeadLetter(2), isFalse);
      expect(policy.shouldMoveToDeadLetter(3), isTrue);
      expect(policy.shouldMoveToDeadLetter(4), isTrue);
    });
  });
} 