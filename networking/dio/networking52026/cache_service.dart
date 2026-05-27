import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:path_provider/path_provider.dart';

/// A singleton service that manages HTTP cache configuration and storage.
///
/// Must be initialized before use via [init]. Provides cache options
/// for the [DioCacheInterceptor] and utilities for cache management.
///
/// Usage:
/// ```dart
/// await CacheService.instance.init();
/// final options = CacheService.instance.buildOptions(
///   policy: CachePolicy.request,
///   maxStale: const Duration(hours: 1),
/// );
/// ```
class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  late final CacheStore _store;
  late final CacheOptions _defaultOptions;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initializes the cache store and default options.
  /// Must be called (and awaited) before accessing any other member.
  Future<void> init() async {
    if (_initialized) return;

    // Use temporary directory — cache is expendable data
    final dir = await getTemporaryDirectory();
    final cacheDir = '${dir.path}/dio_cache';

    _store = HiveCacheStore(cacheDir);

    _defaultOptions = CacheOptions(
      store: _store,
      policy: CachePolicy.refreshForceCache,
      maxStale: const Duration(days: 7),
      priority: CachePriority.normal,
      hitCacheOnNetworkFailure: true,
    );

    _initialized = true;
  }

  CacheStore get store {
    _ensureInitialized();
    return _store;
  }

  CacheOptions get defaultOptions {
    _ensureInitialized();
    return _defaultOptions;
  }

  /// Builds per-request [CacheOptions] with the given overrides.
  /// Always uses the initialized [_store].
  CacheOptions buildOptions({
    CachePolicy policy = CachePolicy.request,
    Duration maxStale = const Duration(days: 7),
    CachePriority priority = CachePriority.normal,
    bool hitCacheOnNetworkFailure = true,
    List<int> hitCacheOnErrorCodes = const [500, 502, 503, 504],
    CacheKeyBuilder keyBuilder = CacheOptions.defaultCacheKeyBuilder,
    bool allowPostMethod = false,
  }) {
    _ensureInitialized();

    return CacheOptions(
      store: _store,
      policy: policy,
      maxStale: maxStale,
      priority: priority,
      hitCacheOnNetworkFailure: hitCacheOnNetworkFailure,
      hitCacheOnErrorCodes: hitCacheOnErrorCodes,
      keyBuilder: keyBuilder,
      allowPostMethod: allowPostMethod,
    );
  }

  /// Clears all cached responses.
  Future<void> clearAll() async {
    _ensureInitialized();
    await _store.clean();
  }

  /// Deletes a single cached response by its key.
  Future<void> clearForKey(String cacheKey) async {
    _ensureInitialized();
    await _store.delete(cacheKey);
  }

  /// Deletes cached responses matching a path pattern.
  /// Only works with [HiveCacheStore].
  Future<void> clearForPath(
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) async {
    _ensureInitialized();

    if (_store is HiveCacheStore) {
      await _store.deleteFromPath(
        pathPattern,
        queryParams: queryParams,
      );
    }
  }

  /// Releases resources held by the cache store.
  Future<void> close() async {
    if (!_initialized) return;
    await _store.close();
    _initialized = false;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'CacheService is not initialized. '
        'Call `await CacheService.instance.init()` first.',
      );
    }
  }
}
