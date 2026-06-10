import 'dart:convert';
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
/// script in `web/index.html` and it does not talk to a server. The *first*
/// [authenticate] runs a WebAuthn registration (`credentials.create`) — the
/// browser shows its "save a passkey" UI once — and the resulting credential
/// ID is kept in `localStorage`. Every later call runs an assertion
/// (`credentials.get`) against that credential, so the user only sees the OS
/// "verify your identity" prompt, and no new passkeys pile up on the device.
///
/// We only care that the user passed local verification — the assertion is
/// never sent to a server. This proves *user presence on this device*, which
/// is exactly what a "confirm before signing" gate needs. It is **not** a
/// cryptographic identity assertion: for that you need a server-issued
/// challenge and a server-side registered credential. If you later add a
/// backend WebAuthn flow, swap this class out behind [BiometricAuthService]
/// without touching call sites.
///
/// If the stored passkey was deleted from the OS, the assertion rejects with
/// `NotAllowedError` — the same error as the user canceling, so the two cannot
/// be told apart. After [_maxConsecutiveAssertFailures] consecutive
/// cancels/failures we drop the stored ID and the next call re-registers.
///
/// WebAuthn requires a secure context (HTTPS or `localhost`). On unsupported
/// browsers every method degrades gracefully to "unavailable".
class BiometricAuthWebImpl implements BiometricAuthService {
  static const _credentialIdKey = 'biometric_auth.credential_id';
  static const _assertFailuresKey = 'biometric_auth.assert_failures';
  static const _maxConsecutiveAssertFailures = 2;

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

    final credentialId = _readStored(_credentialIdKey);
    if (credentialId != null) {
      final result = await _assertExisting(credentialId, biometricOnly);
      if (result != null) return result;
      // The stored credential is unusable — fall through and re-register.
    }
    return _registerNew(localizedReason, biometricOnly);
  }

  /// Verifies the user against the passkey registered by a previous call
  /// (the OS shows its "verify your identity" prompt). Returns `null` when the
  /// stored credential is unusable and registration should run instead.
  Future<BiometricAuthResult?> _assertExisting(
    String credentialId,
    bool biometricOnly,
  ) async {
    final Uint8List rawId;
    try {
      rawId = base64Url.decode(credentialId);
    } catch (_) {
      _writeStored(_credentialIdKey, null);
      return null;
    }

    try {
      final credential = await web.window.navigator.credentials
          .get(
            web.CredentialRequestOptions(
              publicKey: web.PublicKeyCredentialRequestOptions(
                challenge: _randomBytes(32).toJS,
                allowCredentials: <web.PublicKeyCredentialDescriptor>[
                  web.PublicKeyCredentialDescriptor(
                    type: 'public-key',
                    id: rawId.toJS,
                    transports: <JSString>['internal'.toJS].toJS,
                  ),
                ].toJS,
                userVerification: biometricOnly ? 'required' : 'preferred',
                timeout: 60000,
              ),
            ),
          )
          .toDart;

      _writeStored(_assertFailuresKey, null);
      return credential != null
          ? const BiometricAuthSuccess()
          : const BiometricAuthFailed();
    } catch (e) {
      final result = _mapError(e);
      if (result is BiometricAuthUnavailable) {
        // e.g. InvalidStateError — the passkey no longer exists on this
        // authenticator. Drop it and re-register within this same call.
        _writeStored(_credentialIdKey, null);
        return null;
      }
      if (result is BiometricAuthCanceled) {
        // A deleted passkey also rejects with NotAllowedError, which is
        // indistinguishable from the user canceling. Tolerate a couple of
        // cancels, then assume the passkey is gone so the next call
        // re-registers instead of failing forever.
        final failures =
            (int.tryParse(_readStored(_assertFailuresKey) ?? '') ?? 0) + 1;
        if (failures >= _maxConsecutiveAssertFailures) {
          _writeStored(_credentialIdKey, null);
          _writeStored(_assertFailuresKey, null);
        } else {
          _writeStored(_assertFailuresKey, '$failures');
        }
      }
      return result;
    }
  }

  /// Registers a passkey with the platform authenticator (the browser shows
  /// its "create/save a passkey" UI once) and stores its credential ID so
  /// later calls can assert against it instead of creating another one.
  Future<BiometricAuthResult> _registerNew(
    String localizedReason,
    bool biometricOnly,
  ) async {
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

      if (credential == null) return const BiometricAuthFailed();

      final rawId = (credential as web.PublicKeyCredential).rawId.toDart
          .asUint8List();
      _writeStored(_credentialIdKey, base64UrlEncode(rawId));
      _writeStored(_assertFailuresKey, null);
      return const BiometricAuthSuccess();
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

  String? _readStored(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      // Storage can be blocked (e.g. privacy settings); degrade to the
      // register-every-time behavior rather than failing.
      return null;
    }
  }

  void _writeStored(String key, String? value) {
    try {
      value == null
          ? web.window.localStorage.removeItem(key)
          : web.window.localStorage.setItem(key, value);
    } catch (_) {}
  }

  Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }
}
