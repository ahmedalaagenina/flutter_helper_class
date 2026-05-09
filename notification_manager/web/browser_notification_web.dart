// Loaded only on web via the conditional import in `web_notification_service.dart`.
// Native builds get `browser_notification_stub.dart`.
//
// Modern stack: package:web + dart:js_interop. Replaces the legacy dart:html
// pair, which is being phased out in Dart 3.x.
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Display a notification while the tab is in the foreground.
///
/// Goes through `ServiceWorkerRegistration.showNotification` (the same path
/// background pushes use) because page-level `new Notification(...)` is
/// silently dropped on macOS Chrome and unsupported on Android.
///
/// [data] is attached to the notification so the SW's `notificationclick`
/// handler can surface it back to Dart (see `firebase-messaging-sw.js`).
void showBrowserNotification({
  required String title,
  String? body,
  String? icon,
  Map<String, dynamic>? data,
}) {
  if (web.Notification.permission != 'granted') {
    debugPrint('[browser_notification] permission not granted');
    return;
  }
  // Fire-and-forget; the underlying API is async but callers don't await.
  _show(title: title, body: body, icon: icon, data: data);
}

Future<void> _show({
  required String title,
  String? body,
  String? icon,
  Map<String, dynamic>? data,
}) async {
  try {
    final registration = await web.window.navigator.serviceWorker.ready.toDart;
    debugPrint('[browser_notification] showing: $title');
    await registration
        .showNotification(
          title,
          web.NotificationOptions(
            body: body ?? '',
            icon: icon ?? 'icons/icon-192.png',
            badge: 'icons/icon-192.png',
            // Keeps the toast on screen until dismissed.
            requireInteraction: true,
            // Unique tag so consecutive notifications stack instead of replacing.
            tag: '${DateTime.now().microsecondsSinceEpoch}',
            data: (data ?? const <String, dynamic>{}).jsify(),
          ),
        )
        .toDart;
  } catch (e) {
    debugPrint('[browser_notification] showNotification failed: $e');
  }
}

/// Subscribe to clicks on notifications dispatched via the service worker.
///
/// The SW's `notificationclick` handler `JSON.stringify`s `{type, data}` and
/// posts it to the focused client; we decode and forward to [onClick].
/// Stringifying avoids cross-realm structured-clone surprises when reading
/// the envelope back into Dart.
void listenForNotificationClicks(
  void Function(Map<String, dynamic> data) onClick,
) {
  web.window.navigator.serviceWorker.onmessage =
      ((web.MessageEvent event) {
        final raw = event.data;
        if (raw == null || !raw.isA<JSString>()) return;

        final envelopeJson = (raw as JSString).toDart;

        Map<String, dynamic> envelope;
        try {
          final decoded = jsonDecode(envelopeJson);
          if (decoded is! Map) return;
          envelope = Map<String, dynamic>.from(decoded);
        } catch (_) {
          return;
        }

        if (envelope['type'] != 'notificationclick') return;

        final payload = envelope['data'];
        final data = payload is Map
            ? Map<String, dynamic>.from(payload)
            : <String, dynamic>{};
        debugPrint('[browser_notification] click received: $data');
        onClick(data);
      }).toJS;
}

/// On cold start, the SW may have appended notification data to the URL via
/// `?nd=<json>` because there was no tab to receive a postMessage.
///
/// Reads the payload (if any), strips `nd` from the URL so a refresh doesn't
/// replay the click, and returns the parsed data.
Map<String, dynamic>? consumePendingNotification() {
  final search = web.window.location.search;
  if (search.isEmpty || !search.contains('nd=')) return null;

  final query = search.startsWith('?') ? search.substring(1) : search;
  final params = Uri.splitQueryString(query);
  final encoded = params['nd'];
  if (encoded == null || encoded.isEmpty) return null;

  Map<String, dynamic>? data;
  try {
    final decoded = jsonDecode(encoded);
    if (decoded is Map) {
      data = Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    return null;
  }

  // Rebuild the URL without `nd` and replace the history entry so the user
  // can refresh without re-triggering the notification click.
  final remaining = Map<String, String>.from(params)..remove('nd');
  final pathname = web.window.location.pathname;
  final hash = web.window.location.hash;
  final newSearch = remaining.isEmpty
      ? ''
      : '?${remaining.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
  web.window.history.replaceState(
    null.jsify(),
    '',
    '$pathname$newSearch$hash',
  );

  debugPrint('[browser_notification] consumed cold-start payload: $data');
  return data;
}
