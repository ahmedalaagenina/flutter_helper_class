import 'package:idara_driver/core/networking/offline_sync/queued_request.dart';

/// Events emitted by [SyncManager] for UI consumption.
///
/// Use these events to show sync status indicators, snackbars,
/// badges, or any other UI feedback.
///
/// Example — listening in a BLoC:
/// ```dart
/// syncManager.eventStream.listen((event) {
///   switch (event) {
///     case SyncStarted():
///       // Show syncing indicator
///     case SyncCompleted(:final successCount, :final failedCount):
///       // Show "X items synced" snackbar
///     case SyncItemSucceeded(:final request):
///       // Optionally refresh specific data
///     case SyncItemFailed(:final request, :final error):
///       // Show error for specific item
///     case SyncIdle(:final pendingCount):
///       // Update badge count
///   }
/// });
/// ```
sealed class SyncEvent {
  const SyncEvent();
}

/// Emitted when the sync process starts.
class SyncStarted extends SyncEvent {
  /// Total number of items to process.
  final int totalCount;

  const SyncStarted({required this.totalCount});

  @override
  String toString() => 'SyncStarted(totalCount: $totalCount)';
}

/// Emitted when the entire sync process completes.
class SyncCompleted extends SyncEvent {
  /// Number of successfully synced items.
  final int successCount;

  /// Number of items that failed (may be retried later).
  final int failedCount;

  const SyncCompleted({required this.successCount, required this.failedCount});

  @override
  String toString() =>
      'SyncCompleted(success: $successCount, failed: $failedCount)';
}

/// Emitted when a single queued request is successfully replayed.
class SyncItemSucceeded extends SyncEvent {
  /// The request that was successfully synced.
  final QueuedRequest request;

  const SyncItemSucceeded({required this.request});

  @override
  String toString() => 'SyncItemSucceeded(${request.method} ${request.path})';
}

/// Emitted when a single queued request fails during replay.
class SyncItemFailed extends SyncEvent {
  /// The request that failed.
  final QueuedRequest request;

  /// Error description.
  final String error;

  /// Whether the item will be retried (hasn't exceeded max retries).
  final bool willRetry;

  const SyncItemFailed({
    required this.request,
    required this.error,
    required this.willRetry,
  });

  @override
  String toString() =>
      'SyncItemFailed(${request.method} ${request.path}, '
      'error: $error, willRetry: $willRetry)';
}

/// Emitted when a request has exceeded max retries and is discarded.
class SyncItemDiscarded extends SyncEvent {
  /// The request that was discarded.
  final QueuedRequest request;

  const SyncItemDiscarded({required this.request});

  @override
  String toString() =>
      'SyncItemDiscarded(${request.method} ${request.path}, '
      'retries: ${request.retryCount}/${request.maxRetries})';
}

/// Emitted when the sync manager is idle (no active sync).
class SyncIdle extends SyncEvent {
  /// Number of items still pending in the queue.
  final int pendingCount;

  const SyncIdle({required this.pendingCount});

  @override
  String toString() => 'SyncIdle(pending: $pendingCount)';
}
