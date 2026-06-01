import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'biometric_auth_result.dart';
import 'biometric_auth_service.dart';

/// Returns the [BiometricAuthService] for the web platform. Selected
/// automatically by `biometric_auth_factory.dart` via conditional import — do
/// not call directly.
BiometricAuthService createPlatformBiometricAuthService() =>
    BiometricAuthWebImpl();

/// [BiometricAuthService] for the web, backed by the WebAuthn API
/// (`navigator.credentials`) and a platform authenticator — Touch ID / Face ID,
/// Windows Hello, Android biometrics, or the device's screen-lock as fallback.
///
/// ## How it works (and its limits)
///
/// This implementation is **self-contained**: it does not require any helper
/// script in `web/index.html` and it does not talk to a server. On
/// [authenticate] it issues a WebAuthn *registration* (`credentials.create`)
/// with a platform authenticator and `userVerification`, which makes the
/// browser prompt the user for their biometric / device PIN. We only care that
/// the user passed that local verification — the generated credential is not
/// persisted or sent anywhere.
///
/// This proves *user presence on this device*, which is exactly what a
/// "confirm before signing" gate needs. It is **not** a cryptographic identity
/// assertion: for that you need a server-issued challenge and a stored,
/// registered credential. If you later add a backend WebAuthn flow, swap this
/// class out behind [BiometricAuthService] without touching call sites.
///
/// WebAuthn requires a secure context (HTTPS or `localhost`). On unsupported
/// browsers every method degrades gracefully to "unavailable".
class BiometricAuthWebImpl implements BiometricAuthService {
  final Random _random;

  BiometricAuthWebImpl({Random? random}) : _random = random ?? Random.secure();

  @override
  Future<bool> isSupported() async {
    try {
      // `window.PublicKeyCredential` is undefined on browsers without WebAuthn.
      if (!_hasWebAuthn()) return false;
      return await web.PublicKeyCredential
          .isUserVerifyingPlatformAuthenticatorAvailable()
          .toDart
          .then((value) => value.toDart);
    } catch (_) {
      return false;
    }
  }

  /// The browser cannot tell us whether a biometric is enrolled without
  /// prompting, so we treat "platform authenticator available" as the best
  /// available signal.
  @override
  Future<bool> hasEnrolledBiometrics() => isSupported();

  @override
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
  }) async {
    if (!await isSupported()) {
      return const BiometricAuthUnavailable();
    }

    try {
      final options = web.CredentialCreationOptions(
        publicKey: web.PublicKeyCredentialCreationOptions(
          challenge: _randomBytes(32).toJS,
          rp: web.PublicKeyCredentialRpEntity(
            name: web.window.location.hostname,
          ),
          user: web.PublicKeyCredentialUserEntity(
            id: _randomBytes(16).toJS,
            name: localizedReason,
            displayName: localizedReason,
          ),
          pubKeyCredParams: <web.PublicKeyCredentialParameters>[
            web.PublicKeyCredentialParameters(type: 'public-key', alg: -7),
            web.PublicKeyCredentialParameters(type: 'public-key', alg: -257),
          ].toJS,
          authenticatorSelection: web.AuthenticatorSelectionCriteria(
            authenticatorAttachment: 'platform',
            userVerification: biometricOnly ? 'required' : 'preferred',
            residentKey: 'discouraged',
          ),
          timeout: 60000,
          attestation: 'none',
        ),
      );

      final credential = await web.window.navigator.credentials
          .create(options)
          .toDart;

      return credential != null
          ? const BiometricAuthSuccess()
          : const BiometricAuthFailed();
    } catch (e) {
      return _mapError(e);
    }
  }

  /// Maps a rejected WebAuthn promise (a `DOMException`) onto our result type.
  BiometricAuthResult _mapError(Object error) {
    final name = _domExceptionName(error) ?? error.toString();

    // The user dismissed the prompt or it timed out.
    if (name.contains('NotAllowedError') || name.contains('AbortError')) {
      return const BiometricAuthCanceled();
    }
    // No platform authenticator / not a secure context / unsupported.
    if (name.contains('NotSupportedError') ||
        name.contains('SecurityError') ||
        name.contains('InvalidStateError')) {
      return const BiometricAuthUnavailable();
    }
    return BiometricAuthError(name, cause: error);
  }

  bool _hasWebAuthn() =>
      web.window.has('PublicKeyCredential') &&
      web.window.navigator.has('credentials');

  /// Reads the `name` field off a thrown `DOMException`, if present.
  String? _domExceptionName(Object error) {
    // This file only ever runs on web, where a rejected WebAuthn promise throws
    // a JS DOMException, so the JS-interop type check is platform-consistent.
    // ignore: invalid_runtime_check_with_js_interop_types
    if (error is JSObject && error.has('name')) {
      return (error.getProperty('name'.toJS) as JSString?)?.toDart;
    }
    return null;
  }

  Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }
}
