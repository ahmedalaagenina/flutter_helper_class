import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'social_auth_service.dart';

/// Firebase-backed implementation of [SocialAuthService].
///
/// Web vs. native differences are handled internally:
/// * Web uses Firebase's `signInWithPopup` for every provider, so it needs no
///   native SDKs — only the provider configured in the Firebase console.
/// * Native Google uses the `google_sign_in` SDK; native Apple uses
///   `sign_in_with_apple` with a hashed nonce; native Microsoft uses Firebase's
///   `signInWithProvider` (system browser flow).
///
/// This file has no app-specific imports, so it can be copied as-is into other
/// Flutter apps that use Firebase Auth.
class FirebaseSocialAuthService implements SocialAuthService {
  FirebaseSocialAuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  bool _googleInitialized = false;

  static const List<String> _googleScopes = ['email', 'profile'];

  @override
  Future<UserCredential> signIn(SocialAuthProvider provider) {
    switch (provider) {
      case SocialAuthProvider.google:
        return signInWithGoogle();
      case SocialAuthProvider.apple:
        return signInWithApple();
      case SocialAuthProvider.microsoft:
        return signInWithMicrosoft();
    }
  }

  // -------------------------------------------------------------------------
  // Google
  // -------------------------------------------------------------------------
  @override
  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'});
        return await _firebaseAuth.signInWithPopup(provider);
      }

      await _ensureGoogleInitialized();
      // Force the account chooser to appear on every sign-in.
      await _googleSignIn.signOut();

      final googleUser = await _googleSignIn.authenticate(
        scopeHint: _googleScopes,
      );
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw const SocialAuthException('Could not get Google ID token');
      }

      final authClient = _googleSignIn.authorizationClient;
      final authorization =
          await authClient.authorizationForScopes(_googleScopes) ??
          await authClient.authorizeScopes(_googleScopes);

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: authorization.accessToken,
      );
      return await _firebaseAuth.signInWithCredential(credential);
    } on SocialAuthException {
      rethrow;
    } on GoogleSignInException catch (e) {
      throw SocialAuthException(
        e.description ?? e.code.name,
        code: e.code.name,
        cancelled: e.code == GoogleSignInExceptionCode.canceled,
      );
    } on FirebaseAuthException catch (e) {
      throw SocialAuthException(e.message ?? e.code, code: e.code);
    } catch (e) {
      throw SocialAuthException('Google sign-in failed: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Apple
  // -------------------------------------------------------------------------
  @override
  Future<UserCredential> signInWithApple() async {
    try {
      if (kIsWeb) {
        // Firebase drives the full Apple OAuth popup on web; no nonce or
        // `sign_in_with_apple` round-trip is needed.
        final provider = AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
        return await _firebaseAuth.signInWithPopup(provider);
      }

      final rawNonce = _generateNonce();
      final hashedNonce = _sha256OfString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final identityToken = appleCredential.identityToken;
      if (identityToken == null) {
        throw const SocialAuthException('Could not get Apple ID token');
      }

      final oauthCredential = AppleAuthProvider.credentialWithIDToken(
        identityToken,
        rawNonce,
        AppleFullPersonName(
          givenName: appleCredential.givenName,
          familyName: appleCredential.familyName,
        ),
      );
      return await _firebaseAuth.signInWithCredential(oauthCredential);
    } on SocialAuthException {
      rethrow;
    } on SignInWithAppleAuthorizationException catch (e) {
      throw SocialAuthException(
        e.message,
        code: e.code.name,
        cancelled: e.code == AuthorizationErrorCode.canceled,
      );
    } on FirebaseAuthException catch (e) {
      throw SocialAuthException(e.message ?? e.code, code: e.code);
    } catch (e) {
      throw SocialAuthException('Apple sign-in failed: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Microsoft
  // -------------------------------------------------------------------------
  @override
  Future<UserCredential> signInWithMicrosoft() async {
    try {
      final provider = MicrosoftAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      if (kIsWeb) {
        // `signInWithPopup` is unusable for Microsoft personal accounts on web:
        // login.live.com sends COOP headers that sever the popup<->app channel,
        // causing "popup-closed-by-user" / "Pending promise was never set".
        // Use a full-page redirect; the result is collected on the next app
        // load via [getRedirectResult].
        await _firebaseAuth.signInWithRedirect(provider);
        // The browser navigates away here; keep the caller in "loading" until
        // it does (returning would surface a bogus result/error).
        return Completer<UserCredential>().future;
      }
      return await _firebaseAuth.signInWithProvider(provider);
    } on FirebaseAuthException catch (e) {
      throw SocialAuthException(e.message ?? e.code, code: e.code);
    } catch (e) {
      throw SocialAuthException('Microsoft sign-in failed: $e');
    }
  }

  @override
  Future<UserCredential?> getRedirectResult() async {
    if (!kIsWeb) return null;
    try {
      final result = await _firebaseAuth.getRedirectResult();
      // `user` is null when there is no pending redirect to consume.
      return result.user == null ? null : result;
    } on FirebaseAuthException catch (e) {
      throw SocialAuthException(e.message ?? e.code, code: e.code);
    } catch (e) {
      throw SocialAuthException('Microsoft redirect sign-in failed: $e');
    }
  }

  @override
  Future<void> signOut() async {
    if (kIsWeb) {
      await _firebaseAuth.signOut();
    } else {
      await Future.wait([_googleSignIn.signOut(), _firebaseAuth.signOut()]);
    }
  }

  Future<void> _ensureGoogleInitialized() async {
    if (kIsWeb || _googleInitialized) return;
    await _googleSignIn.initialize();
    _googleInitialized = true;
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256OfString(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}
