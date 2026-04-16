import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:idara_driver/core/networking/offline_sync/offline_sync_config.dart';
import 'package:idara_driver/core/networking/offline_sync/queued_request.dart';
import 'package:idara_driver/core/networking/offline_sync/sync_queue.dart';
import 'package:uuid/uuid.dart';

/// Dio interceptor that catches failed write requests when offline
/// and queues them for later replay via [SyncManager].
///
/// Place this interceptor **after** [RetryInterceptor] (so retries
/// happen first) and **before** any cache interceptor.
///
/// This interceptor is fully independent — no imports from
/// `core/networking/`. It only depends on `dio` and the
/// offline sync components.
///
/// Usage:
/// ```dart
/// dio.interceptors.add(
///   OfflineSyncInterceptor(
///     queue: syncQueue,
///     config: OfflineSyncConfig(
///       excludedPaths: ['/auth/login', '/auth/logout'],
///       syntheticResponseBuilder: (syncId) => {
///         '_offlineQueued': true,
///         '_syncId': syncId,
///         'message': 'Your custom offline message',
///       },
///     ),
///   ),
/// );
/// ```
class OfflineSyncInterceptor extends Interceptor {
  final SyncQueue _queue;
  final OfflineSyncConfig _config;

  static const _uuid = Uuid();

  /// Extra key used to mark replay requests to prevent re-queuing.
  static const replayMarker = '_isOfflineReplay';

  OfflineSyncInterceptor({
    required SyncQueue queue,
    OfflineSyncConfig config = const OfflineSyncConfig(),
  }) : _queue = queue,
       _config = config;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;

    // Don't re-queue replay requests
    if (options.extra[replayMarker] == true) {
      return handler.next(err);
    }

    // Only queue syncable methods (POST, PUT, DELETE, PATCH)
    if (!_config.isSyncable(options.method)) {
      return handler.next(err);
    }

    // Don't queue excluded paths
    if (_config.isExcluded(options.path)) {
      return handler.next(err);
    }

    // Only queue on offline/network errors
    if (!_isOfflineError(err)) {
      return handler.next(err);
    }

    // Check body size limit
    if (!_isWithinSizeLimit(options.data)) {
      debugPrint(
        'OfflineSyncInterceptor: Request body exceeds maxBodySize, '
        'skipping queue for ${options.method} ${options.path}',
      );
      return handler.next(err);
    }

    // Queue the request
    try {
      final syncId = _uuid.v4();
      final pendingRequest = QueuedRequest(
        id: syncId,
        method: options.method,
        path: options.path,
        baseUrl: options.baseUrl,
        data: _serializeData(options.data),
        queryParameters: options.queryParameters.isNotEmpty
            ? options.queryParameters
            : null,
        headers: _extractHeaders(options.headers),
        createdAt: DateTime.now(),
        maxRetries: _config.maxRetries,
      );

      await _queue.enqueue(pendingRequest);

      if (_config.returnSyntheticResponse) {
        // Return synthetic success — UI updates optimistically
        final syntheticData = _config.buildSyntheticResponse(syncId);
        return handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: syntheticData,
          ),
        );
      } else {
        // Pass through the error — let caller handle it
        return handler.next(err);
      }
    } catch (e) {
      debugPrint('OfflineSyncInterceptor: Failed to queue request: $e');
      return handler.next(err);
    }
  }

  /// Determines if the error is due to offline/network issues.
  bool _isOfflineError(DioException err) {
    // Connection timeout
    if (err.type == DioExceptionType.connectionTimeout) return true;

    // Send timeout (couldn't send data)
    if (err.type == DioExceptionType.sendTimeout) return true;

    // Connection error (no internet)
    if (err.type == DioExceptionType.connectionError) return true;

    // Unknown — check for SocketException (network unreachable)
    if (!kIsWeb && err.type == DioExceptionType.unknown) {
      if (err.error is SocketException) return true;
    }

    return false;
  }

  /// Checks if the request body is within the configured size limit.
  bool _isWithinSizeLimit(dynamic data) {
    if (_config.maxBodySize == null) return true;
    if (data == null) return true;

    try {
      final encoded = jsonEncode(data);
      return encoded.length <= _config.maxBodySize!;
    } catch (_) {
      // If we can't encode, it's likely not JSON-serializable
      // (e.g., FormData for file uploads) — skip it
      return false;
    }
  }

  /// Serializes request data to a JSON-compatible map.
  ///
  /// Returns null if the data is not serializable (e.g., FormData).
  Map<String, dynamic>? _serializeData(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);

    // Try JSON encode/decode round-trip
    try {
      final encoded = jsonEncode(data);
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      debugPrint(
        'OfflineSyncInterceptor: Cannot serialize data of type '
        '${data.runtimeType}, storing as null',
      );
    }
    return null;
  }

  /// Extracts only custom headers (not Dio's defaults) for storage.
  Map<String, String>? _extractHeaders(Map<String, dynamic> headers) {
    if (headers.isEmpty) return null;

    final filtered = <String, String>{};
    for (final entry in headers.entries) {
      // Skip standard Dio headers that will be re-added on replay
      if (entry.key.toLowerCase() == 'content-type') continue;
      if (entry.key.toLowerCase() == 'content-length') continue;
      if (entry.value != null) {
        filtered[entry.key] = entry.value.toString();
      }
    }
    return filtered.isEmpty ? null : filtered;
  }
}
