/// The outcome of a [BiometricAuthService.authenticate] call.
///
/// This is a closed [sealed] hierarchy, so callers can exhaustively handle
/// every case with a `switch` and the compiler will flag any missed branch:
///
/// ```dart
/// switch (result) {
///   case BiometricAuthSuccess():       proceed();
///   case BiometricAuthCanceled():      // user dismissed the prompt
///   case BiometricAuthFailed():        // wrong biometric, can retry
///   case BiometricAuthLockedOut():     // too many attempts
///   case BiometricAuthUnavailable():   // no hardware / nothing enrolled
///   case BiometricAuthError(:final message): showError(message);
/// }
/// ```
sealed class BiometricAuthResult {
  const BiometricAuthResult();

  /// Convenience flag for the common "did it pass?" check.
  bool get isSuccess => this is BiometricAuthSuccess;
}

/// The user successfully authenticated (biometric or device credential).
final class BiometricAuthSuccess extends BiometricAuthResult {
  const BiometricAuthSuccess();
}

/// The user actively dismissed the prompt or it was canceled by the system
/// (e.g. the app was backgrounded, or a timeout elapsed). Not an error.
final class BiometricAuthCanceled extends BiometricAuthResult {
  const BiometricAuthCanceled();
}

/// The user attempted to authenticate but failed (e.g. an unrecognized
/// fingerprint). The user may still retry.
final class BiometricAuthFailed extends BiometricAuthResult {
  const BiometricAuthFailed();
}

/// Authentication is locked because of too many failed attempts (temporarily,
/// or until the user unlocks the device with their credential).
final class BiometricAuthLockedOut extends BiometricAuthResult {
  const BiometricAuthLockedOut();
}

/// The device/browser cannot perform local authentication right now — no
/// hardware, nothing enrolled, no device credential, or an unsupported
/// platform.
final class BiometricAuthUnavailable extends BiometricAuthResult {
  const BiometricAuthUnavailable();
}

/// An unexpected platform error occurred.
final class BiometricAuthError extends BiometricAuthResult {
  /// Human-readable description, safe to log. Not intended for end users.
  final String message;

  /// The original error/exception, when available, for logging.
  final Object? cause;

  const BiometricAuthError(this.message, {this.cause});
}
