import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/logger.dart';

/// Social authentication result containing Firebase ID token and user info
class SocialAuthResult {
  final String firebaseIdToken;
  final String? email;
  final String? name;

  const SocialAuthResult({
    required this.firebaseIdToken,
    this.email,
    this.name,
  });
}

/// Abstract interface for social authentication using Firebase Auth
abstract class SocialAuthRemoteDataSource {
  /// Sign in with Google via Firebase Auth
  /// Returns [SocialAuthResult] with Firebase ID token
  /// Throws [AuthenticationException] on failure
  Future<SocialAuthResult> signInWithGoogle();

  /// Sign in with Apple via Firebase Auth
  /// Returns [SocialAuthResult] with Firebase ID token
  /// Throws [AuthenticationException] on failure
  Future<SocialAuthResult> signInWithApple();

  /// Sign out from all providers and Firebase
  Future<void> signOut();
}

/// Firebase-based implementation of social authentication
class SocialAuthRemoteDataSourceImpl implements SocialAuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  bool _isInitialized = false;

  SocialAuthRemoteDataSourceImpl({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _googleSignIn.initialize();
      _isInitialized = true;
    }
  }

  @override
  Future<SocialAuthResult> signInWithGoogle() async {
    try {
      await _ensureInitialized();

      // Ensure fresh sign-in
      await _googleSignIn.signOut();

      // Use the v7 API authenticate method
      final googleUser = await _googleSignIn.authenticate(scopeHint: ['email']);

      final googleAuth = googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw AuthenticationException('Could not get Google ID Token');
      }

      // Get access token separately (v7 API requirement)
      String? accessToken;
      try {
        final authorization = await _googleSignIn.authorizationClient
            .authorizationForScopes(['email']);
        accessToken = authorization?.accessToken;
      } catch (e) {
        AppLogger.warning('Failed to get access token: $e');
        // Continue without access token - Firebase can work with just idToken
      }

      // Create Firebase credential and sign in
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      final firebaseIdToken = await _getFirebaseIdToken(userCredential.user);

      AppLogger.info('Google Sign-In successful: ${googleUser.email}');

      return SocialAuthResult(
        firebaseIdToken: firebaseIdToken,
        email: googleUser.email,
        name: googleUser.displayName,
      );
    } on AuthenticationException {
      rethrow;
    } catch (e) {
      AppLogger.error('Google Sign-In error: $e');
      throw AuthenticationException('Google Sign-In failed: ${e.toString()}');
    }
  }

  @override
  Future<SocialAuthResult> signInWithApple() async {
    try {
      // Generate secure nonce
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      // Get Apple credential (webAuthenticationOptions required for Android)
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: ApiConstants.appleServiceId,
          redirectUri: Uri.parse(ApiConstants.appleRedirectUri),
        ),
      );

      if (appleCredential.identityToken == null) {
        throw AuthenticationException('Could not get Apple ID Token');
      }

      // Build name from Apple credential
      final fullName = _buildFullName(
        appleCredential.givenName,
        appleCredential.familyName,
      );

      // Create Firebase credential
      final oauthCredential = AppleAuthProvider.credentialWithIDToken(
        appleCredential.identityToken!,
        rawNonce,
        AppleFullPersonName(
          familyName: appleCredential.familyName,
          givenName: appleCredential.givenName,
        ),
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        oauthCredential,
      );
      final firebaseIdToken = await _getFirebaseIdToken(userCredential.user);

      AppLogger.info('Apple Sign-In successful');

      return SocialAuthResult(
        firebaseIdToken: firebaseIdToken,
        email: appleCredential.email,
        name: fullName ?? userCredential.user?.displayName,
      );
    } on AuthenticationException {
      rethrow;
    } catch (e) {
      AppLogger.error('Apple Sign-In error: $e');
      throw AuthenticationException('Apple Sign-In failed: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await Future.wait([_googleSignIn.signOut(), _firebaseAuth.signOut()]);
    } catch (e) {
      AppLogger.warning('Sign-Out error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Private Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  Future<String> _getFirebaseIdToken(User? user) async {
    final token = await user?.getIdToken();
    if (token == null) {
      throw AuthenticationException('Could not get Firebase ID Token');
    }
    return token;
  }

  String? _buildFullName(String? givenName, String? familyName) {
    if (givenName == null && familyName == null) return null;
    return '${givenName ?? ''} ${familyName ?? ''}'.trim();
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

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
