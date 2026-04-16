abstract class LocalStorageApiService {
  Future<void> save({required String key, required Map<String, dynamic> data});

  Map<String, dynamic>? read(String key);

  Future<void> remove(String key);

  bool contains(String key);
}
