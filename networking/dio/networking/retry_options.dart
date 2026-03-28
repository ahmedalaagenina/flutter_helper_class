class RetryOptions {
  final int maxRetries;
  final Duration retryDelay;

  RetryOptions({required this.maxRetries, required this.retryDelay});
}
