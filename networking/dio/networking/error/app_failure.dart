sealed class AppFailure {
  final String message;
  final int? code;
  final Map<String, dynamic>? data;

  const AppFailure(this.message, this.code, [this.data]);

  @override
  String toString() =>
      '${runtimeType.toString()}: $message (Code: ${code ?? 'N/A'}, Data: ${data ?? 'N/A'})';
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([
    super.message = 'No internet connection',
    super.code,
    super.data,
  ]);
}

class ServerFailure extends AppFailure {
  const ServerFailure(super.message, [super.code, super.data]);
}

class CacheFailure extends AppFailure {
  const CacheFailure(super.message, [super.code, super.data]);
}

class NoCachedDataFailure extends AppFailure {
  const NoCachedDataFailure([
    super.message = 'No cached data found',
    super.code,
    super.data,
  ]);
}

// Inside your failures file alongside NetworkFailure, etc.
class OfflineQueuedFailure extends AppFailure {
  final String? syncId;
  const OfflineQueuedFailure({
    this.syncId,
    String message = 'You are offline. Request queued and will sync automatically.',
    int? code,
    Map<String, dynamic>? data,
  }) : super(message, code, data);
}

class UnknownFailure extends AppFailure {
  const UnknownFailure([
    super.message = "An unknown error occurred.",
    super.code,
    super.data,
  ]);
}
