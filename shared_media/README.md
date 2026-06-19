# SharedMediaService

A small, **self-contained, strongly-typed** service that receives files handed to
your app through the OS **Share Sheet** ("Share with…") or **Open-with** action,
on **iOS and Android**, and exposes them as [`SharedFile`] objects.

It wraps [`share_handler`](https://pub.dev/packages/share_handler) and depends on
nothing else (no `file_picker`, no app-specific logging), so you can reuse it in
any app — new or old — by copying this folder and following the setup below.

```
lib/core/services/shared_media/
├── shared_media_service.dart   ← the service (copy this)
└── README.md                   ← this file
```

---

## 1. Dart API

```dart
// Model emitted for every accepted file.
class SharedFile {
  final String path;            // absolute path on disk
  final String name;            // "contract.pdf"
  final int    size;            // bytes
  final String fileExtension;   // "pdf" (lowercase, no dot, "" if unknown)
  final SharedFileType type;    // resolved category
  String get nameWithoutExtension; // "contract"
  File   get file;                 // File(path)
}

enum SharedFileType { pdf, image, doc, text, video, audio, other, any }

class SharedMediaService {
  SharedMediaService({Set<SharedFileType> acceptedTypes = const {SharedFileType.any}});

  Stream<SharedFile> get onFileReceived; // cold-start + warm-start
  SharedFile? get pendingFile;           // last accepted, not yet consumed
  void consumePendingFile();

  void init();                                // call once
  Future<bool> handleExternalUri(Uri uri);    // for file:// open-with (router hook)
  void dispose();
}
```

`acceptedTypes` filters incoming files **by extension**. Use `{SharedFileType.any}`
to accept everything, or e.g. `{SharedFileType.pdf}` to accept PDFs only. Add new
categories by extending the `SharedFileType` enum and `kSharedFileExtensions` map.

---

## 2. Usage

### Register (e.g. get_it)

```dart
getIt.registerLazySingleton<SharedMediaService>(
  () => SharedMediaService(acceptedTypes: {SharedFileType.pdf}),
);
```

### Wire into your root widget

```dart
late final SharedMediaService _shared;
StreamSubscription<SharedFile>? _sub;

@override
void initState() {
  super.initState();
  _shared = getIt<SharedMediaService>();
  _sub = _shared.onFileReceived.listen(_onFile);
  WidgetsBinding.instance.addPostFrameCallback((_) => _shared.init());
}

@override
void dispose() {
  _sub?.cancel();
  _shared.dispose();
  super.dispose();
}

void _onFile(SharedFile file) {
  // Navigate / upload / preview …
}
```

### Auth-gated flows (file shared before login)

When a file arrives but the user isn't authenticated, it stays in `pendingFile`.
Pick it up once the user logs in:

```dart
void _onAuthChanged(AuthState state) {
  if (state.isAuthenticated && _shared.pendingFile != null) {
    final file = _shared.pendingFile!;
    _navigate(file);
    _shared.consumePendingFile();
  }
}
```

### Interop with `file_picker`

The service is intentionally **not** coupled to `file_picker`. If your downstream
code expects a `PlatformFile`, convert at the boundary:

```dart
final platformFile = PlatformFile(path: file.path, name: file.name, size: file.size);
```

---

## 3. Dependency

```yaml
# pubspec.yaml
dependencies:
  share_handler: ^0.0.25
```

---

## 4. iOS setup

The app and a **Share Extension** target communicate through a shared **App
Group**. The extension writes the file into the group container and relaunches
the app via a custom `ShareMedia-<bundleId>://` URL; the plugin then reads it.

### 4.1 Create the Share Extension target
Xcode → *File ▸ New ▸ Target… ▸ Share Extension*. Set its **iOS Deployment
Target equal to the Runner's** (mismatched targets break the build).

### 4.2 `ShareViewController.swift` (in the extension)
```swift
import share_handler_ios_models

class ShareViewController: ShareHandlerIosViewController {}
```

### 4.3 Podfile (in `target 'Runner'`)
```ruby
target 'Share Extension' do          # ← must match your extension's target name
  inherit! :search_paths
  pod 'share_handler_ios_models',
    :path => '.symlinks/plugins/share_handler_ios/ios/Models'
end
```
Then `cd ios && pod install`.

### 4.4 App Group (both targets)
*Signing & Capabilities ▸ + App Groups* on **Runner** AND the **Share Extension**,
using the **same** id, e.g. `group.<your.bundle.id>.share`. This adds it to both
`.entitlements` files:
```xml
<key>com.apple.security.application-groups</key>
<array><string>group.net.idara.sign.share</string></array>
```

### 4.5 Info.plist — **both** Runner and Share Extension
```xml
<key>AppGroupId</key>
<string>group.net.idara.sign.share</string>   <!-- must equal the App Group id -->
```

### 4.6 Info.plist — Runner only
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key><string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array><string>ShareMedia-$(PRODUCT_BUNDLE_IDENTIFIER)</string></array>
  </dict>
</array>

<!-- Optional: also support "Open with <App>" for PDFs -->
<key>CFBundleDocumentTypes</key>
<array>
  <dict>
    <key>CFBundleTypeName</key><string>PDF Document</string>
    <key>CFBundleTypeRole</key><string>Viewer</string>
    <key>LSHandlerRank</key><string>Alternate</string>
    <key>LSItemContentTypes</key>
    <array><string>com.adobe.pdf</string></array>
  </dict>
</array>
```

### 4.7 Info.plist — Share Extension only (which files appear in the sheet)
```xml
<key>NSExtension</key>
<dict>
  <key>NSExtensionPointIdentifier</key><string>com.apple.share-services</string>
  <key>NSExtensionMainStoryboard</key><string>MainInterface</string>
  <key>NSExtensionAttributes</key>
  <dict>
    <key>NSExtensionActivationRule</key>
    <!-- Accept exactly one PDF. Widen this to accept more types. -->
    <string>SUBQUERY (extensionItems, $e, SUBQUERY ($e.attachments, $a, ANY $a.registeredTypeIdentifiers UTI-CONFORMS-TO "com.adobe.pdf").@count == 1).@count == 1</string>
  </dict>
</dict>
```

### 4.8 Build phase order
In the **Runner** target's *Build Phases*, drag **Embed Foundation Extension**
(or *Embed App Extensions*) **above** the *Thin Binary* phase.

---

## 5. Android setup

No Kotlin/Java changes. In `android/app/src/main/AndroidManifest.xml`, on your
`<activity>` add intent-filters for the types you accept:

```xml
<activity android:name=".MainActivity" android:launchMode="singleTop" ... >
  ...
  <!-- "Open with" (VIEW) -->
  <intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="application/pdf" />
  </intent-filter>

  <!-- "Share" (SEND) -->
  <intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="application/pdf" />
  </intent-filter>
</activity>
```

Permissions (for reading older shared files):
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
```

> `launchMode="singleTask"` is also fine and avoids stacking activities on repeat
> shares; `singleTop` works too.

---

## 6. Router / deep-link integration (important)

On modern Flutter (iOS Scene lifecycle), the `ShareMedia-<bundleId>://` relaunch
URL is also delivered to your router as a deep link. The shared file is delivered
through the plugin stream, **not** this URL, so a router like **go_router** must
**block** it — otherwise it throws `no routes for location` and the app gets stuck
on an error screen (which prevents the file from ever being handled).

```dart
// go_router onEnter guard
if (uri.scheme.toLowerCase().startsWith('sharemedia-')) {
  return const Block.stop();                 // plugin handles the file
}
// file:// / content:// "Open with" — block routing and forward to the service:
if (uri.scheme == 'file' || uri.scheme == 'content') {
  getIt<SharedMediaService>().handleExternalUri(uri);
  return const Block.stop();
}
```

Also set `overridePlatformDefaultLocation: true` (or equivalent) when the launch
URI is one of the above so the app boots to its normal initial route on cold
start. See `lib/config/routes/app_router.dart` in this project for a full example.

---

## 7. Reuse checklist (new app)

1. Copy `lib/core/services/shared_media/` into the new project.
2. `share_handler: ^0.0.25` in `pubspec.yaml` → `flutter pub get`.
3. iOS: Share Extension target + steps 4.2–4.8 → `pod install`.
4. Android: intent-filters (§5).
5. Register + wire the service (§2).
6. If you use a router with deep linking, add the guards (§6).

---

## 8. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `no routes for location: sharemedia-…` | Router not blocking the callback URL — add §6 guards. |
| App opens but file never arrives | App Group id mismatch between Runner & Extension, or `AppGroupId` missing from an Info.plist. Must match exactly. |
| App doesn't appear in the share sheet | `NSExtensionActivationRule` too strict, or extension not embedded (§4.8). |
| iOS build fails after adding the extension | Deployment targets differ, or Podfile `share_handler_ios_models` block missing / wrong target name. |
| File arrives twice | Don't both stream-handle *and* forward the same URI; only forward `file://`/`content://` via `handleExternalUri`, let `ShareMedia-*` go through the plugin stream. |
| Nothing on a hot restart replay | Expected — the service calls `resetInitialSharedMedia()` after consuming the cold-start file. |
