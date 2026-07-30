import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart' as ad;
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:idara_tracking_app/core/local_storage/storage_keys.dart';
import 'package:idara_tracking_app/core/networking/networking.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Copy-paste registration for GetIt. Verified to compile against this folder.
// Needs: get_it, hive_ce_flutter, flutter_secure_storage, shared_preferences.
//
// Order matters in two places: Hive.initFlutter() must precede SyncQueue.init()
// and CacheService.init(), and NetworkHelper must be registered before Dio so
// the main and replay Dios come from the same instance.
//
// Future<void> registerNetworkStack() async {
//   // ── 1. Storage primitives ──────────────────────────────────────────
//   getIt.registerSingleton<SharedPreferences>(
//     await SharedPreferences.getInstance(),
//   );
//   getIt.registerSingleton<SecureStorage>(
//     SecureStorageImpl(const FlutterSecureStorage()),
//   );
//
//   // ── 2. Hive — MUST come before SyncQueue / CacheService ────────────
//   await Hive.initFlutter();
//   await CacheService.instance.init();
//
//   final syncQueue = SyncQueue();
//   await syncQueue.init();
//   getIt.registerSingleton<SyncQueue>(syncQueue);
//
//   final userBox = await Hive.openBox<dynamic>('user_box');
//   getIt.registerSingleton<LocalStorageApiService>(
//     HiveLocalStorageApiService(userBox),
//   );
//
//   // ── 3. Leaf services ───────────────────────────────────────────────
//   getIt.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());
//   getIt.registerFactory<CancelToken>(() => CancelToken());
//   getIt.registerLazySingleton<AuthTokenStore>(
//     () => AuthTokenStoreImpl(
//       secureStorage: getIt<SecureStorage>(),
//       sharedPreferences: getIt<SharedPreferences>(),
//     ),
//   );
//
//   // Teach the error handler how your backend shapes messages.
//   ApiFailureHandler.messageExtractor = const DefaultServerMessageExtractor();
//
//   // ── 4. NetworkHelper — one instance builds BOTH Dios ───────────────
//   getIt.registerSingletonAsync<NetworkHelper>(() async {
//     return NetworkHelper(
//       getIt<AuthTokenStore>(),
//       getIt<SharedPreferences>(),
//       syncQueue: syncQueue,
//
//       // Optional. Drop it and every request uses CacheService.defaultOptions.
//       cacheRegistry: EndpointCacheRegistry(
//         fallback: CacheService.instance.networkOnly,
//       )
//         ..register(RegExp(r'^/auth/'), CacheService.instance.networkOnly)
//         ..register(
//           RegExp(r'^/home$'),
//           CacheService.instance.cacheFirst(maxStale: const Duration(hours: 6)),
//         ),
//
//       // Resolved lazily — fires only on a failed refresh, by which point
//       // AuthBloc is registered, so registration order does not matter.
//       onForceLogout: () {
//         if (!getIt.isRegistered<AuthBloc>()) return;
//         final bloc = getIt<AuthBloc>();
//         if (!bloc.isClosed) bloc.add(const LogoutEvent());
//       },
//       onTelemetry: (event) => AppLog.i(event.toString()),
//     );
//   });
//
//   // ── 5. Main Dio + ApiService ───────────────────────────────────────
//   getIt.registerSingletonAsync<Dio>(
//     () async => (await getIt.getAsync<NetworkHelper>()).createDio(),
//     dependsOn: [NetworkHelper],
//   );
//
//   getIt.registerSingletonWithDependencies<ApiService>(
//     () => ApiServiceImpl(getIt<Dio>()),
//     dependsOn: [Dio],
//   );
//
//   // ── 6. Offline sync — its OWN replay Dio, never the main one.
//   //    createReplayDio() has no duplicate-detection, no cache and no
//   //    offline-sync interceptor, so replays cannot re-queue themselves.
//   getIt.registerSingletonAsync<SyncServiceManager>(
//     () async {
//       final replayDio =
//           await (await getIt.getAsync<NetworkHelper>()).createReplayDio();
//       return SyncServiceManager(
//         dio: replayDio,
//         queue: getIt<SyncQueue>(),
//         networkInfo: getIt<NetworkInfo>(),
//       );
//     },
//     dependsOn: [NetworkHelper],
//   );
//
//   // ── 7. Wait for every async singleton, then start syncing ──────────
//   await getIt.allReady();
//   await getIt<SyncServiceManager>().init();
// }

/// Helper class for creating and configuring Dio instances
class NetworkHelper {
  final AuthTokenStore _tokenStore;
  final SharedPreferences _prefs;
  final SyncQueue? _syncQueue;
  final void Function()? _onForceLogout;
  final void Function(TelemetryEvent)? _onTelemetry;

  /// Optional per-path cache policy. When supplied, an
  /// [EndpointCacheInterceptor] resolves each request's [CacheOptions] from it
  /// and the registry's `fallback` becomes the interceptor default — so an
  /// endpoint you forgot to register inherits that instead of a blanket
  /// policy. When null, every request uses [CacheService.defaultOptions].
  final EndpointCacheRegistry? _cacheRegistry;

  NetworkHelper(
    this._tokenStore,
    this._prefs, {
    this._syncQueue,
    this._onForceLogout,
    this._onTelemetry,
    EndpointCacheRegistry? cacheRegistry,
  }) : _cacheRegistry = cacheRegistry;

  Future<Dio> createDio({
    int defaultMaxRetries = 3,
    Duration defaultRetryDelay = const Duration(seconds: 2),
  }) async {
    final baseOptions = BaseOptions(
      baseUrl: ApiConstant.baseUrl,
      followRedirects: true,
      receiveDataWhenStatusError: true,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Connection': 'keep-alive'},
    );

    final dio = Dio(baseOptions);
    final refreshDio = Dio(baseOptions);
    refreshDio.interceptors.addAll([
      RetryInterceptor(
        dio: refreshDio,
        maxRetries: defaultMaxRetries,
        initialDelay: defaultRetryDelay,
      ),
      if (kDebugMode)
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseHeader: true,
        ),
    ]);

    dio.interceptors.addAll([
      // 1. Telemetry FIRST — stamps start time, observes everything below it.
      if (_onTelemetry != null) TelemetryInterceptor(onEvent: _onTelemetry),

      // 2. Idempotency — generates/forwards Idempotency-Key header.
      //    Must run BEFORE Duplicate so the key is set even for first attempt.
      IdempotencyInterceptor(),

      // 3. Kills duplicates before auth/retry/logging.
      DuplicateRequestInterceptor(),

      // 4. Auth.
      AuthInterceptor(
        tokenStore: _tokenStore,
        dio: dio,
        refreshDio: refreshDio, // separate Dio WITHOUT this interceptor
        refreshPath: ApiConstant.refreshToken,
        publicPaths: [ApiConstant.login, ApiConstant.register],
        skipRefreshPaths: [ApiConstant.revokeAllTokens],
        localeProvider: () => _prefs.getString(StorageKeys.locale) ?? 'en',
        // onForceLogout: () => getIt<AuthBloc>().add(const LogoutEvent()),
      ),

      // 5. Resolves per-path CacheOptions. Must sit immediately before the
      //    cache interceptor so the options are attached when it runs.
      if (_cacheRegistry != null) EndpointCacheInterceptor(_cacheRegistry),

      // 6. Cache BEFORE offline sync — on network error, serves stale cache.
      DioCacheInterceptor(
        options: _cacheRegistry?.fallback ?? CacheService.instance.defaultOptions,
      ),

      // 6. Retry BEFORE offline sync — exhaust retries first.
      RetryInterceptor(
        dio: dio,
        maxRetries: defaultMaxRetries,
        initialDelay: defaultRetryDelay,
      ),

      // 7. Only queues if cache also missed AND all retries failed.
      if (_syncQueue != null)
        OfflineSyncInterceptor(
          queue: _syncQueue,
          config: const OfflineSyncConfig(
            returnSyntheticResponse: false,
            excludedPaths: [
              ApiConstant.login,
              ApiConstant.verifyOtp,
              ApiConstant.logout,
              ApiConstant.refreshToken,
            ],
          ),
        ),

      if (kDebugMode)
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseHeader: true,
        ),
    ]);

    if (!kIsWeb) {
      dio.httpClientAdapter = _setupProxy();
    }

    return dio;
  }

  /// Creates a dedicated, lightweight Dio for [SyncServiceManager] to
  /// replay queued requests with. Only Auth + Retry — no duplicate
  /// detection, no cache, no offline-sync (avoids re-queue loops).
  ///
  /// AuthInterceptor here uses the same [refreshDio] cycle, so a stale
  /// token in a replay is auto-refreshed instead of failing the queue.
  Future<Dio> createReplayDio({
    int defaultMaxRetries = 3,
    Duration defaultRetryDelay = const Duration(seconds: 2),
  }) async {
    final baseOptions = BaseOptions(
      baseUrl: ApiConstant.baseUrl,
      followRedirects: true,
      receiveDataWhenStatusError: true,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Connection': 'keep-alive'},
    );

    final replayDio = Dio(baseOptions);
    final refreshDio = Dio(baseOptions);
    refreshDio.interceptors.add(
      RetryInterceptor(
        dio: refreshDio,
        maxRetries: defaultMaxRetries,
        initialDelay: defaultRetryDelay,
      ),
    );

    replayDio.interceptors.addAll([
      if (_onTelemetry != null) TelemetryInterceptor(onEvent: _onTelemetry),
      IdempotencyInterceptor(),
      AuthInterceptor(
        tokenStore: _tokenStore,
        dio: replayDio,
        refreshDio: refreshDio,
        onForceLogout: _onForceLogout,
        refreshPath: ApiConstant.refreshToken,
        publicPaths: [ApiConstant.login, ApiConstant.register],
        skipRefreshPaths: [ApiConstant.revokeAllTokens],
        localeProvider: () => _prefs.getString(StorageKeys.locale) ?? 'en',
        // onForceLogout: () => getIt<AuthBloc>().add(const LogoutEvent()),
      ),
      RetryInterceptor(
        dio: replayDio,
        maxRetries: defaultMaxRetries,
        initialDelay: defaultRetryDelay,
      ),
      if (kDebugMode) PrettyDioLogger(requestHeader: true, requestBody: true),
    ]);

    if (!kIsWeb) {
      replayDio.httpClientAdapter = _setupProxy();
    }
    return replayDio;
  }

  /// Configures HTTP client adapter with SSL settings
  ad.IOHttpClientAdapter _setupProxy() {
    return ad.IOHttpClientAdapter(
      createHttpClient: () {
        final client = io.HttpClient();
        // Prevent Connection Closed before full header was received
        client.idleTimeout = const Duration(seconds: 3);
        // Allow self-signed certificates in development
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      },
      validateCertificate: (cert, host, port) => true,
    );
  }
}
