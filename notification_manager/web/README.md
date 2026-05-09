# Notification Manager — Web

Firebase Cloud Messaging pipeline for the Flutter Web build of iDara Sign.
Native (Android / iOS) handling lives in the parent folder
(`notification_helper.dart`) and is unchanged.

`NotificationApi.init()` early-returns to `WebNotificationService.init()` when
`kIsWeb` is true, so the native path never touches `dart:io` or
`flutter_local_notifications` in the browser.

---

## Stack

| Layer | Technology | Why |
|---|---|---|
| FCM client (Dart) | `firebase_messaging` | Token, permission, `onMessage` stream. |
| DOM / Notification API (Dart) | `package:web` + `dart:js_interop` | Modern, type-safe JS interop. Replaces legacy `dart:html`. |
| Service worker (JS) | `firebase-messaging-sw.js` (classic, `importScripts`) | Receives background pushes, displays notifications, bridges click events back to Dart. |
| Click bridge | `postMessage` of a `JSON.stringify`'d envelope | Avoids cross-realm structured-clone surprises; Dart parses with plain `jsonDecode`. |
| Cold-start fallback | `?nd=<json>` URL parameter | When no tab is open, the SW opens one with the payload in the query string; Dart consumes and clears it on init. |

---

## Layout

```
notification_manager/
├── notification_manager.dart          ← barrel; always import this
├── notification_api.dart              ← entry. Branches on kIsWeb.
├── notification_helper.dart           ← Android/iOS path (flutter_local_notifications)
├── notification_click_action.dart     ← shared `data`-payload constants
└── web/
    ├── README.md                      ← you are here
    ├── web_notification_service.dart  ← FCM init, VAPID token, message + click handlers
    ├── browser_notification_stub.dart ← no-op used on native builds
    └── browser_notification_web.dart  ← package:web → SW.showNotification + URL bridge
```

And next to your Flutter project root, **outside** this folder:

```
<project>/
├── web/
│   ├── index.html                     ← registers the SW on window.load
│   └── firebase-messaging-sw.js       ← service worker (covered below)
└── lib/firebase_options.dart          ← Firebase web config (sync with the SW)
```

---

## Setup (one-time)

### 1. Service worker file
`<project>/web/firebase-messaging-sw.js` already ships with the project's
Firebase config. **If you switch Firebase projects, sync this file with the
`web` block in `lib/firebase_options.dart`.** It must live at the web root so
the browser can load it from `/firebase-messaging-sw.js`.

### 2. VAPID key
1. Firebase Console → **Project Settings** → **Cloud Messaging**.
2. Scroll to **Web configuration** → **Web Push certificates**.
3. **Generate key pair** (or copy the existing one).
4. Paste into `web_notification_service.dart`:

   ```dart
   static const String vapidKey = '<paste here>';
   ```
   Without it, `getToken()` throws on web and FCM can't target this browser.

### 3. Service worker registration
Already wired in `<project>/web/index.html` — a small inline script registers
`firebase-messaging-sw.js` on `window.load`. Nothing to change unless you
relocate the SW.

### 4. Test
1. `flutter run -d chrome`
2. Accept the browser permission prompt.
3. Copy the FCM token from the console:
   `[WebNotificationService] FCM token: …`
4. Send a test push from Firebase Console → **Cloud Messaging**, targeting the token.
5. Verify all three flows:
   - **Foreground** (tab focused) → toast appears via in-page SW dispatch.
   - **Background** (tab hidden) → toast appears via SW's `onBackgroundMessage`.
   - **Cold-start** (tab closed) → tap → tab opens, navigates from payload.

---

## Files explained

### `firebase-messaging-sw.js` (project's `web/` folder)

The classic service worker — pure JavaScript, no Dart involvement. Three
distinct responsibilities:

```js
// 1. Initialize Firebase JS SDK inside the SW context.
firebase.initializeApp({ /* same config as firebase_options.dart web */ });
const messaging = firebase.messaging();
```

```js
// 2. Background message handler.
//
// Defining onBackgroundMessage disables FCM's auto-display; we render
// every payload through showNotification so behavior is uniform across
// `notification`, `data`, and mixed payloads.
messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const data = payload.data || {};
  const title = notification.title || data.title || "iDara Sign";
  self.registration.showNotification(title, {
    body: notification.body || data.body || "",
    icon: "icons/icon-192.png",
    badge: "icons/icon-192.png",
    requireInteraction: true,
    tag: `fcm-${Date.now()}`,
    data, // stored on the notification, read in notificationclick
  });
});
```

```js
// 3. Click handler — bridge clicks back to Dart.
//
// Tab open  → JSON-stringify the payload and postMessage to the focused tab.
// Tab closed → open a new tab with `?nd=<json>` so Dart can pick it up
//              after load (consumePendingNotification).
self.addEventListener("notificationclick", (event) => { /* … */ });
```

`SW_VERSION` at the top exists purely as a cache-buster: bump it whenever
you edit the SW so browsers re-fetch the file on next load (also clear the
SW in DevTools → Application → Service Workers → **Unregister** during
development).

### `web_notification_service.dart`

The orchestrator. `init()` does five things, in order:

| # | Step | Notes |
|---|---|---|
| 1 | `requestPermission` | On web this also grants browser-level Notification permission. |
| 2 | `getToken(vapidKey: ...)` + `onTokenRefresh` listener | Tokens rotate (browser data clear, long inactivity) — the refresh stream keeps the backend in sync. |
| 3 | `onMessage` + `onMessageOpenedApp` listeners | Foreground messages go to `_handleForegroundMessage`; `onMessageOpenedApp` is a no-op on web today but kept for native-API parity. |
| 4 | `listenForNotificationClicks` | Subscribes to the SW's postMessage bridge. SW-dispatched notifications **don't** fire FCM's `onMessageOpenedApp`. |
| 5 | `consumePendingNotification` | Cold-start path: read and clear `?nd=<json>` from the URL. Navigation is deferred to the next frame so the navigator is mounted. |

Two safety nets:

- **`_initialized` guard** — `init()` is idempotent; calling it again from a
  re-mount is a no-op.
- **Permission gating** — if the user denies, we log and bail out instead of
  setting up listeners that will never fire.

The fallback navigation `_navigateFromNotification` always goes to
`Routes.userDocuments`. Extend it by inspecting `data['click_action']` once
notification types are formalized — that's the natural extension point.

### `browser_notification_web.dart` (web build only)

Three exports, all using `package:web` + `dart:js_interop`:

- **`showBrowserNotification`** — public entry. Permission-checks then calls
  the private async `_show`, which awaits `serviceWorker.ready`,
  constructs a typed `web.NotificationOptions`, and calls
  `registration.showNotification(...)`.
- **`listenForNotificationClicks`** — sets `serviceWorker.onmessage`. The
  callback ignores anything not matching the `{type:"notificationclick"}`
  envelope, decodes the inner data, and forwards it.
- **`consumePendingNotification`** — reads `?nd=<json>` from
  `window.location.search`, parses it, then `replaceState`-s the URL to
  remove `nd` so a refresh doesn't replay the click.

Why `package:web` over `dart:html`:

- `dart:html` is being phased out in Dart 3.x.
- `package:web` is generated from current web IDL — typed
  `NotificationOptions`, no untyped `Map<String, dynamic>` to the JS layer.
- Pairs with `dart:js_interop` (`.toJS`, `.toDart`, `.jsify()`,
  `.isA<JSString>()`) which is the canonical Dart 3 interop API.

### `browser_notification_stub.dart` (native build only)

Three no-op functions matching the web file's signatures. This is what gets
compiled into Android/iOS/macOS/Windows/Linux builds and exists for one
reason only: to keep the conditional import resolvable.

---

## The conditional-import pattern (and why the stub matters)

Top of `web_notification_service.dart`:

```dart
import 'browser_notification_stub.dart'
    if (dart.library.js_interop) 'browser_notification_web.dart';
```

Translation:
> *"Import the stub. If `dart.library.js_interop` is available
> (i.e., this is a Flutter Web build), import the web file instead."*

`dart:js_interop` is a web-only SDK library. On native, the sentinel is
false and the stub wins; on web, it's true and the real implementation wins.
**Only one of the two files exists in any given binary** — it's a
compile-time switch, not a runtime fallback.

### Why the stub is *not* redundant with `kIsWeb`

A common question: *"We already have `if (!kIsWeb) return;` — isn't the stub
extra?"* No, they protect against different things:

| | What it does | When it runs |
|---|---|---|
| `if (kIsWeb) return;` | runtime guard | when the app is running |
| Conditional import | compile-time switch | during `flutter build` |

The compiler reads imports **before** any `kIsWeb` check ever runs. If
`web_notification_service.dart` imported `package:web` directly, the
Android/iOS builds would fail to compile:

```
Error: Library 'dart:js_interop' is not available on this platform.
```

`kIsWeb` is just a boolean — it can't prevent something from being compiled.

---

## Why SW dispatch (not `new Notification(...)`)

Foreground notifications go through `serviceWorker.ready` →
`registration.showNotification(...)` instead of the page-level
`new Notification(...)` constructor. Two reasons:

1. **Reliability.** Page-level `Notification` is silently dropped on macOS
   Chrome and unsupported on Android Chrome. SW-dispatched notifications
   work on every desktop and Android browser that supports FCM.
2. **Consistency.** Background pushes already render through the SW
   (`firebase-messaging-sw.js` → `self.registration.showNotification`).
   Using the same path for foreground means the toast looks identical
   regardless of whether the tab was focused.

`requireInteraction: true` keeps the toast on screen until dismissed —
easier to spot when macOS Focus is on or the OS auto-hides banners.

---

## Click handling: SW → Dart bridge

Notifications dispatched via `registration.showNotification(...)` are **not
tracked by FCM**, so `FirebaseMessaging.onMessageOpenedApp` never fires for
them. The bridge:

1. SW's `notificationclick` handler reads the `data` stored on the
   notification.
2. **Tab open** → `JSON.stringify({type, data})` and `postMessage` it to
   the focused client; `client.focus()` brings the tab forward.
3. **Tab closed** → `clients.openWindow("/?nd=" + encodeURIComponent(json))`
   opens a fresh tab with the payload in the query string.
4. On the Dart side:
   - `listenForNotificationClicks` handles the warm-tab case via
     `serviceWorker.onmessage`.
   - `consumePendingNotification` handles the cold-start case via the
     URL query, then strips `?nd=` from history so a refresh doesn't replay
     the click.

We stringify on the JS side rather than passing a JS object directly
because the Dart side can then use plain `jsonDecode` — no JS-interop
boundary on the read path, no fragile `dartify` conversion.

### Cold-start gotcha

`consumePendingNotification` runs in `WebNotificationService.init()`, which
is invoked from `UserDashboardPage.initState`. If your router strips query
params during pre-dashboard navigation (login, redirects, …), the `nd`
parameter may not survive. For maximum reliability, capture the URL in
`main()` before `runApp()`. The current implementation works for the typical
flow where the user is already authenticated when they cold-start the tab.

---

## Sending pushes that actually display on web

The SW's `onBackgroundMessage` always renders, so any payload works as long
as it has a title somewhere. Examples (FCM v1 HTTP API):

```json
// Standard notification + click action
{
  "message": {
    "token": "<web-fcm-token>",
    "notification": { "title": "Document signed", "body": "Tap to view." },
    "data": { "click_action": "open_documents", "doc_id": "42" }
  }
}
```

```json
// Data-only payload — title/body fall back to data fields
{
  "message": {
    "token": "<web-fcm-token>",
    "data": { "title": "New comment", "body": "Ali replied to you", "doc_id": "42" }
  }
}
```

The `data` map is what surfaces to `_navigateFromNotification` after a tap.

---

## Gotchas

- **`localhost` works, `file://` doesn't.** Service workers require
  `https://` or `http://localhost`.
- **VAPID is a public key** — safe to commit. The private half stays in
  Firebase.
- **`flutter_local_notifications` has no web implementation.** Don't call
  `NotificationHelper().showNotification(...)` from web code paths.
- **Icon path** is `icons/icon-192.png`, relative to the web root. If you
  rename the file, update both `firebase-messaging-sw.js` and the
  `NotificationOptions` in `browser_notification_web.dart`.
- **Service workers cache aggressively.** After editing the SW, bump
  `SW_VERSION` and hard-reload (DevTools → Application → Service Workers →
  **Unregister**, then refresh).
- **macOS notifications.** If the SW dispatch succeeds but no toast appears,
  check System Settings → Notifications → Google Chrome (allow
  notifications, banner/alert style). Focus mode silently suppresses them
  too.
- **Token rotation.** Tokens can change. Always send the latest one to your
  backend — wire `onTokenRefresh` to your backend sync, the listener is
  already set up.
- **Re-init.** `init()` is idempotent (`_initialized` flag), so calling it
  from `initState` of a re-mounted widget won't double-subscribe.

---

## Extension points

The code is intentionally minimal. Common things to add later:

| Want | Where to add it |
|---|---|
| Persist token to your backend | `onTokenRefresh` handler in `init()` (and the initial `getToken` call). |
| Route based on `data['click_action']` | `_navigateFromNotification` — switch on the action key. |
| In-app banner / toast for foreground | `_handleForegroundMessage` — invoke a snackbar via `rootNavigatorKey.currentContext` instead of (or in addition to) the system notification. |
| Custom icon per notification | Pass `icon` through `showBrowserNotification` from `_handleForegroundMessage` (e.g., `message.notification?.imageUrl`). |
| Robust cold-start | Move `consumePendingNotification` out of `init()` and into `main()` before `runApp` — captures the URL before the router can strip it. |
| Auto-sync SW config with `firebase_options.dart` | A pre-build script that templates `firebase-messaging-sw.js` from the Dart constants. Worth it if you switch Firebase projects often. |
