import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Clear keychain on reinstall 
/// call this function on first of init and before of di.init()  
// Future<void> _clearKeychainOnReinstall() async {
//   final prefs = await SharedPreferences.getInstance();
//   final hasRunBefore = prefs.getBool('has_run_before') ?? false;

//   if (!hasRunBefore) {
//     debugPrint('🗑️ First launch detected — clearing Keychain data.');
//     const storage = FlutterSecureStorage();
//     await storage.deleteAll();
//     await prefs.setBool('has_run_before', true);
//   }
// }

abstract class SecureStorage {
  /// Save a secure value
  Future<void> write({required String key, required String value});

  /// Read a secure value
  Future<String?> read({required String key});

  /// Delete a secure value
  Future<void> delete({required String key});

  /// Delete all secure values
  Future<void> deleteAll();

  /// Check if a key exists
  Future<bool> containsKey({required String key});
}

class SecureStorageImpl implements SecureStorage {
  final FlutterSecureStorage _storage;

  SecureStorageImpl(this._storage);

  @override
  Future<void> write({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read({required String key}) async {
    return await _storage.read(key: key);
  }

  @override
  Future<void> delete({required String key}) async {
    await _storage.delete(key: key);
  }

  @override
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  @override
  Future<bool> containsKey({required String key}) async {
    final value = await read(key: key);
    return value != null;
  }
}
