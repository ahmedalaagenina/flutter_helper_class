import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:idara_esign/config/routes/app_router.dart';
import 'package:idara_esign/core/notification_manager/notification_manager.dart';
import 'package:idara_esign/core/services/logger_service.dart';

class NotificationApi {
  static FirebaseMessaging messaging = FirebaseMessaging.instance;
  static bool _isInitialized = false;

  static Future<String?> getDeviceFCMToken() async {
    try {
      if (!await ensurePermission()) {
        AppLog.i('[NotificationApi] Notifications declined');
        return null;
      }

      if (Platform.isIOS && !await _waitForApnsToken()) {
        AppLog.w('[NotificationApi] No APNS token; skipping FCM registration');
        return null;
      }

      return await messaging.getToken();
    } on Object catch (error) {
      AppLog.w('[NotificationApi] Token unavailable — $error');
      return null;
    }
  }

  static Future<bool> _waitForApnsToken({
    Duration timeout = const Duration(seconds: 10),
    Duration interval = const Duration(milliseconds: 500),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      try {
        if (await messaging.getAPNSToken() != null) return true;
      } on Object {
        // Not ready yet. `getAPNSToken()` throws rather than returning null
        // before APNS answers, so this is the normal path for the first second
        // or two after launch — nothing to log.
      }
      await Future<void>.delayed(interval);
    }

    return false;
  }

  /// Whether the OS will let this app post notifications, asking if it has not
  /// been asked yet.
  ///
  /// ⛔ The single answer to that question — [getDeviceFCMToken] defers to it
  /// rather than deciding for itself. The two used to check separately and
  /// disagreed: one rejected only an outright denial, the other accepted only
  /// `authorized` or `provisional`. So on a not-yet-determined status the
  /// settings switch refused to move while login-time registration went ahead
  /// and minted a token anyway.
  ///
  /// Checked before switching push on, so a blocked permission can be reported
  /// plainly. Without it the switch reads "on", no token is ever minted, and
  /// nothing arrives — with nothing on screen to explain why.
  static Future<bool> ensurePermission() async {
    try {
      final settings = await _requestPermission();
      return switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => true,
        _ => false,
      };
    } on Object catch (error) {
      AppLog.w('[NotificationApi] Permission check failed — $error');
      return false;
    }
  }

  static Future<void> deleteToken() async {
    try {
      await messaging.deleteToken();
      AppLog.i('[NotificationApi] FCM token deleted');
    } on Object catch (error) {
      AppLog.w('[NotificationApi] Could not delete the FCM token — $error');
    }
  }

  static Stream<String> get onTokenRefresh {
    try {
      return messaging.onTokenRefresh;
    } on Object catch (error) {
      AppLog.w('[NotificationApi] Refresh stream unavailable — $error');
      return const Stream<String>.empty();
    }
  }

  /// How to use it?
  /// in main()
  // await NotificationApi.init();

  static Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    // Web has its own pipeline: no flutter_local_notifications, no Platform.is*,
    // and getToken needs a VAPID key. Delegate and bail out.
    if (kIsWeb) {
      await WebNotificationService.init();
      return;
    }

    // Enabling foreground notifications for Android
    // is Done in local Notification class
    // Enabling foreground notifications for IOS
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    NotificationHelper().initialize();

    /// this done by getDeviceFCMToken()
    // NotificationApi.requestPermission();

    NotificationApi.foregroundNotification();
    _registerForegroundActions();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Future.delayed(const Duration(milliseconds: 500), () async {
        await NotificationApi.setupInteractedMessage();
      });
    });
    // Enabling background Message
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    var token = await getDeviceToken();
    debugPrint("token: $token");
  }

  /// Register all foreground notification actions here.
  /// This is the best place because it runs once during notification setup.
  static void _registerForegroundActions() {
    final handler = ForegroundNotificationHandler.instance;

    // ── Refresh unread notification count ──────────────────────────────
    // Runs on EVERY notification → updates the badge counter in the app.
    handler.registerAction(
      ForegroundNotificationAction(
        id: 'refresh_unread_count',
        type: NotificationActionType.apiCall,
        execute: (message, context) async {
          if (context == null) return;
          try {
            context.read<NotificationsBloc>().add(
              const FetchUnreadCountEvent(),
            );
          } catch (_) {
            // Bloc not available in the tree yet — ignore.
          }
        },
      ),
    );
  }

  /// Prompts, if the OS has not already asked, and reports what it decided.
  ///
  /// Private: [ensurePermission] is the way in. Two public methods that both
  /// prompt, named "request" and "ensure", gave a caller no way to tell which
  /// one they wanted.
  static Future<NotificationSettings> _requestPermission() async {
    final settings = await messaging.requestPermission();

    // Logged whatever the answer. This used to skip the denied case, which is
    // the one worth having in a log — "notifications never arrive" is nearly
    // always this, and it left no trace.
    AppLog.i('[NotificationApi] Permission: ${settings.authorizationStatus}');
    return settings;
  }

  /// Handle background message only not notification
  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    debugPrint("Handling a background message: ${message.data}");
  }

  /// Handle foreground message and notification
  static void foregroundNotification() {
    // Provide the root context so in-app UI actions can show snackbars, etc.
    ForegroundNotificationHandler.instance.contextProvider = () =>
        rootNavigatorKey.currentContext;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      // Fan-out to all registered foreground actions (API calls, UI, etc.)
      ForegroundNotificationHandler.instance.handleMessage(message);

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      if (notification != null && android != null) {
        /// here handle ui of notification
        /// to get notification must use flutter_local_notifications

        debugPrint(
          'Message also contained a notification: ${message.notification?.toMap()}',
        );

        /// Interacted with UI in [(Foreground)] (when app is opened)
        /// in LocalNotificationApi.showNotification
        NotificationHelper().showNotification(message: message);
      }
    });
  }

  /// Interacted with UI in [(Background or Terminated)] (when app is Closed)
  static Future<void> setupInteractedMessage() async {
    // Get any messages which caused the application to open from
    // a [(Terminated)] state.
    messaging.getInitialMessage().then(_handleMessage);

    // Also handle any interaction when the app is in the [(Background)] via a
    // Stream listener
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  static void _handleMessage(RemoteMessage? message) {
    if (message == null) return;
    // It is assumed that all messages contain a data field with the key 'type'
    // If the message also contains a data property with a "type" of "chat",
    // navigate to a chat screen

    // if app in Background or Terminated that will work fine
    debugPrint("Opened Notification Data : ${message.data}");
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    NotificationNavigator.handle(Map<String, dynamic>.from(map));

    ///we can use normal navigatorKey.currentContext! to Do what we want
    // if (RouteConfigurations.parentNavigatorKey.currentState != null) {
    //   if (message.data[NotificationClickAction.clickAction] ==
    //       NotificationClickAction.newRequest) {
    //     RouteConfigurations.parentNavigatorKey.currentState!.context
    //         .pushNamed(AppRoutes.requestsScreen, extra: true);
    //   } else if (message.data[NotificationClickAction.clickAction] ==
    //       NotificationClickAction.orderUserAction) {
    //     RouteConfigurations.router
    //         .goNamed(AppRoutes.myOrderScreen, extra: true);
    //   } else if (message.data[NotificationClickAction.clickAction] ==
    //       NotificationClickAction.orderDashboardAction) {
    //     Map sendData = message.data[NotificationClickAction.sendData] as Map;
    //     RouteConfigurations.router.goNamed(
    //       AppRoutes.clothesItemScreen,
    //       pathParameters: {'id': sendData['id']},
    //     );
    //   }
    // }
  }
}
