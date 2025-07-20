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

  @override
  Duration getRetryDelay(int attempts) {
    // Calculate exponential delay: baseDelay * 2^attempt
    final exponentialDelay = baseDelay.inMilliseconds * math.pow(2, attempts);
    
    // Add jitter: random value between 75% and 100% of calculated delay
    final jitterMultiplier = 0.75 + (_random.nextDouble() * 0.25);
    final delayWithJitter = (exponentialDelay * jitterMultiplier).round();
    
    // Ensure delay doesn't exceed maxDelay
    return Duration(
      milliseconds: math.min(delayWithJitter, maxDelay.inMilliseconds),
    );
  }

  @override
  bool shouldMoveToDeadLetter(int attempts, [Object? error]) {
    return attempts >= maxAttempts;
  }
} 