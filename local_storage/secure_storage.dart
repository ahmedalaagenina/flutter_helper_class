import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Clear keychain on reinstall
/// call this function on first of init and before of di.init()
// Future<void> _clearKeychainOnReinstall() async {
// if (kIsWeb) return;
//   final prefs = await SharedPreferences.getInstance();
//   final hasRunBefore = prefs.getBool('has_run_before') ?? false;

//   if (!hasRunBefore) {
//     debugPrint('🗑️ First launch detected — clearing Keychain data.');
//     const storage = FlutterSecureStorage();
//     await storage.deleteAll();
//     await prefs.setBool('has_run_before', true);
//   }
// }
/* =========================
   LOCAL PERSISTENCE
========================= */
// Future<void> _registerLocalPersistence() async {
//   final sharedPreferences = await SharedPreferences.getInstance();
//   const flutterSecureStorage = FlutterSecureStorage();

//   getIt.registerLazySingleton<SharedPreferences>(() => sharedPreferences);
//   getIt.registerLazySingleton<FlutterSecureStorage>(() => flutterSecureStorage);

//   getIt.registerLazySingleton<CacheStorage>(
//     () => CacheStorageImpl(getIt<SharedPreferences>()),
//   );

//   getIt.registerLazySingleton<SecureStorage>(
//     () => SecureStorageImpl(getIt<FlutterSecureStorage>()),
//   );
// }
abstract class SecureStorage {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
  Future<void> deleteAll();
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
