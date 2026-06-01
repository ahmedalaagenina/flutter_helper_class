import 'dart:js_interop';

import 'files (1)/biometric_auth_result.dart';
import 'files (1)/biometric_auth_service.dart';

// ---------------------------------------------------------------------------
// JS bindings — calls the helper functions we define in web/index.html
// ---------------------------------------------------------------------------

@JS('window.webAuthnIsAvailable')
external JSPromise<JSBoolean> _webAuthnIsAvailable();

@JS('window.webAuthnAuthenticate')
external JSPromise<JSBoolean> _webAuthnAuthenticate(JSString challenge);

// ---------------------------------------------------------------------------

class BiometricAuthWebImpl implements BiometricAuthService {
  @override
  Future<bool> isAvailable() async {
    try {
      final result = await _webAuthnIsAvailable().toDart;
      return result.toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> hasBiometrics() => isAvailable();

  @override
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
  }) async {
    if (!await isAvailable()) return const BiometricAuthNotAvailable();

    try {
      // In a production app, this challenge should come from your server
      // to prevent replay attacks. A timestamp is fine for local-only verification.
      final challenge = DateTime.now().millisecondsSinceEpoch.toString();
      final result = await _webAuthnAuthenticate(challenge.toJS).toDart;

      return result.toDart
          ? const BiometricAuthSuccess()
          : const BiometricAuthFailed();
    } catch (e) {
      final msg = e.toString();

      // NotAllowedError = user cancelled the browser prompt
      if (msg.contains('NotAllowedError')) {
        return const BiometricAuthFailed();
      }

      // InvalidStateError = credential not registered on this device yet
      // This is expected on first visit — treat as not available
      if (msg.contains('InvalidStateError')) {
        return const BiometricAuthNotAvailable();
      }

      return BiometricAuthError(msg);
    }
  }
}
