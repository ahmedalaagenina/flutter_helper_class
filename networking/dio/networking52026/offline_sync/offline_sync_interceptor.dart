import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:idara_driver/core/networking/idempotency_interceptor.dart';
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
  static const syncIdKey = '_syncId';
  static const offlineMessageKey = '_offlineQueuedMessage';

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

    // Prevent double queueing if the error bubbles up through nested interceptor chains
    if (options.extra['_hasBeenOfflineQueued'] == true) {
      return handler.next(err);
    }
    options.extra['_hasBeenOfflineQueued'] = true;

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

    // Multipart upload — try to capture file paths for later replay.
    // Must run BEFORE the size check, since FormData isn't JSON-encodable.
    Map<String, String>? filePaths;
    Map<String, dynamic>? multipartData;
    final isMultipart = options.data is FormData;
    if (isMultipart) {
      final captured = _captureMultipart(options);
      if (captured == null) {
        debugPrint(
          'OfflineSyncInterceptor: multipart with bytes-only files cannot '
          'be queued (no filesystem path) — ${options.path}',
        );
        return handler.next(err);
      }
      filePaths = captured.$1;
      multipartData = captured.$2;
    }

    // Body-size check applies only to JSON requests; file sizes are
    // governed by your storage budget, not the queue payload size.
    if (!isMultipart && !_isWithinSizeLimit(options.data)) {
      debugPrint(
        'OfflineSyncInterceptor: Request body exceeds maxBodySize, '
        'skipping queue for ${options.method} ${options.path}',
      );
      return handler.next(err);
    }

    // Queue the request
    try {
      final syncId = _uuid.v4();
      options.extra[syncIdKey] = syncId;
      options.extra[offlineMessageKey] = _config.defaultOfflineMessage;
      final pendingRequest = QueuedRequest(
        id: syncId,
        method: options.method,
        path: options.path,
        baseUrl: options.baseUrl,
        data: multipartData ?? _serializeData(options.data),
        queryParameters: options.queryParameters.isNotEmpty
            ? options.queryParameters
            : null,
        headers: _extractHeaders(options.headers),
        createdAt: DateTime.now(),
        maxRetries: _config.maxRetries,
        idempotencyKey:
            options.extra[IdempotencyInterceptor.extraKey] as String?,
        filePaths: filePaths,
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

  /// Reads the multipart spec stashed by `ApiService.multipartRequest`
  /// and returns `(filePaths, data)` if every file has a persistable
  /// local path. Returns `null` if any file is bytes-only (which cannot
  /// survive the queue).
  ///
  /// Spec shape (set by ApiService into `options.extra[specKey]`):
  /// ```dart
  /// {
  ///   'files': { 'fieldName': {'filePath': '/a/b.png', 'filename': 'b.png'} },
  ///   'data':  { 'name': 'foo', ... }
  /// }
  /// ```
  static const multipartSpecKey = '_offlineMultipartSpec';

  (Map<String, String>, Map<String, dynamic>)? _captureMultipart(
    RequestOptions options,
  ) {
    final spec = options.extra[multipartSpecKey];
    if (spec is! Map) return null;

    final filesSpec = spec['files'];
    if (filesSpec is! Map) return null;

    final paths = <String, String>{};
    for (final entry in filesSpec.entries) {
      final fieldName = entry.key.toString();
      final fileSpec = entry.value;
      if (fileSpec is! Map) return null;
      final path = fileSpec['filePath'];
      // Bytes-only files cannot be persisted across app restarts.
      if (path is! String || path.isEmpty) return null;
      paths[fieldName] = path;
    }

    final data = spec['data'];
    final dataMap = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};

    return (paths, dataMap);
  }

  /// Extracts only custom headers (not Dio's defaults) for storage.
  Map<String, String>? _extractHeaders(Map<String, dynamic> headers) {
    if (headers.isEmpty) return null;

    final filtered = <String, String>{};
    for (final entry in headers.entries) {
      final key = entry.key.toLowerCase();
      // Skip standard Dio headers that will be re-added on replay
      if (key == 'content-type') continue;
      if (key == 'content-length') continue;
      // Never persist auth — AuthInterceptor reattaches a fresh token on replay.
      // Storing a stale Bearer token in Hive is both a security and a
      // correctness problem (expired tokens never refresh on the queued copy).
      if (key == 'authorization') continue;
      if (entry.value != null) {
        filtered[entry.key] = entry.value.toString();
      }
    }
    return filtered.isEmpty ? null : filtered;
  }
}
