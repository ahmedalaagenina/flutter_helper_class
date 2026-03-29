/// Storage key constants for SharedPreferences and SecureStorage
///
/// Centralizes all storage key definitions to avoid typos and inconsistencies
class StorageKeys {
  StorageKeys._();
  // Auth tokens
  static const String authToken = 'auth_token';
  static const String refreshToken = 'refresh_token';
  static const String tokenExpiry = 'token_expiry';
  static const String isPersistentSession = 'is_persistent_session';

  // App preferences
  static const String themeMode = 'theme_mode';
  static const String language = 'language';
  static const String isFirstLaunch = 'is_first_launch';

  // Locale
  static const String locale = 'locale';

  // onboarding
  static const String onboardingCompleted = 'onboardingCompleted';
}
