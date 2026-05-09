// Service worker for Flutter Web Firebase Cloud Messaging.
// Companion code: lib/core/notification_manager/web/
//
// Bump SW_VERSION whenever you edit this file. Browsers cache service workers
// aggressively; a version change forces them to re-fetch on next page load.

importScripts(
  "https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js",
);
importScripts(
  "https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js",
);

// Keep this in sync with the `web` block in lib/firebase_options.dart.
firebase.initializeApp({
  apiKey: "AIzaSyC2qHMu8AeXNn2G-GM63jQeEPV1Kv1pIwE",
  appId: "1:738751313398:web:943944d69ca0fe2e4143d7",
  messagingSenderId: "738751313398",
  projectId: "idara-sign-e32e5",
  authDomain: "idara-sign-e32e5.firebaseapp.com",
  storageBucket: "idara-sign-e32e5.firebasestorage.app",
  measurementId: "G-5KGM0V7QE9",
});

const messaging = firebase.messaging();

// Background pushes (tab closed or hidden).
//
// Defining onBackgroundMessage disables FCM's auto-display, so we always
// render with showNotification ourselves. This handles both `notification`
// payloads and `data`-only payloads uniformly.
messaging.onBackgroundMessage((payload) => {
  console.log(`[fcm-sw] background:`, payload);

  const notification = payload.notification || {};
  const data = payload.data || {};
  const title = notification.title || data.title || "iDara Sign";

  self.registration.showNotification(title, {
    body: notification.body || data.body || "",
    icon: "icons/icon-192.png",
    badge: "icons/icon-192.png",
    requireInteraction: true,
    tag: `fcm-${Date.now()}`,
    // Stored on the notification; read back inside `notificationclick`.
    data,
  });
});

// Bridge notification clicks back to Dart.
//
// FCM's `onMessageOpenedApp` does NOT fire on web for notifications dispatched
// via `registration.showNotification` — we have to wire this up manually.
//
//  - Tab open  → postMessage the payload, then focus that tab.
//  - Tab closed → open one with `?nd=<json>` so Dart can pick the data up
//                 after load (see `consumePendingNotification` in
//                 lib/core/notification_manager/web/browser_notification_web.dart).
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const data = event.notification.data || {};

  event.waitUntil(
    (async () => {
      const windowClients = await clients.matchAll({
        type: "window",
        includeUncontrolled: true,
      });

      if (windowClients.length > 0) {
        const client = windowClients[0];
        // Stringify so Dart can `jsonDecode` without JS-interop conversion.
        client.postMessage(JSON.stringify({ type: "notificationclick", data }));
        if ("focus" in client) await client.focus();
        return;
      }

      if (clients.openWindow) {
        const encoded = encodeURIComponent(JSON.stringify(data));
        await clients.openWindow(`/?nd=${encoded}`);
      }
    })(),
  );
});

/// in index.html add this script tag
// <script>
//     // Register the Firebase Messaging service worker so background pushes
//     // are delivered when the tab is closed or in the background.
//     if ("serviceWorker" in navigator) {
//       window.addEventListener("load", function () {
//         navigator.serviceWorker
//           .register("firebase-messaging-sw.js")
//           .then(function (registration) {
//             console.log(
//               "FCM service worker registered:",
//               registration.scope,
//             );
//           })
//           .catch(function (err) {
//             console.error("FCM service worker registration failed:", err);
//           });
//       });
//     }
//   </script>
