import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

/// Per-endpoint cache policy registry. Resolves a [CacheOptions] for a
/// given request path so you can centralize policy instead of sprinkling
/// `cacheOptions:` overrides through repositories.
///
/// Usage:
/// ```dart
/// final registry = EndpointCacheRegistry(fallback: CacheService.instance.defaultOptions)
///   ..register(RegExp(r'^/news/feed$'),
///       CacheService.instance.buildOptions(
///         policy: CachePolicy.request,
///         maxStale: const Duration(minutes: 5)))
///   ..register(RegExp(r'^/user/profile'),
///       CacheService.instance.buildOptions(
///         policy: CachePolicy.refreshForceCache,
///         maxStale: const Duration(hours: 1)));
///
/// // Wire as an interceptor before DioCacheInterceptor:
/// dio.interceptors.add(EndpointCacheInterceptor(registry));
/// dio.interceptors.add(DioCacheInterceptor(options: registry.fallback));
/// ```
class EndpointCacheRegistry {
  final CacheOptions fallback;
  final List<MapEntry<RegExp, CacheOptions>> _rules = [];

  EndpointCacheRegistry({required this.fallback});

  /// Registers a `pathPattern → options` mapping. Order matters — the
  /// first matching pattern wins. Register more specific patterns first.
  void register(RegExp pathPattern, CacheOptions options) {
    _rules.add(MapEntry(pathPattern, options));
  }

  /// Resolves the [CacheOptions] for a given path. Returns [fallback]
  /// if no rule matches.
  CacheOptions resolve(String path) {
    for (final rule in _rules) {
      if (rule.key.hasMatch(path)) return rule.value;
    }
    return fallback;
  }
}

/// Injects per-endpoint cache options based on path. Place BEFORE
/// [DioCacheInterceptor] in the interceptor chain.
///
/// Skips requests that already have `extra['dio_cache_interceptor_request_options']`
/// set (i.e. the caller explicitly passed `cacheOptions:` — caller wins).
class EndpointCacheInterceptor extends Interceptor {
  final EndpointCacheRegistry registry;

  /// The exact extra key dio_cache_interceptor uses internally. If the
  /// caller already attached options, we don't overwrite.
  static const _callerOverrideKey = '@cache_options@';

  EndpointCacheInterceptor(this.registry);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra.containsKey(_callerOverrideKey)) {
      return handler.next(options);
    }
    final resolved = registry.resolve(options.path);
    options.extra.addAll(resolved.toExtra());
    handler.next(options);
  }
}
