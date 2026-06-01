sealed class BiometricAuthResult {
  const BiometricAuthResult();
}

/// Authentication succeeded
final class BiometricAuthSuccess extends BiometricAuthResult {
  const BiometricAuthSuccess();
}

/// User dismissed or failed (wrong fingerprint, cancelled, etc.)
final class BiometricAuthFailed extends BiometricAuthResult {
  const BiometricAuthFailed();
}

/// Device/browser does not support biometric or device credential auth
final class BiometricAuthNotAvailable extends BiometricAuthResult {
  const BiometricAuthNotAvailable();
}

/// Unexpected error occurred
final class BiometricAuthError extends BiometricAuthResult {
  final String message;
  const BiometricAuthError(this.message);
}
