import 'dart:math' as math;
import 'retry_policy.dart';

/// Implements exponential backoff retry strategy with jitter
class ExponentialBackoff implements RetryPolicy {
  /// Base delay for retry attempts
  final Duration baseDelay;

  /// Maximum delay between retries
  final Duration maxDelay;

  /// Maximum number of retry attempts
  @override
  final int maxAttempts;

  /// Random number generator for jitter
  final _random = math.Random();

  /// Creates an exponential backoff retry policy
  /// 
  /// [baseDelay] is the initial delay between retries
  /// [maxDelay] is the maximum delay between retries
  /// [maxAttempts] is the maximum number of retry attempts
  ExponentialBackoff({
    this.baseDelay = const Duration(milliseconds: 100),
    this.maxDelay = const Duration(seconds: 30),
    this.maxAttempts = 5,
  });

  @override
  bool shouldRetry(int attempts, [Object? error]) {
    return attempts < maxAttempts;
  }

  /// The delay before attempt [attempts], never longer than [maxDelay].
  ///
  /// The delay doubles per attempt until it reaches [maxDelay], then stays
  /// there. Jitter of up to 25% is taken off whatever that works out to,
  /// including at the ceiling, so consumers that failed together do not all
  /// come back at the same instant.
  @override
  Duration getRetryDelay(int attempts) {
    final baseMs = baseDelay.inMilliseconds;
    final capMs = maxDelay.inMilliseconds;
    if (baseMs <= 0 || capMs <= 0) return Duration.zero;

    // Deliberately double arithmetic. `2^attempts` as an int overflows a
    // 64-bit int at attempt 63 and wraps, which the cap below could not catch
    // because it was comparing against the wrapped value: attempt 58 asked for
    // a delay of 60,000 years, and from attempt 64 every delay came out zero,
    // turning backoff into a tight retry loop. Doubles saturate to infinity
    // rather than wrapping, and `min` handles infinity correctly.
    final exponentialMs =
        baseMs * math.pow(2.0, attempts < 0 ? 0 : attempts).toDouble();
    final cappedMs = math.min(exponentialMs, capMs.toDouble());

    // Jitter applies after the cap. Applying it before, as this did, meant
    // every attempt past the ceiling asked for exactly maxDelay with no
    // spread at all — the point in the backoff where spread matters most.
    final jitter = 0.75 + (_random.nextDouble() * 0.25);
    return Duration(milliseconds: (cappedMs * jitter).round());
  }

  @override
  bool shouldMoveToDeadLetter(int attempts, [Object? error]) {
    return attempts >= maxAttempts;
  }
} 