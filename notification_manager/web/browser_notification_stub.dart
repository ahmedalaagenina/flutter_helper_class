// Non-web stub. Used when the app is compiled for native targets, where
// `dart:js_interop` and `package:web` don't apply. The web build replaces this
// file via the conditional import in `web_notification_service.dart`.

void showBrowserNotification({
  required String title,
  String? body,
  String? icon,
  Map<String, dynamic>? data,
}) {
  // no-op
}

void listenForNotificationClicks(
  void Function(Map<String, dynamic> data) onClick,
) {
  // no-op
}

Map<String, dynamic>? consumePendingNotification() => null;
