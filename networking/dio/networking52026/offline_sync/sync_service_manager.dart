import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:idara_driver/core/networking/networking.dart';

/// Monitors connectivity and processes the offline sync queue
/// when the device comes back online.
///
/// Uses its own Dio instance (without [OfflineSyncInterceptor])
/// to replay requests, preventing infinite re-queuing loops.
class SyncServiceManager {
  final Dio _dio;
  final SyncQueue _queue;
  final OfflineSyncConfig _config;
  final NetworkInfo _networkInfo;

  StreamSubscription<bool>? _connectivitySubscription;
  final _eventController = StreamController<SyncEvent>.broadcast();
  bool _isSyncing = false;
  bool _disposed = false;

  /// Stream of [SyncEvent] for UI consumption.
  Stream<SyncEvent> get eventStream => _eventController.stream;

  /// Whether the sync manager is currently processing the queue.
  bool get isSyncing => _isSyncing;

  /// Number of pending items in the queue.
  int get pendingCount => _queue.pendingCount;

  /// Stream of pending item count.
  Stream<int> get pendingCountStream => _queue.pendingCountStream;

  SyncServiceManager({
    /// Dio used to replay queued requests. SHOULD be a dedicated instance
    /// built with [NetworkHelper.createReplayDio] — only Auth + Retry, no
    /// duplicate-detection, no cache, no offline-sync. Passing the main Dio
    /// still works (replayMarker prevents re-queue) but wastes cycles.
    required Dio dio,
    required SyncQueue queue,
    required NetworkInfo networkInfo,
    OfflineSyncConfig config = const OfflineSyncConfig(),
  }) : _dio = dio,
       _queue = queue,
       _networkInfo = networkInfo,
       _config = config;

  /// Starts listening to connectivity changes.
  Future<void> init() async {
    if (_disposed) {
      throw StateError('SyncManager has been disposed and cannot be reused.');
    }

    _connectivitySubscription = _networkInfo.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    // Initial check
    if (await _networkInfo.isConnected && _queue.pendingCount > 0) {
      debugPrint(
        'SyncManager: Found ${_queue.pendingCount} pending items on init. '
        'Processing...',
      );
      await processQueue();
    }
  }

  /// Callback for connectivity changes.
  void _onConnectivityChanged(bool isOnline) {
    if (isOnline && !_isSyncing && _queue.pendingCount > 0) {
      debugPrint(
        'SyncManager: Connectivity restored. '
        'Processing ${_queue.pendingCount} pending items...',
      );
      processQueue();
    }
  }

  /// Processes all pending items in the queue (FIFO order).
  ///
  /// Can also be called manually to force a sync attempt.
  Future<void> processQueue() async {
    if (_isSyncing || _disposed) return;

    _isSyncing = true;
    int successCount = 0;
    int failedCount = 0;

    final items = await _queue.getAll();
    if (items.isEmpty) {
      _isSyncing = false;
      return;
    }

    _emitEvent(SyncStarted(totalCount: items.length));

    for (final request in items) {
      if (_disposed) break;

      // Check if the item has exceeded max retries
      if (request.isExpired) {
        debugPrint(
          'SyncManager: Discarding expired request '
          '${request.method} ${request.path} '
          '(${request.retryCount}/${request.maxRetries})',
        );
        await _queue.dequeue(request.id);
        _emitEvent(SyncItemDiscarded(request: request));
        failedCount++;
        continue;
      }

      try {
        await _replayRequest(request);
        await _queue.dequeue(request.id);
        successCount++;
        _emitEvent(SyncItemSucceeded(request: request));

        debugPrint('SyncManager: ✅ Synced ${request.method} ${request.path}');
      } catch (e) {
        await _queue.incrementRetry(request.id);

        final updated = request.incrementedRetry();
        final willRetry = !updated.isExpired;

        failedCount++;
        _emitEvent(
          SyncItemFailed(
            request: request,
            error: e.toString(),
            willRetry: willRetry,
          ),
        );

        debugPrint(
          'SyncManager: ❌ Failed ${request.method} ${request.path} '
          '(retry ${updated.retryCount}/${updated.maxRetries}): $e',
        );

        if (!willRetry) {
          await _queue.dequeue(request.id);
          _emitEvent(SyncItemDiscarded(request: updated));
        }
      }

      // Delay between items to avoid flooding
      if (!_disposed) {
        await Future.delayed(_config.processingDelay);
      }
    }

    _isSyncing = false;
    _emitEvent(
      SyncCompleted(successCount: successCount, failedCount: failedCount),
    );
    _emitEvent(SyncIdle(pendingCount: _queue.pendingCount));
  }

  /// Replays a single [QueuedRequest] via Dio.
  Future<void> _replayRequest(QueuedRequest request) async {
    final extra = <String, dynamic>{
      OfflineSyncInterceptor.replayMarker: true,
    };

    // Preserve idempotency across replay so the server can dedupe.
    if (request.idempotencyKey != null) {
      extra[IdempotencyInterceptor.extraKey] = request.idempotencyKey;
    }

    final options = Options(
      method: request.method,
      headers: request.headers != null
          ? Map<String, dynamic>.from(request.headers!)
          : null,
      extra: extra,
    );

    // Rebuild multipart payload from persisted file paths, or fall back
    // to the stored JSON body for plain requests.
    dynamic body;
    if (request.isMultipart) {
      body = await _rebuildFormData(request);
    } else {
      body = request.data;
    }

    String url = request.path;
    if (request.baseUrl != null && request.baseUrl!.isNotEmpty) {
      if (!request.path.startsWith('http')) {
        url = request.path; // Let Dio's baseUrl handle it
      }
    }

    await _dio.request(
      url,
      data: body,
      queryParameters: request.queryParameters,
      options: options,
    );
  }

  /// Rebuilds a multipart body from persisted file paths.
  /// Files that have since been deleted are skipped — the server gets
  /// the upload without that field. Adjust to throw if you need
  /// stricter semantics.
  Future<FormData> _rebuildFormData(QueuedRequest request) async {
    final entries = <MapEntry<String, dynamic>>[];

    if (request.data != null) {
      for (final entry in request.data!.entries) {
        entries.add(MapEntry(entry.key, entry.value));
      }
    }

    for (final entry in request.filePaths!.entries) {
      final path = entry.value;
      if (!await File(path).exists()) {
        debugPrint(
          'SyncManager: queued file missing on replay, skipping field '
          '"${entry.key}" — $path',
        );
        continue;
      }
      final filename = path.split('/').last;
      entries.add(
        MapEntry(
          entry.key,
          await MultipartFile.fromFile(path, filename: filename),
        ),
      );
    }

    return FormData.fromMap(Map.fromEntries(entries));
  }

  void _emitEvent(SyncEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
      debugPrint('SyncManager: Event → $event');
    }
  }

  /// Stops listening to connectivity and releases resources.
  Future<void> dispose() async {
    _disposed = true;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    await _eventController.close();
  }
}
