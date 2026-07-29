import 'dart:convert';

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

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

  // ── Ready-made policies for the HTTP response cache ──────────────────
  // Pass one as `cacheOptions:` on an ApiService call to control what the
  // DioCacheInterceptor does for that single request. These are independent
  // of `CacheMode`, which governs the Hive store instead.

  /// Never reads and never writes the HTTP cache — not even on failure.
  /// Any previously stored entry for this request is deleted.
  CacheOptions get networkOnly => buildOptions(
    policy: CachePolicy.noCache,
    hitCacheOnNetworkFailure: false,
    hitCacheOnErrorCodes: const [],
  );

  /// Serves the stored copy when one exists; only reaches the network when
  /// the store is empty. The cheapest read, and the most stale.
  CacheOptions cacheFirst({Duration maxStale = const Duration(days: 7)}) =>
      buildOptions(policy: CachePolicy.forceCache, maxStale: maxStale);

  /// Always requests the network and stores the result regardless of what
  /// the server's cache headers say; serves the stored copy on failure.
  CacheOptions refreshAndStore({
    Duration maxStale = const Duration(days: 7),
    bool hitCacheOnNetworkFailure = true,
  }) => buildOptions(
    policy: CachePolicy.refreshForceCache,
    maxStale: maxStale,
    hitCacheOnNetworkFailure: hitCacheOnNetworkFailure,
  );

  /// Always requests the network; stores the result only when the server's
  /// cache headers permit it. Use when the backend owns cache lifetime.
  CacheOptions refreshRespectingHeaders({
    Duration maxStale = const Duration(days: 7),
  }) => buildOptions(policy: CachePolicy.refresh, maxStale: maxStale);

  /// Caches a **read-shaped POST** (search, filter, report) — an endpoint that
  /// uses POST only because its payload is too big for a query string, and
  /// that changes nothing on the server.
  ///
  /// The test: *if the same request is sent twice, does something happen twice
  /// on the server?* Yes → never use this. No → safe.
  ///
  /// Pointing this at a real mutation breaks it in two ways:
  ///
  /// 1. `CachePolicy.forceCache` looks the store up **before sending**. Repeat
  ///    a mutation with an identical body inside [maxStale] and the request is
  ///    answered from cache and never leaves the device, while the UI reports
  ///    success. [maxStale] is exactly how long that suppression lasts.
  /// 2. On a dead connection the stored response is served instead of the
  ///    error. `handleWrite` sees success, and since [DioCacheInterceptor]
  ///    runs before [OfflineSyncInterceptor] the request is never queued —
  ///    the write is lost silently.
  ///
  /// Safe: `POST /trips/search`, `/reports/generate`, `/pricing/calculate`.
  /// Never: `POST /trips`, `/auth/login`, `/trips/{id}/complete`, any upload.
  ///
  /// Uses [bodyAwareCacheKeyBuilder], because the default key builder hashes
  /// the URL alone — every payload posted to the same path would otherwise
  /// share one cache entry.
  CacheOptions postCache({Duration maxStale = const Duration(minutes: 10)}) =>
      buildOptions(
        policy: CachePolicy.forceCache,
        maxStale: maxStale,
        allowPostMethod: true,
        keyBuilder: bodyAwareCacheKeyBuilder,
      );

  /// Cache key derived from the URL **and** the request body.
  ///
  /// Map keys are sorted so two equal bodies serialized in a different order
  /// still land on the same entry.
  static String bodyAwareCacheKeyBuilder({
    required Uri url,
    Map<String, String>? headers,
    Object? body,
  }) => const Uuid().v5(Namespace.url.value, '$url::${_stableBody(body)}');

  static String _stableBody(Object? body) {
    if (body == null) return '';
    try {
      return jsonEncode(_sortKeys(body));
    } catch (_) {
      // Not JSON-encodable — FormData, streams, raw bytes. FormData does not
      // override toString(), so every instance renders as "Instance of
      // 'FormData'" and they would all collide on a single entry. Emit a
      // unique value instead so the lookup always misses. Multipart uploads
      // should not be routed through [postCache] in the first place.
      return const Uuid().v4();
    }
  }

  static Object? _sortKeys(Object? value) {
    if (value is Map) {
      final entries =
          value.entries
              .map((e) => MapEntry(e.key.toString(), _sortKeys(e.value)))
              .toList()
            ..sort((a, b) => a.key.compareTo(b.key));
      return Map<String, Object?>.fromEntries(entries);
    }
    if (value is List) return value.map(_sortKeys).toList();
    return value;
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
      await _store.deleteFromPath(pathPattern, queryParams: queryParams);
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
