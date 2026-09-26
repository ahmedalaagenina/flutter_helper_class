import 'package:flutter/material.dart';
import 'package:idara_esign/core/biometric_auth/service/biometric_auth.dart';
import 'package:idara_esign/di/injection_container.dart';

/// The device's biometric glyph: a face on Face ID devices, a fingerprint
/// everywhere else (including while the kind is still being resolved).
class BiometricIcon extends StatelessWidget {
  const BiometricIcon({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  // Resolved once per app run; enrolment changes are picked up on restart.
  static final Future<BiometricKind> _kind = getIt<BiometricAuthService>()
      .biometricKind();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BiometricKind>(
      future: _kind,
      builder: (context, snapshot) => Icon(
        snapshot.data == BiometricKind.face
            ? Icons.face_unlock_rounded
            : Icons.fingerprint_rounded,
        size: size,
        color: color,
      ),
    );
  }
}
