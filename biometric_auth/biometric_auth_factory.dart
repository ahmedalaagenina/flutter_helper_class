// lib/core/services/biometric_auth/biometric_auth_factory.dart

import 'package:flutter/foundation.dart';
import 'biometric_auth_service.dart';
import 'biometric_auth_service_impl.dart';
import 'biometric_auth_web_stub.dart';

/// Returns the correct [BiometricAuthService] for the current platform.
///
/// Usage in GetIt:
/// ```dart
/// sl.registerLazySingleton<BiometricAuthService>(
///   () => createBiometricAuthService(),
/// );
/// ```
BiometricAuthService createBiometricAuthService() {
  if (kIsWeb) return BiometricAuthWebImpl();
  return BiometricAuthServiceImpl();
}

