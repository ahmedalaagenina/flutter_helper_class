/// Reusable, cross-platform local authentication (biometrics + device
/// credential) for any Flutter app.
///
/// Import this single barrel to get the public API. Platform implementations
/// are wired automatically by [createBiometricAuthService] via conditional
/// import, so they are intentionally **not** exported here — that prevents the
/// native (`local_auth`) and web (`dart:js_interop`) code from leaking into the
/// wrong build.
library;

export 'biometric_auth_factory.dart';
export 'biometric_auth_result.dart';
export 'biometric_auth_service.dart';
