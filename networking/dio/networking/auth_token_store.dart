import 'package:idara_esign/core/constants/storage_keys.dart';
import 'package:idara_esign/core/security/secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AuthTokenStore {
  Future<void> saveToken(String token, {required bool persist});
  Future<String?> getToken();
  Future<bool> hasSession();
  Future<bool> isPersistentSession();
  Future<void> clearToken();
}

class AuthTokenStoreImpl implements AuthTokenStore {
  AuthTokenStoreImpl({
    required SecureStorage secureStorage,
    required SharedPreferences sharedPreferences,
  }) : _secureStorage = secureStorage,
       _sharedPreferences = sharedPreferences;

  final SecureStorage _secureStorage;
  final SharedPreferences _sharedPreferences;

  String? _volatileToken;

  @override
  Future<void> saveToken(String token, {required bool persist}) async {
    _volatileToken = token;

    if (persist) {
      await _secureStorage.write(key: StorageKeys.authToken, value: token);
      await _sharedPreferences.setBool(StorageKeys.isPersistentSession, true);
    } else {
      await _secureStorage.delete(key: StorageKeys.authToken);
      await _sharedPreferences.setBool(StorageKeys.isPersistentSession, false);
    }
  }

  @override
  Future<String?> getToken() async {
    if (_volatileToken != null && _volatileToken!.isNotEmpty) {
      return _volatileToken;
    }

    final isPersistent = await isPersistentSession();
    if (!isPersistent) {
      return null;
    }

    return _secureStorage.read(key: StorageKeys.authToken);
  }

  @override
  Future<bool> hasSession() async {
    if (_volatileToken != null && _volatileToken!.isNotEmpty) return true;

    final shouldPersist =
        _sharedPreferences.getBool(StorageKeys.isPersistentSession) ?? false;
    if (!shouldPersist) return false;

    final token = await _secureStorage.read(key: StorageKeys.authToken);
    return token != null && token.isNotEmpty;
  }

  @override
  Future<bool> isPersistentSession() async {
    return _sharedPreferences.getBool(StorageKeys.isPersistentSession) ?? false;
  }

  @override
  Future<void> clearToken() async {
    _volatileToken = null;
    await _secureStorage.delete(key: StorageKeys.authToken);
    await _sharedPreferences.remove(StorageKeys.isPersistentSession);
  }
}
