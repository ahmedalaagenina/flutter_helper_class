import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:idara_esign/config/routes/app_router.dart';
import 'package:idara_esign/config/routes/route_names.dart';
import 'package:idara_esign/core/services/logger_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
// NOTE: Import the following packages for platform-specific implementations
// NOTE: This Will replacement for LocalNotificationApi But Wait For The Nxt Use Of It
// NOTE: for More Details of use this package see https://github.com/MaikuB/flutter_local_notifications/blob/master/flutter_local_notifications/example/lib/main.dart#L347

/// A comprehensive helper class to handle local notifications in Flutter applications.
/// This class provides methods to initialize, schedule, and manage notifications across
/// different platforms (Android, iOS, macOS, and Linux).
class NotificationHelper {
  static final NotificationHelper _instance = NotificationHelper._internal();
  factory NotificationHelper() => _instance;
  NotificationHelper._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Android notification channel details
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );
  Future<void> _configureLocalTimeZone() async {
    if (kIsWeb || Platform.isLinux) {
      return;
    }
    tz.initializeTimeZones();
    if (Platform.isWindows) {
      return;
    }
    final TimezoneInfo tzInfo = await FlutterTimezone.getLocalTimezone();
    final String tzName = tzInfo.identifier;

    try {
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (e) {
      debugPrint('Timezone not found: $tzName, falling back to UTC. Error: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  /// Initialize notification settings for all platforms
  Future<void> initialize() async {
    // Initialize timezone
    await _configureLocalTimeZone();
    // Platform-specific initialization settings
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: androidInitializationSettings,
          iOS: iosSettings,
          macOS: iosSettings,
          linux: linuxSettings,
        );

    // Create high importance channel for Android
    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
    }
    await requestPermissions();
    final notificationAppLaunchDetails = await flutterLocalNotificationsPlugin
        .getNotificationAppLaunchDetails();

    if (notificationAppLaunchDetails != null &&
        notificationAppLaunchDetails.didNotificationLaunchApp) {
      onTapNotification(notificationAppLaunchDetails.notificationResponse!);
    }
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,

      /// on did receive notification response
      /// == for when app is opened via notification while in foreground on android
      onDidReceiveNotificationResponse: onTapNotification,
    );
  }

  /// Request notification permissions
  Future<void> requestPermissions() async {
    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else if (Platform.isMacOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Show an immediate notification
  Future<void> showNotification({required RemoteMessage message}) async {
    var notificationDetails = await _notificationDetails(message);
    flutterLocalNotificationsPlugin.show(
      id: message.notification!.hashCode,
      title: message.notification!.title,
      body: message.notification!.body,
      notificationDetails: notificationDetails,
      payload: jsonEncode(
        message.data,
      ), // value that pass from notification to app
    );
  }

  /// Schedule a notification for a specific date and time
  Future<void> scheduleNotification({
    required RemoteMessage message,
    required DateTime scheduledDate,
  }) async {
    var notificationDetails = await _notificationDetails(message);
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: message.notification!.hashCode,
      title: message.notification!.title,
      body: message.notification!.body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: jsonEncode(message.data),
    );
  }

  /// Show a notification with progress
  Future<void> showProgressNotification({
    required int id,
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.low,
          priority: Priority.low,
          showProgress: true,
          maxProgress: maxProgress,
          progress: progress,
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  /// Show a notification with a custom sound
  Future<void> showNotificationWithCustomSound({
    required int id,
    required String title,
    required String body,
    required String soundFile, // e.g., 'notification_sound.wav'
  }) async {
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound(
        soundFile.split('.').first,
      ), // Remove file extension
    );

    DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      sound: soundFile,
    );

    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  /// Show a grouped notification (Android only)
  Future<void> showGroupedNotifications({
    required String groupKey,
    required List<NotificationInfo> notifications,
  }) async {
    // Show individual notifications
    for (var i = 0; i < notifications.length; i++) {
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
            groupKey: groupKey,
          );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        id: i,
        title: notifications[i].title,
        body: notifications[i].body,
        notificationDetails: notificationDetails,
      );
    }

    // Show summary notification
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          groupKey: groupKey,
          setAsGroupSummary: true,
        );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      id: notifications.length,
      title: 'Group notification',
      body: '${notifications.length} messages',
      notificationDetails: notificationDetails,
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await androidImplementation?.areNotificationsEnabled() ?? false;
    } else if (Platform.isIOS) {
      final iosImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await iosImplementation?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  /// Get pending notification requests
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  /// Get active notifications (Android only)
  Future<List<ActiveNotification>> getActiveNotifications() async {
    if (Platform.isAndroid) {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await androidImplementation?.getActiveNotifications() ?? [];
    }
    return [];
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(
    NotificationResponse notificationResponse,
  ) {
    // handle actions
    debugPrint(
      "onDidReceiveBackgroundNotificationResponse: ${notificationResponse.payload}",
    );
  }

  static Future<Uint8List> _getByteArrayFromUrl(String url) async {
    final http.Response response = await http.get(Uri.parse(url));
    return response.bodyBytes;
  }

  // Helper method to get byte array from asset
  static Future<Uint8List> _getByteArrayFromAsset(String assetPath) async {
    final ByteData byteData = await rootBundle.load(assetPath);
    return byteData.buffer.asUint8List();
  }

  // Helper method for notification details
  static Future<NotificationDetails> _notificationDetails(
    RemoteMessage message,
  ) async {
    final ByteArrayAndroidBitmap? bigPicture =
        message.notification?.android?.imageUrl == null
        ? null
        : ByteArrayAndroidBitmap(
            await _getByteArrayFromUrl(
              message.notification!.android!.imageUrl!,
            ),
          );

    final BigPictureStyleInformation? bigPictureStyleInformation =
        bigPicture == null
        ? null
        : BigPictureStyleInformation(bigPicture, largeIcon: bigPicture);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _channel.id, // channel id
          _channel.name, // channel name
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: bigPictureStyleInformation,
        );
    // Configure iOS/macOS-specific notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );
  }

  /// when tap in notification to open specific screen or anything
  void onTapNotification(NotificationResponse details) {
    debugPrint("onDidReceiveNotificationResponse: ${details.payload}");
    var map = convertPayloadToMap(details.payload!);
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    context.go(Routes.userDocuments);

    ///key.currentContext!
    // if (RouteConfigurations.parentNavigatorKey.currentState != null) {
    //   Map? sendData = map[NotificationClickAction.sendData] as Map?;
    //   if (map[NotificationClickAction.clickAction] ==
    //       NotificationClickAction.newRequest) {
    //     RouteConfigurations.parentNavigatorKey.currentState!.context.pushNamed(
    //       AppRoutes.requestsScreen,
    //       extra: true,
    //     );
    //   } else if (map[NotificationClickAction.clickAction] ==
    //       NotificationClickAction.orderUserAction) {
    //     RouteConfigurations.router.goNamed(
    //       AppRoutes.myOrderScreen,
    //       extra: true,
    //     );
    //   } else if (map[NotificationClickAction.clickAction] ==
    //       NotificationClickAction.orderDashboardAction) {
    //     RouteConfigurations.router.goNamed(
    //       AppRoutes.clothesItemScreen,
    //       pathParameters: {'id': sendData!['id']},
    //       extra: true,
    //     );
    //   }
    // }
  }

  static Map convertPayloadToMap(String payload) {
    final String nPayload = payload.substring(1, payload.length - 1);
    List<String> split = [];
    nPayload.split(",").forEach((String s) => split.addAll(s.split(":")));
    Map mapped = {};
    for (int i = 0; i < split.length + 1; i++) {
      if (i % 2 == 1) {
        mapped.addAll({split[i - 1].trim().toString(): split[i].trim()});
      }
    }
    return mapped;
  }

  /// Parse nested payloads from notifications (new way)
  Map<String, dynamic> parseNestedPayload(String? payload) {
    if (payload == null || payload.isEmpty) return {};

    try {
      var decoded = jsonDecode(payload);
      return _processNestedMap(decoded);
    } catch (e) {
      AppLog.e('Error parsing nested payload: $e');
      return {};
    }
  }

  Map<String, dynamic> _processNestedMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      Map<String, dynamic> result = {};

      data.forEach((key, value) {
        if (value is Map) {
          // Recursively process nested maps
          result[key] = _processNestedMap(value);
        } else if (value is List) {
          // Handle lists that might contain maps
          result[key] = _processNestedList(value);
        } else {
          result[key] = value;
        }
      });

      return result;
    }
    return data is Map ? Map<String, dynamic>.from(data) : {'data': data};
  }

  List<dynamic> _processNestedList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map) {
        return _processNestedMap(item);
      } else if (item is List) {
        return _processNestedList(item);
      }
      return item;
    }).toList();
  }
}

/// Helper class to store notification information
class NotificationInfo {
  final String title;
  final String body;
  final String? payload;

  NotificationInfo({required this.title, required this.body, this.payload});
}
