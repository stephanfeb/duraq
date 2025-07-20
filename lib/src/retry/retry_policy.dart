/// Interface defining retry behavior for failed queue entries
abstract class RetryPolicy {
  /// Maximum number of retry attempts
  int get maxAttempts;

  /// Whether to retry the operation based on the current attempt count and error
  bool shouldRetry(int attempts, [Object? error]);

  /// Calculate delay before the next retry attempt
  Duration getRetryDelay(int attempts);

  /// Whether to move the entry to dead letter queue after all retries are exhausted
  bool shouldMoveToDeadLetter(int attempts, [Object? error]) => true;
} 