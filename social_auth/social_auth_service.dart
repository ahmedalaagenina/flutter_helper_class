import 'package:firebase_auth/firebase_auth.dart';

/// The social identity providers supported by [SocialAuthService].
enum SocialAuthProvider { google, apple, microsoft }

/// Thrown when a social sign-in flow fails or is cancelled by the user.
///
/// Keeps the service app-agnostic: callers map this to their own domain
/// failures instead of leaking provider-specific exception types.
class SocialAuthException implements Exception {
  const SocialAuthException(this.message, {this.code, this.cancelled = false});

  final String message;

  /// Provider/Firebase error code when available (e.g. `account-exists`).
  final String? code;

  /// `true` when the user dismissed/cancelled the provider sheet or popup.
  final bool cancelled;

  @override
  String toString() => 'SocialAuthException(${code ?? '-'}): $message';
}

/// App-agnostic social authentication backed by Firebase Auth.
///
/// Reusable across apps: an implementation should depend only on
/// authentication packages (`firebase_auth`, `google_sign_in`,
/// `sign_in_with_apple`) — never on app-specific networking, DI or models.
///
/// Each method performs the provider handshake, signs in to Firebase, and
/// returns the resulting [UserCredential]. Exchanging the Firebase ID token
/// (`credential.user?.getIdToken()`) with your own backend is the caller's
/// responsibility. All methods throw [SocialAuthException] on failure.
abstract class SocialAuthService {
  Future<UserCredential> signInWithGoogle();

  Future<UserCredential> signInWithApple();

  Future<UserCredential> signInWithMicrosoft();

  /// Convenience dispatcher for a dynamically selected [provider].
  Future<UserCredential> signIn(SocialAuthProvider provider);

  /// Web only: returns the pending redirect sign-in result (e.g. Microsoft via
  /// `signInWithRedirect`), or `null` when there is no pending redirect. Always
  /// returns `null` on native platforms. Call once on app startup.
  Future<UserCredential?> getRedirectResult();

  /// Signs out of Firebase and any native provider sessions (e.g. Google).
  Future<void> signOut();
}
