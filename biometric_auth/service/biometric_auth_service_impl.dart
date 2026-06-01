import 'package:local_auth/local_auth.dart';

import 'biometric_auth_result.dart';
import 'biometric_auth_service.dart';

/// Returns the [BiometricAuthService] for native platforms (Android, iOS,
/// macOS, Windows). Selected automatically by `biometric_auth_factory.dart`
/// via conditional import — do not call directly.
BiometricAuthService createPlatformBiometricAuthService() =>
    BiometricAuthServiceImpl();

/// [BiometricAuthService] backed by the `local_auth` plugin (3.x API).
class BiometricAuthServiceImpl implements BiometricAuthService {
  final LocalAuthentication _auth;

  BiometricAuthServiceImpl({LocalAuthentication? localAuthentication})
    : _auth = localAuthentication ?? LocalAuthentication();

  @override
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> hasEnrolledBiometrics() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
  }) async {
    if (!await isSupported()) {
      return const BiometricAuthUnavailable();
    }

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: biometricOnly,
        // Show platform confirmation after face recognition for sensitive ops.
        sensitiveTransaction: true,
        // Resume (instead of failing) if the app is briefly backgrounded.
        persistAcrossBackgrounding: true,
      );

      return authenticated
          ? const BiometricAuthSuccess()
          : const BiometricAuthFailed();
    } on LocalAuthException catch (e) {
      return _mapException(e);
    } catch (e) {
      return BiometricAuthError(e.toString(), cause: e);
    }
  }

  /// Maps the plugin's [LocalAuthException] onto our typed result hierarchy.
  ///
  /// The plugin documents that [LocalAuthExceptionCode] may gain new values, so
  /// the `default` branch is intentional and required.
  BiometricAuthResult _mapException(LocalAuthException e) {
    switch (e.code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.timeout:
      case LocalAuthExceptionCode.userRequestedFallback:
        return const BiometricAuthCanceled();

      case LocalAuthExceptionCode.noCredentialsSet:
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noBiometricHardware:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return const BiometricAuthUnavailable();

      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return const BiometricAuthLockedOut();

      // authInProgress, uiUnavailable, deviceError, unknownError, and any
      // codes added by future plugin versions.
      default:
        return BiometricAuthError(e.description ?? e.code.name, cause: e);
    }
  }
}
