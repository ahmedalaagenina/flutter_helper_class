import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:idara_driver/core/networking/offline_sync/queued_request.dart';

/// Persistent FIFO queue for offline requests, backed by Hive.
///
/// Each pending request is stored as a JSON string in a Hive box.
/// Items are returned sorted by [QueuedRequest.createdAt] (oldest first).
///
/// Usage:
/// ```dart
/// final queue = SyncQueue();
/// await queue.init();
///
/// await queue.enqueue(pendingRequest);
/// final items = await queue.getAll();
/// await queue.dequeue(items.first.id);
/// ```
class SyncQueue {
  static const String _boxName = 'offline_sync_queue';

  Box<String>? _box;

  final _pendingCountController = StreamController<int>.broadcast();

  /// Stream of pending item count — useful for UI badges.
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  /// Current number of pending items.
  int get pendingCount => _box?.length ?? 0;

  /// Whether the queue has been initialized.
  bool get isInitialized => _box?.isOpen ?? false;

  /// Initializes the Hive box for the sync queue.
  ///
  /// Must be called (and awaited) before any other operation.
  /// Requires [Hive.initFlutter()] to have been called first.
  Future<void> init() async {
    if (_box?.isOpen ?? false) return;
    _box = await Hive.openBox<String>(_boxName);
    _notifyCount();
  }

  /// Adds a [QueuedRequest] to the end of the queue.
  Future<void> enqueue(QueuedRequest request) async {
    _ensureInitialized();
    await _box!.put(request.id, request.toJsonString());
    _notifyCount();
    debugPrint(
      'SyncQueue: Enqueued ${request.method} ${request.path} '
      '(id: ${request.id}, pending: $pendingCount)',
    );
  }

  /// Removes a [QueuedRequest] from the queue by its ID.
  ///
  /// Typically called after a successful replay.
  Future<void> dequeue(String id) async {
    _ensureInitialized();
    await _box!.delete(id);
    _notifyCount();
    debugPrint('SyncQueue: Dequeued $id (pending: $pendingCount)');
  }

  /// Updates a [QueuedRequest] with an incremented retry count.
  ///
  /// Called when a replay attempt fails but the item hasn't
  /// exceeded its max retries yet.
  Future<void> incrementRetry(String id) async {
    _ensureInitialized();
    final json = _box!.get(id);
    if (json == null) return;

    final request = QueuedRequest.fromJsonString(json);
    final updated = request.incrementedRetry();
    await _box!.put(id, updated.toJsonString());
    debugPrint(
      'SyncQueue: Retry incremented for $id '
      '(${updated.retryCount}/${updated.maxRetries})',
    );
  }

  /// Returns the next item without removing it.
  Future<QueuedRequest?> peek() async {
    _ensureInitialized();
    final all = await getAll();
    return all.isEmpty ? null : all.first;
  }

  /// Returns all pending requests sorted by creation time (FIFO).
  Future<List<QueuedRequest>> getAll() async {
    _ensureInitialized();
    final items = <QueuedRequest>[];

    for (final json in _box!.values) {
      try {
        items.add(QueuedRequest.fromJsonString(json));
      } catch (e) {
        debugPrint('SyncQueue: Failed to parse item: $e');
      }
    }

    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  /// Clears all pending requests from the queue.
  Future<void> clear() async {
    _ensureInitialized();
    await _box!.clear();
    _notifyCount();
    debugPrint('SyncQueue: Cleared all items');
  }

  /// Closes the Hive box and releases resources.
  Future<void> close() async {
    await _pendingCountController.close();
    if (_box?.isOpen ?? false) {
      await _box!.close();
    }
  }

  void _notifyCount() {
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(pendingCount);
    }
  }

  void _ensureInitialized() {
    if (!(_box?.isOpen ?? false)) {
      throw StateError(
        'SyncQueue is not initialized. '
        'Call `await SyncQueue().init()` first.',
      );
    }
  }
}
