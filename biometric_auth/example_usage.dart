
// Android — android/app/src/main/AndroidManifest.xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<!-- For older APIs -->
<uses-permission android:name="android.permission.USE_FINGERPRINT" />



// iOS — ios/Runner/Info.plist
<key>NSFaceIDUsageDescription</key>
<string>We use Face ID to verify your identity</string>



// ============================================================
// EXAMPLE: How to use BiometricAuthService in a BLoC or UseCase
// ============================================================

import 'package:flutter/material.dart';
import 'files (1)/core/services/biometric_auth/biometric_auth.dart';

// ── In your GetIt setup (injection_container.dart) ──────────────────────────

// sl.registerLazySingleton<BiometricAuthService>(
//   () => createBiometricAuthService(),
// );

// ── In a UseCase ─────────────────────────────────────────────────────────────

class VerifyUserIdentityUseCase {
  final BiometricAuthService _authService;

  VerifyUserIdentityUseCase(this._authService);

  Future<bool> call() async {
    final result = await _authService.authenticate(
      localizedReason: 'Please verify your identity to continue',
    );

    return switch (result) {
      BiometricAuthSuccess()      => true,
      BiometricAuthFailed()       => false,
      BiometricAuthNotAvailable() => true,  // ← silently skip, no auth required
      BiometricAuthError()        => false,
    };
  }
}

// ── In a BLoC event handler ───────────────────────────────────────────────────

// Future<void> _onVerifyIdentity(
//   VerifyIdentityEvent event,
//   Emitter<YourState> emit,
// ) async {
//   emit(state.copyWith(status: Status.loading));
//
//   final result = await sl<BiometricAuthService>().authenticate(
//     localizedReason: 'Authenticate to sign the document',
//   );
//
//   switch (result) {
//     case BiometricAuthSuccess():
//       emit(state.copyWith(status: Status.authenticated));
//
//     case BiometricAuthFailed():
//       emit(state.copyWith(
//         status: Status.error,
//         errorMessage: 'Authentication failed. Please try again.',
//       ));
//
//     case BiometricAuthNotAvailable():
//       // Device has no biometric/PIN — skip silently and proceed
//       emit(state.copyWith(status: Status.authenticated));
//
//     case BiometricAuthError(:final message):
//       emit(state.copyWith(status: Status.error, errorMessage: message));
//   }
// }

// ── Quick check before showing the biometric button in UI ───────────────────

class BiometricButtonWidget extends StatefulWidget {
  const BiometricButtonWidget({super.key});

  @override
  State<BiometricButtonWidget> createState() => _BiometricButtonWidgetState();
}

class _BiometricButtonWidgetState extends State<BiometricButtonWidget> {
  bool _isAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    // Replace sl<...> with however you access your service
    // final service = sl<BiometricAuthService>();
    // final available = await service.isAvailable();
    // setState(() => _isAvailable = available);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAvailable) return const SizedBox.shrink(); // hide on unsupported devices

    return ElevatedButton.icon(
      onPressed: () async {
        // final service = sl<BiometricAuthService>();
        // final result = await service.authenticate(
        //   localizedReason: 'Authenticate to continue',
        // );
        // handle result...
      },
      icon: const Icon(Icons.fingerprint),
      label: const Text('Verify Identity'),
    );
  }
}
