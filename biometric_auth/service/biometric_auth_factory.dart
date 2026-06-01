import 'biometric_auth_service.dart';
// Conditional import: the web file (WebAuthn / dart:js_interop) is only
// compiled for web targets, and the native file (local_auth) only for the
// rest. This keeps each platform's build free of the other's dependencies.
import 'biometric_auth_service_impl.dart'
    if (dart.library.js_interop) 'biometric_auth_web_impl.dart';

/// Creates the [BiometricAuthService] implementation for the current platform.
///
/// Register it once with your service locator, e.g. with GetIt:
/// ```dart
/// sl.registerLazySingleton<BiometricAuthService>(createBiometricAuthService);
/// ```
BiometricAuthService createBiometricAuthService() =>
    createPlatformBiometricAuthService();
