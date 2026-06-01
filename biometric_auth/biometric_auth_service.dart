import 'biometric_auth_result.dart';

abstract class BiometricAuthService {
  /// Returns true if the device/browser supports biometric or device credential auth.
  Future<bool> isAvailable();

  /// Returns true if biometrics (fingerprint, face, etc.) are enrolled.
  /// On web, same as isAvailable().
  Future<bool> hasBiometrics();

  /// Prompts the user for biometric or device credential (PIN/password/pattern).
  /// If not available, silently returns [BiometricAuthNotAvailable].
  Future<BiometricAuthResult> authenticate({required String localizedReason});
}
