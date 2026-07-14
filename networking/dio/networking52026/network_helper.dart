import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart' as ad;
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:idara_driver/core/networking/networking.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../networking/api_constant.dart';

// Future<void> _registerNetworkStack() async {
//   // await Hive.initFlutter();
//   await CacheService.instance.init();

//   // Initialize and register SyncQueue
//   final syncQueue = SyncQueue();
//   await syncQueue.init();
//   getIt.registerLazySingleton<SyncQueue>(() => syncQueue);

//   getIt.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());
//   getIt.registerFactory(() => CancelToken());
//   getIt.registerLazySingleton<AuthTokenStore>(
//     () =>
//         AuthTokenStoreImpl(secureStorage: getIt(), sharedPreferences: getIt()),
//   );
//   getIt.registerSingletonAsync<Dio>(
//     () async =>
//         await NetworkHelper(getIt(), getIt(), syncQueue: syncQueue).createDio(),
//   );
//   getIt.registerSingletonWithDependencies<ApiService>(
//     () => ApiServiceImpl(getIt<Dio>()),
//     dependsOn: [Dio],
//   );

//   // SyncManager — starts after Dio is ready
//   getIt.registerSingletonWithDependencies<SyncServiceManager>(
//     () => SyncServiceManager(
//       dio: getIt<Dio>(),
//       queue: getIt<SyncQueue>(),
//       networkInfo: getIt<NetworkInfo>(),
//     ),
//     dependsOn: [Dio],
//   );

//   await getIt.isReady<Dio>();
//   await getIt.isReady<ApiService>();
//   await getIt.isReady<SyncServiceManager>();

//   // Start SyncManager
//   getIt<SyncServiceManager>().init();
// }

/// Helper class for creating and configuring Dio instances
class NetworkHelper {
  final AuthTokenStore _tokenStore;
  final SharedPreferences _prefs;
  final SyncQueue? _syncQueue;
  final void Function()? _onForceLogout;
  final void Function(TelemetryEvent)? _onTelemetry;

  NetworkHelper(
    this._tokenStore,
    this._prefs, {
    SyncQueue? syncQueue,
    void Function()? onForceLogout,
    void Function(TelemetryEvent)? onTelemetry,
  }) : _syncQueue = syncQueue,
       _onForceLogout = onForceLogout,
       _onTelemetry = onTelemetry;

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
        localeProvider: () => prefs.getString(StorageKeys.locale) ?? 'en',
        onForceLogout: () => getIt<AuthBloc>().add(const LogoutEvent()),
       )
     

      // 5. Cache BEFORE offline sync — on network error, serves stale cache.
      DioCacheInterceptor(options: CacheService.instance.defaultOptions),

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
          config: OfflineSyncConfig(
            returnSyntheticResponse: false,
            defaultOfflineMessage:
                'You are offline. Request queued and will sync automatically.',
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
        prefs: _prefs,
        tokenStore: _tokenStore,
        dio: replayDio,
        refreshDio: refreshDio,
        onForceLogout: _onForceLogout,
      ),
      RetryInterceptor(
        dio: replayDio,
        maxRetries: defaultMaxRetries,
        initialDelay: defaultRetryDelay,
      ),
      if (kDebugMode)
        PrettyDioLogger(requestHeader: true, requestBody: true),
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
