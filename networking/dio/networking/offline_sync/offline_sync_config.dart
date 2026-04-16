/// Configuration for the offline sync layer.
///
/// Controls which requests get queued when offline, retry behavior,
/// excluded endpoints, and synthetic response format.
///
/// Usage:
/// ```dart
/// final config = OfflineSyncConfig(
///   maxRetries: 5,
///   excludedPaths: ['/auth/login', '/auth/logout'],
///   syncableMethods: ['POST', 'PUT', 'DELETE', 'PATCH'],
///   syntheticResponseBuilder: (syncId) => {
///     '_offlineQueued': true,
///     '_syncId': syncId,
///     'message': 'Your custom message here',
///   },
/// );
/// ```
class OfflineSyncConfig {
  /// HTTP methods that should be queued when offline.
  ///
  /// Only write methods should be queued — GET/HEAD are read-only
  /// and should be handled by cache interceptors instead.
  ///
  /// Default: `['POST', 'PUT', 'DELETE', 'PATCH']`
  final List<String> syncableMethods;

  /// URL paths that should **never** be queued for offline sync.
  ///
  /// Supports both exact path matches and substring matching.
  /// Typically used to exclude auth-related endpoints.
  ///
  /// Example: `['/auth/login', '/auth/logout', '/auth/refresh']`
  final List<String> excludedPaths;

  /// URL path patterns (regex) that should **never** be queued.
  ///
  /// For more complex exclusion rules than simple string matching.
  ///
  /// Example: `[RegExp(r'/auth/.*')]`
  final List<RegExp> excludedPatterns;

  /// Maximum number of retry attempts for a failed sync item
  /// before it is discarded.
  ///
  /// Default: `5`
  final int maxRetries;

  /// Delay between processing queued items during sync.
  ///
  /// Prevents flooding the server with rapid-fire requests
  /// when connectivity is restored.
  ///
  /// Default: `Duration(seconds: 1)`
  final Duration processingDelay;

  /// Maximum request body size (in bytes) to queue.
  ///
  /// Prevents queuing large file uploads that would bloat
  /// the Hive database. Set to `null` to allow any size.
  ///
  /// Default: `5 * 1024 * 1024` (5 MB)
  final int? maxBodySize;

  /// Whether to return a synthetic success response when a
  /// request is queued offline.
  ///
  /// If `true`, the interceptor returns a fake `200` response
  /// so the UI can update optimistically (e.g., show success).
  ///
  /// If `false`, the original `DioException` is passed through,
  /// and the caller must handle the offline error.
  ///
  /// Default: `true`
  final bool returnSyntheticResponse;

  /// Default message returned in the synthetic response when a 
  /// request is queued offline.
  /// 
  /// Only used if [syntheticResponseBuilder] is null.
  /// 
  /// Default: `'Saved offline. Will sync when connected.'`
  final String defaultOfflineMessage;

  /// Custom builder for the synthetic response data.
  ///
  /// Called when a request is queued offline and
  /// [returnSyntheticResponse] is `true`.
  ///
  /// The `syncId` parameter is the unique identifier of the
  /// queued request, which can be used to track its status.
  ///
  /// Default returns:
  /// ```dart
  /// {
  ///   '_offlineQueued': true,
  ///   '_syncId': syncId,
  ///   'message': [defaultOfflineMessage],
  /// }
  /// ```
  final Map<String, dynamic> Function(String syncId)? syntheticResponseBuilder;

  const OfflineSyncConfig({
    this.syncableMethods = const ['POST', 'PUT', 'DELETE', 'PATCH'],
    this.excludedPaths = const [],
    this.excludedPatterns = const [],
    this.maxRetries = 5,
    this.processingDelay = const Duration(seconds: 1),
    this.maxBodySize = 5 * 1024 * 1024, // 5 MB
    this.returnSyntheticResponse = true,
    this.defaultOfflineMessage = 'Saved offline. Will sync when connected.',
    this.syntheticResponseBuilder,
  });

  /// Builds the synthetic response data for a queued request.
  Map<String, dynamic> buildSyntheticResponse(String syncId) {
    if (syntheticResponseBuilder != null) {
      return syntheticResponseBuilder!(syncId);
    }
    return {
      '_offlineQueued': true,
      '_syncId': syncId,
      'message': defaultOfflineMessage,
    };
  }

  /// Checks if a request path is excluded from offline sync.
  bool isExcluded(String path) {
    // Check exact/substring matches
    for (final excluded in excludedPaths) {
      if (path.contains(excluded)) return true;
    }
    // Check regex patterns
    for (final pattern in excludedPatterns) {
      if (pattern.hasMatch(path)) return true;
    }
    return false;
  }

  /// Checks if a request method is syncable.
  bool isSyncable(String method) {
    return syncableMethods.contains(method.toUpperCase());
  }

  /// Creates a copy with the given overrides.
  OfflineSyncConfig copyWith({
    List<String>? syncableMethods,
    List<String>? excludedPaths,
    List<RegExp>? excludedPatterns,
    int? maxRetries,
    Duration? processingDelay,
    int? maxBodySize,
    bool? returnSyntheticResponse,
    String? defaultOfflineMessage,
    Map<String, dynamic> Function(String syncId)? syntheticResponseBuilder,
  }) {
    return OfflineSyncConfig(
      syncableMethods: syncableMethods ?? this.syncableMethods,
      excludedPaths: excludedPaths ?? this.excludedPaths,
      excludedPatterns: excludedPatterns ?? this.excludedPatterns,
      maxRetries: maxRetries ?? this.maxRetries,
      processingDelay: processingDelay ?? this.processingDelay,
      maxBodySize: maxBodySize ?? this.maxBodySize,
      returnSyntheticResponse:
          returnSyntheticResponse ?? this.returnSyntheticResponse,
      defaultOfflineMessage:
          defaultOfflineMessage ?? this.defaultOfflineMessage,
      syntheticResponseBuilder:
          syntheticResponseBuilder ?? this.syntheticResponseBuilder,
    );
  }
}
