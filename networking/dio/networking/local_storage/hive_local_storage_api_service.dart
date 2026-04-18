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

    return _normalizeMap(result);
  }

  @override
  bool contains(String key) {
    return box.containsKey(key);
  }

  @override
  Future<void> remove(String key) async {
    await box.delete(key);
  }

  @override
  Future<void> clearAll() async {
   await Hive.deleteFromDisk();
  }

  Map<String, dynamic> _normalizeMap(dynamic value) {
    return Map<String, dynamic>.fromEntries(
      (value as Map).entries.map(
        (entry) => MapEntry(entry.key.toString(), _normalizeValue(entry.value)),
      ),
    );
  }

  dynamic _normalizeValue(dynamic value) {
    if (value is Map) {
      return _normalizeMap(value);
    }

    if (value is List) {
      return value.map(_normalizeValue).toList(growable: false);
    }

    return value;
  }
}
