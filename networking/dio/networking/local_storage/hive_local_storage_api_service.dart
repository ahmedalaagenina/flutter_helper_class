import 'package:hive_ce/hive.dart';
import 'package:idara_driver/core/networking/local_storage/local_storage_api_service.dart';

class HiveLocalStorageApiService implements LocalStorageApiService {
  final Box box;

  HiveLocalStorageApiService(this.box);

  @override
  Future<void> save({
    required String key,
    required Map<String, dynamic> data,
  }) async {
    await box.put(key, data);
  }

  @override
  Map<String, dynamic>? read(String key) {
    final result = box.get(key);
    if (result == null) return null;
    return Map<String, dynamic>.from(result);
  }

  @override
  Future<void> remove(String key) async {
    await box.delete(key);
  }

  @override
  bool contains(String key) {
    return box.containsKey(key);
  }
}
