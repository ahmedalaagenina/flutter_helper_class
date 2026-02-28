import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart' as ad;
import 'package:flutter/foundation.dart';
import 'package:idara_esign/config/env/app_config.dart';
import 'package:idara_esign/core/networking/networking.dart';
import 'package:idara_esign/core/security/secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

/// Helper class for creating and configuring Dio instances
class NetworkHelper {
  final AppConfig _config;
  final SecureStorage _secureStorage;

  NetworkHelper(this._config, this._secureStorage);

  Future<Dio> createDio({
    int defaultMaxRetries = 3,
    Duration defaultRetryDelay = const Duration(seconds: 2),
  }) async {
    final baseOptions = BaseOptions(
      baseUrl: _config.apiBaseUrl,
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
        maxRetries: 2,
        initialDelay: const Duration(seconds: 1),
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
        secureStorage: _secureStorage,
        dio: dio,
        refreshDio: refreshDio,
      ),
      CustomInterceptor(),
      RetryInterceptor(
        dio: dio,
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
