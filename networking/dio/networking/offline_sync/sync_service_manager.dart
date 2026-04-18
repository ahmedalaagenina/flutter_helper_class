import 'dart:async';

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
    final options = Options(
      method: request.method,
      headers: request.headers != null
          ? Map<String, dynamic>.from(request.headers!)
          : null,
      extra: {OfflineSyncInterceptor.replayMarker: true},
    );

    String url = request.path;
    if (request.baseUrl != null && request.baseUrl!.isNotEmpty) {
      // If path is already a full URL, use it directly
      if (!request.path.startsWith('http')) {
        url = request.path; // Let Dio's baseUrl handle it
      }
    }

    await _dio.request(
      url,
      data: request.data,
      queryParameters: request.queryParameters,
      options: options,
    );
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
