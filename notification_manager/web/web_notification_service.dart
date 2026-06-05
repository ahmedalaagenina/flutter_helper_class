import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:idara_esign/core/notification_manager/notification_api.dart';
import 'package:idara_esign/core/notification_manager/notification_navigator.dart';
import 'package:idara_esign/core/services/logger_service.dart';

import 'browser_notification_stub.dart'
    if (dart.library.js_interop) 'browser_notification_web.dart';

/// Web-only Firebase Cloud Messaging setup.
///
/// Native (Android/iOS) push goes through `NotificationApi` +
/// `NotificationHelper`; this is the web-safe counterpart and skips
/// `flutter_local_notifications` and `dart:io`.
///
/// See `lib/core/notification_manager/web/README.md`.
class WebNotificationService {
  WebNotificationService._();

  /// Public VAPID key — Firebase Console → Project Settings →
  /// Cloud Messaging → Web Push certificates. Safe to commit.
  static const String vapidKey =
      'BO8Wlb8DM7AKdeV7m0knleRLztSYAVYwIPu5qBIoNV94274V9X3PfCDl9ZPo5ChQTT_ZtypSGIytr0c-npRjEZg';

  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  static bool _initialized = false;

  static Future<void> init() async {
    if (!kIsWeb || _initialized) return;
    _initialized = true;

    // 1. Permission. On web this also satisfies the browser-level
    //    Notification permission used by `showNotification`.
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
      '[WebNotificationService] permission: ${settings.authorizationStatus}',
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      AppLog.e('[WebNotificationService] permission denied — aborting setup');
      return;
    }

    // 2. Token + refresh. The token can rotate (browser data clear, long
    //    inactivity); the refresh stream lets us keep the backend in sync.
    final token = await getToken();
    debugPrint('[WebNotificationService] FCM token: $token');
    if (token != null && token.isNotEmpty) {
      await NotificationApi.registerDeviceToken(token);
    }
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('[WebNotificationService] token refresh: $newToken');
      // TODO: persist `newToken` to the backend.
      NotificationApi.registerDeviceToken(newToken);
    });

    // 3. Live messages. `onMessage` fires when the tab is focused; the SW
    //    handles the rest. `onMessageOpenedApp` is a no-op on web today,
    //    kept for native-API parity.
    //
    // `handleError` guards a known firebase_messaging_web bug: the JS SDK can
    // emit a payload the plugin fails to convert to a RemoteMessage
    // ("TypeError: map[$_get] is not a function"). Without this, that parse
    // failure surfaces as an uncaught zone error in the console.
    FirebaseMessaging.onMessage
        .handleError(
          (Object error, StackTrace stackTrace) => AppLog.e(
            '[WebNotificationService] onMessage parse failed (ignored): $error',
          ),
        )
        .listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

    // 4. Click bridge. SW-dispatched notifications don't fire
    //    `onMessageOpenedApp`; the SW posts a JSON envelope back here.
    listenForNotificationClicks(_handleNotificationClick);

    // 5. Cold-start. If the user clicked a notification while no tab was
    //    open, the SW encoded the payload in the URL — consume it here.
    final pending = consumePendingNotification();
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateFromNotification(pending);
      });
    }
  }

  /// FCM registration token for this browser. Requires [vapidKey].
  static Future<String?> getToken() async {
    if (!kIsWeb) return null;
    try {
      return await _messaging.getToken(vapidKey: vapidKey);
    } catch (e) {
      AppLog.e('[WebNotificationService] getToken failed: $e');
      return null;
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
      '[WebNotificationService] foreground: '
      'title=${message.notification?.title}, data=${message.data}',
    );
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    if (title == null || title.isEmpty) return;

    showBrowserNotification(
      title: title,
      body: notification?.body ?? message.data['body'] as String?,
      data: Map<String, dynamic>.from(message.data),
    );
  }

  static void _handleOpenedMessage(RemoteMessage message) {
    debugPrint('[WebNotificationService] opened (FCM): ${message.data}');
    _navigateFromNotification(message.data);
  }

  static void _handleNotificationClick(Map<String, dynamic> data) {
    debugPrint('[WebNotificationService] opened (SW click): $data');
    _navigateFromNotification(data);
  }

  /// Default destination on tap. Extend by reading `data['click_action']`
  /// once notification types are formalized.
  static void _navigateFromNotification(Map<String, dynamic> data) {
    // final context = rootNavigatorKey.currentContext;
    // if (context == null) {
    //   debugPrint('[WebNotificationService] no navigator context — skipping');
    //   return;
    // }
    // context.go(Routes.userDocuments);

    NotificationNavigator.handle(Map<String, dynamic>.from(map));
  }
}
