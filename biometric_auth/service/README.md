# biometric_auth

Reusable, cross-platform local authentication (biometrics + device credential)
for Flutter. Drop this folder into any app — it has **no app-specific
dependencies**.

- **Android / iOS / macOS / Windows** → `local_auth`
- **Web** → WebAuthn via `package:web` (self-contained, no `index.html` edits)

## API

```dart
import 'core/biometric_auth/biometric_auth.dart';

final BiometricAuthService auth = createBiometricAuthService();

await auth.isSupported();           // device can do local auth at all
await auth.hasEnrolledBiometrics(); // a fingerprint/face is enrolled

final result = await auth.authenticate(
  localizedReason: 'Authenticate to continue', // already localized, non-empty
  biometricOnly: false, // false → allow PIN/passcode fallback (recommended)
);

switch (result) {
  case BiometricAuthSuccess():      // ✅ proceed
  case BiometricAuthCanceled():     // user dismissed
  case BiometricAuthFailed():       // wrong biometric, can retry
  case BiometricAuthLockedOut():    // too many attempts
  case BiometricAuthUnavailable():  // no hardware / nothing enrolled / no web support
  case BiometricAuthError(:final message): // unexpected platform error
}
```

`authenticate` **never throws** — every failure maps to a result case.

Register once with your service locator:

```dart
getIt.registerLazySingleton<BiometricAuthService>(createBiometricAuthService);
```

## Files

| File | Purpose |
| --- | --- |
| `biometric_auth.dart` | Public barrel — import this. |
| `biometric_auth_service.dart` | `BiometricAuthService` interface. |
| `biometric_auth_result.dart` | Sealed `BiometricAuthResult` hierarchy. |
| `biometric_auth_factory.dart` | `createBiometricAuthService()` + conditional import. |
| `biometric_auth_service_impl.dart` | Native impl (`local_auth`). |
| `biometric_auth_web_impl.dart` | Web impl (WebAuthn). |

The factory uses a conditional import so the native build never pulls in
`dart:js_interop` and the web build never pulls in `local_auth`.

## Per-platform setup

**Dependencies** (`pubspec.yaml`): `local_auth`, `web`.

**Android**
- `MainActivity` must extend `FlutterFragmentActivity` (not `FlutterActivity`).
- `AndroidManifest.xml`: `<uses-permission android:name="android.permission.USE_BIOMETRIC"/>`

**iOS** (`Info.plist`)
```xml
<key>NSFaceIDUsageDescription</key>
<string>Face ID is used to verify your identity.</string>
```

**Web**
- Served over HTTPS or `localhost` (WebAuthn requires a secure context).
- No `index.html` changes are required.

## Web caveat

The web implementation proves **user presence on this device** (it triggers the
platform authenticator and checks the local user-verification passed). It is
*not* a cryptographic identity assertion — that needs a server-issued challenge
and a registered credential. If you add a backend WebAuthn flow later, replace
`BiometricAuthWebImpl` behind the `BiometricAuthService` interface without
touching any call sites.
