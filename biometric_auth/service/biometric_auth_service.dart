import 'biometric_auth_result.dart';

/// Platform-agnostic local authentication (biometrics + device credential).
///
/// This abstraction never leaks platform plugin types, so it can be dropped
/// into any Flutter app and mocked easily in tests. Obtain an instance for the
/// current platform via `createBiometricAuthService()`
/// (see `biometric_auth_factory.dart`).
abstract interface class BiometricAuthService {
  /// Whether the device is *capable* of local authentication — i.e. it has the
  /// hardware/OS support and a secure lock screen that can act as a fallback.
  ///
  /// This does **not** guarantee a biometric is enrolled; use
  /// [hasEnrolledBiometrics] for that. Never throws — returns `false` on error.
  Future<bool> isSupported();

  /// Whether at least one biometric (fingerprint, face, iris, …) is enrolled.
  ///
  /// Use this to decide whether to show a "Face ID / fingerprint" affordance.
  /// Never throws — returns `false` on error.
  Future<bool> hasEnrolledBiometrics();

  /// Prompts the user to authenticate and resolves to a typed
  /// [BiometricAuthResult]. Never throws — all failures map to a result case.
  ///
  /// [localizedReason] is the (already localized) sentence shown to the user,
  /// e.g. "Authenticate to sign the document". Must not be empty.
  ///
  /// When [biometricOnly] is `true`, the device credential (PIN/passcode/
  /// pattern) fallback is disabled and only biometrics are accepted. Defaults
  /// to `false` so users without enrolled biometrics can still proceed.
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
  });
}
