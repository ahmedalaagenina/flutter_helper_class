import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:idara_esign/config/routes/app_router.dart';
import 'package:idara_esign/core/notification_manager/notification_manager.dart';
import 'package:idara_esign/core/services/logger_service.dart';

class NotificationApi {
  static FirebaseMessaging messaging = FirebaseMessaging.instance;

  static Future<String?> getDeviceToken() async {
    try {
      if (kIsWeb) {
        return await WebNotificationService.getToken();
      }
      return await messaging.getToken();
    } catch (e) {
      AppLog.e('Error getting FCM token: $e');
    }
    return null;
  }

  /// How to use it?
  /// in main()
  // await NotificationApi.init();

  static Future<void> init() async {
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
    NotificationApi.requestPermission();
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

  static void requestPermission() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');
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
    ForegroundNotificationHandler.instance.contextProvider =
        () => rootNavigatorKey.currentContext;

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
