import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

import 'biometric_auth_result.dart';
import 'biometric_auth_service.dart';

class BiometricAuthServiceImpl implements BiometricAuthService {
  final LocalAuthentication _auth;

  BiometricAuthServiceImpl({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> hasBiometrics() async {
    try {
      if (!await isAvailable()) return false;
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
  }) async {
    if (!await isAvailable()) return const BiometricAuthNotAvailable();

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          // false = allows PIN/password/pattern as fallback automatically
          biometricOnly: false,
          // keeps the prompt alive if user switches apps briefly
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );

      return authenticated
          ? const BiometricAuthSuccess()
          : const BiometricAuthFailed();
    } on PlatformException catch (e) {
      if (e.code == auth_error.notAvailable ||
          e.code == auth_error.notEnrolled) {
        return const BiometricAuthNotAvailable();
      }
      if (e.code == auth_error.lockedOut ||
          e.code == auth_error.permanentlyLockedOut) {
        return const BiometricAuthError(
          'Too many failed attempts. Device is locked out.',
        );
      }
      // User cancelled (passcodeNotSet, otherOperatingSystem, etc.)
      return const BiometricAuthFailed();
    } catch (e) {
      return BiometricAuthError(e.toString());
    }
  }
}
