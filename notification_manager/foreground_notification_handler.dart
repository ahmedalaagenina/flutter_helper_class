import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:idara_esign/core/services/logger_service.dart';

/// The type of action to execute when a foreground notification is received.
enum NotificationActionType {
  /// Call an API endpoint (e.g. refresh data, mark as read).
  apiCall,

  /// Save/cache data locally (e.g. persist payload to local storage).
  saveData,

  /// Show an in-app UI element (e.g. snackbar, banner, dialog).
  showUI,

  /// A custom action that doesn't fit the categories above.
  custom,
}

/// Describes a single action that should be executed when a foreground
/// notification matching certain criteria arrives.
///
/// Example:
/// ```dart
/// ForegroundNotificationAction(
///   id: 'refresh_documents',
///   type: NotificationActionType.apiCall,
///   description: 'Refresh document list when a new document notification arrives',
///   matcher: (message) => message.data['type'] == 'document',
///   execute: (message, context) async {
///     context?.read<DocumentBloc>().add(const DocumentsRefreshEvent());
///   },
/// )
/// ```
class ForegroundNotificationAction {
  /// Unique identifier for this action. Used for registration/removal.
  final String id;

  /// Category of the action for debugging and organization.
  final NotificationActionType type;

  /// Human-readable description of what this action does (optional, used for debugging and organization).
  final String? description;

  /// Priority for execution ordering. Lower values execute first.
  /// Defaults to 0 (all equal priority).
  final int priority;

  /// Returns `true` if this action should be triggered for the given [message].
  ///
  /// If `null`, the action will match **every** foreground notification.
  final bool Function(RemoteMessage message)? matcher;

  /// The callback to execute when a matching notification arrives.
  ///
  /// [message] – the raw FCM message.
  /// [context] – the current root navigator `BuildContext` (nullable if the
  ///   navigator key has no context yet).
  final Future<void> Function(RemoteMessage message, BuildContext? context)
  execute;

  const ForegroundNotificationAction({
    required this.id,
    required this.type,
    required this.execute,
    this.description,
    this.matcher,
    this.priority = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForegroundNotificationAction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ForegroundNotificationAction(id: $id, type: $type, desc: $description)';
}

/// Centralized handler that manages what happens when a push notification
/// arrives **while the app is open and in the foreground**.
///
/// Register one or more [ForegroundNotificationAction]s to:
/// - Call APIs (refresh lists, mark-as-read, etc.)
/// - Persist data locally.
/// - Show in-app UI (snackbar, banner, overlay, etc.)
/// - Execute any custom logic.
///
/// Usage:
/// ```dart
/// final handler = ForegroundNotificationHandler.instance;
///
/// handler.registerAction(
///   ForegroundNotificationAction(
///     id: 'refresh_documents',
///     type: NotificationActionType.apiCall,
///     description: 'Refresh document list on new document notification',
///     matcher: (msg) => msg.data['type'] == 'document',
///     execute: (msg, ctx) async {
///       ctx?.read<DocumentBloc>().add(const DocumentsRefreshEvent());
///     },
///   ),
/// );
/// ```
class ForegroundNotificationHandler {
  static final ForegroundNotificationHandler _instance =
      ForegroundNotificationHandler._internal();

  factory ForegroundNotificationHandler() => _instance;

  static ForegroundNotificationHandler get instance => _instance;

  ForegroundNotificationHandler._internal();

  final List<ForegroundNotificationAction> _actions = [];

  /// Optional root context supplier. Defaults to `null`.
  /// Set this so that actions can access the widget tree (show snackbars, etc.).
  BuildContext? Function()? contextProvider;

  /// Register a new action. Replaces an existing action with the same [id].
  void registerAction(ForegroundNotificationAction action) {
    _actions.removeWhere((a) => a.id == action.id);
    _actions.add(action);
    _actions.sort((a, b) => a.priority.compareTo(b.priority));
    AppLog.d(
      'ForegroundNotificationHandler ▸ registered: ${action.id} '
      '(${action.type.name})',
    );
  }

  /// Register multiple actions at once.
  void registerActions(List<ForegroundNotificationAction> actions) {
    for (final action in actions) {
      registerAction(action);
    }
  }

  /// Remove a previously registered action by its [id].
  void removeAction(String id) {
    _actions.removeWhere((a) => a.id == id);
    AppLog.d('ForegroundNotificationHandler ▸ removed: $id');
  }

  /// Remove all registered actions.
  void clearActions() {
    _actions.clear();
    AppLog.d('ForegroundNotificationHandler ▸ all actions cleared');
  }

  /// Returns `true` if an action with the given [id] is registered.
  bool hasAction(String id) => _actions.any((a) => a.id == id);

  /// Returns a read-only view of the currently registered actions.
  List<ForegroundNotificationAction> get registeredActions =>
      List.unmodifiable(_actions);

  /// The core method – call this from [FirebaseMessaging.onMessage] to fan-out
  /// the notification to all matching handlers.
  ///
  /// Returns the list of action IDs that were executed.
  Future<List<String>> handleMessage(RemoteMessage message) async {
    final context = contextProvider?.call();

    final executed = <String>[];

    for (final action in _actions) {
      try {
        // If no matcher → matches everything.
        final matches = action.matcher?.call(message) ?? true;
        if (!matches) continue;

        AppLog.d(
          'ForegroundNotificationHandler ▸ executing: ${action.id} '
          '(${action.type.name})',
        );
        await action.execute(message, context);
        executed.add(action.id);
      } catch (e, stack) {
        AppLog.e(
          'ForegroundNotificationHandler ▸ error in action "${action.id}": $e, stackTrace: $stack',
        );
      }
    }

    if (executed.isEmpty) {
      AppLog.d(
        'ForegroundNotificationHandler ▸ no actions matched message '
        'data: ${message.data}',
      );
    }

    return executed;
  }
}
