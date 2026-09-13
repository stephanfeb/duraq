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

    // Regression tests for M5. The delay was computed as
    // `baseDelay.inMilliseconds * math.pow(2, attempts)` in int arithmetic,
    // which overflows a 64-bit int at attempt 63. The cap could not catch the
    // wrapped value: attempt 58 asked for a delay of roughly 60,000 years, and
    // from attempt 64 every delay came out zero, which turns backoff into a
    // tight retry loop.
    group('at attempt counts that used to overflow', () {
      final policy = ExponentialBackoff(
        baseDelay: const Duration(milliseconds: 100),
        maxDelay: const Duration(seconds: 30),
        maxAttempts: 1 << 30,
      );

      test('never exceeds maxDelay, at any attempt count', () {
        for (final attempts in [1, 5, 10, 30, 58, 60, 63, 64, 100, 1100, 5000]) {
          final delay = policy.getRetryDelay(attempts);
          expect(delay, lessThanOrEqualTo(const Duration(seconds: 30)),
              reason: 'attempt $attempts asked for ${delay.inMilliseconds}ms');
        }
      });

      test('is never negative and never zero', () {
        for (final attempts in [1, 30, 58, 60, 63, 64, 100, 1100, 5000]) {
          final delay = policy.getRetryDelay(attempts);
          expect(delay.isNegative, isFalse,
              reason: 'attempt $attempts scheduled a retry in the past');
          expect(delay, greaterThan(Duration.zero),
              reason: 'attempt $attempts would retry immediately, forever');
        }
      });

      test('settles at the ceiling rather than collapsing past it', () {
        // Well past the point the old arithmetic wrapped, the delay is still
        // the ceiling less jitter.
        for (final attempts in [64, 200, 5000]) {
          expect(policy.getRetryDelay(attempts),
              greaterThanOrEqualTo(const Duration(milliseconds: 22500)));
        }
      });

      test('still spreads retries out once it reaches the ceiling', () {
        // Jitter used to be applied before the cap, so every attempt past the
        // ceiling returned exactly maxDelay: consumers that failed together
        // came back together, which is the case jitter exists for.
        final delays = {
          for (var i = 0; i < 25; i++) policy.getRetryDelay(40).inMilliseconds,
        };

        expect(delays.length, greaterThan(1),
            reason: 'delays at the ceiling should not all be identical');
        expect(delays.every((ms) => ms <= 30000), isTrue);
      });

      test('a zero or negative configuration yields no delay', () {
        final none = ExponentialBackoff(
          baseDelay: Duration.zero,
          maxDelay: const Duration(seconds: 30),
        );
        expect(none.getRetryDelay(5), equals(Duration.zero));
      });
    });
  });
} 