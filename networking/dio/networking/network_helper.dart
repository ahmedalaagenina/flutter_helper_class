import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart' as ad;
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:idara_driver/core/networking/networking.dart';
import 'package:idara_driver/core/networking/offline_sync/offline_sync.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Future<void> _registerNetworkStack() async {
//// call in local storage get it
//   await Hive.initFlutter();
//     final box = await Hive.openBox('app_box');
//     getIt.registerLazySingleton<Box>(() => box);
//   getIt.registerLazySingleton<LocalStorageApiService>(
//     () => HiveLocalStorageApiService(getIt()),
//   );
/// this cash about api response
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

  NetworkHelper(this._tokenStore, this._prefs, {SyncQueue? syncQueue})
    : _syncQueue = syncQueue;

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

    // Add interceptors in order
    dio.interceptors.addAll([
      AuthInterceptor(
        prefs: _prefs,
        tokenStore: _tokenStore,
        dio: dio,
        refreshDio: refreshDio,
      ),
      RetryInterceptor(
        dio: dio,
        maxRetries: defaultMaxRetries,
        initialDelay: defaultRetryDelay,
      ),
      if (_syncQueue != null)
        OfflineSyncInterceptor(
          queue: _syncQueue,
          config: OfflineSyncConfig(
            excludedPaths: [
              ApiConstant.requestOtp,
              ApiConstant.verifyOtp,
              ApiConstant.resendOtp,
              ApiConstant.logout,
              ApiConstant.refreshToken,
            ],
          ),
        ),
      DioCacheInterceptor(options: CacheService.instance.defaultOptions),

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
