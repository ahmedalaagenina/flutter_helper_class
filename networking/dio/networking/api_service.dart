import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:idara_esign/core/networking/networking.dart';

class ApiService implements IApiService {
  final Dio _dio;
  final int defaultMaxRetries;
  final Duration defaultRetryDelay;
  ApiService(
    this._dio, {
    this.defaultMaxRetries = 3,
    this.defaultRetryDelay = const Duration(seconds: 2),
  });

  /// Registering Dio and CancelToken
  //  getIt.registerLazySingleton(() => CancelToken());
  //  getIt
  //      .registerSingletonAsync<Dio>(() async => await NetworkHelper.createDio());

  //  getIt.registerSingletonWithDependencies<INetworkService>(
  //    () => NetworkService(getIt<Dio>(), getIt<CancelToken>()),
  //    dependsOn: [Dio],
  //  );
  /// in main.dart
  ///  WidgetsFlutterBinding.ensureInitialized();
  // setupServiceLocator();
  // await getIt.allReady();

  //? How to cancel request
  // CancelToken? _uploadCancelToken = CancelToken();
  // ! pass _uploadCancelToken to cancel in Call method
  // void cancelUpload() {
  //   _uploadCancelToken?.cancel('User cancelled the upload');
  // }

  // GET method
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
    RetryOptions? retryOptions,
  }) async {
    options = _mergeRetryOptions(options, retryOptions);
    final response = await _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
    return response;
  }

  // POST method
  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
    RetryOptions? retryOptions,
  }) async {
    options = _mergeRetryOptions(options, retryOptions);
    final response = await _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
    return response;
  }

  // PUT method
  @override
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
    RetryOptions? retryOptions,
  }) async {
    options = _mergeRetryOptions(options, retryOptions);
    final response = await _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
    return response;
  }

  // DELETE method
  @override
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    RetryOptions? retryOptions,
  }) async {
    options = _mergeRetryOptions(options, retryOptions);
    final response = await _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
    return response;
  }

  // PATCH method
  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
    RetryOptions? retryOptions,
  }) async {
    options = _mergeRetryOptions(options, retryOptions);
    final response = await _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
    return response;
  }

  // HEAD method
  @override
  Future<Response<T>> head<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    RetryOptions? retryOptions,
  }) async {
    options = _mergeRetryOptions(options, retryOptions);
    final response = await _dio.head<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
    return response;
  }

  // Example of file download
  // try {
  //   await apiService.download(
  //     'https://example.com/files/document.pdf',
  //     '/path/to/save/document.pdf',
  //     onReceiveProgress: (received, total) {
  //       if (total != -1) {
  //         final progress = (received / total * 100).toStringAsFixed(0);
  //         print('Download progress: $progress%');
  //       }
  //     },
  //   );
  //   print('File downloaded successfully');
  // } catch (e) {
  //   print('Error downloading file: $e');
  // }
  // Download file
  @override
  Future<Response> download(
    String urlPath,
    String savePath, {
    void Function(int, int)? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
    dynamic data,
    Options? options,
    RetryOptions? retryOptions,
  }) async {
    options = _mergeRetryOptions(options, retryOptions);
    final response = await _dio.download(
      urlPath,
      savePath,
      onReceiveProgress: onReceiveProgress,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      deleteOnError: deleteOnError,
      lengthHeader: lengthHeader,
      data: data,
      options: options,
    );
    return response;
  }

  // Example of multipart request for file upload
  // try {
  //   final response = await apiService.multipartRequest<Map<String, dynamic>>(
  //     '/upload',
  //     'POST',
  //     files: {'file': '/path/to/local/file.pdf'},
  //     data: {'description': 'My uploaded file'},
  //     onSendProgress: (sent, total) {
  //       final progress = (sent / total * 100).toStringAsFixed(0);
  //       print('Upload progress: $progress%');
  //     },
  //   );
  //   print('File uploaded successfully: ${response.data}');
  // } catch (e) {
  //   print('Error uploading file: $e');
  // }

  // OR

  //  final response = await apiClient.multipartRequest(
  //     ApiConstant.userSignatures,
  //     'POST',
  //     files: {
  //       'signature_file': FileData(
  //         filePath: kIsWeb ? null : signatureFilePath,
  //         bytes: kIsWeb ? signatureBytes : null,
  //         filename: signatureFilePath.split('/').last,
  //         contentType: 'image/png',
  //       ),
  //     },
  //     data: {
  //       'name': name,
  //       'signature_type': signatureType,
  //     },
  //   );

  // Multipart request helper

  @override
  Future<Response<T>> multipartRequest<T>(
    String path,
    MethodType methodType, {
    required Map<String, FileData> files,
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
    RetryOptions? retryOptions,
  }) async {
    options = _mergeRetryOptions(options, retryOptions);

    // Process files based on type
    final Map<String, dynamic> processedFiles = {};

    for (var entry in files.entries) {
      final key = entry.key;
      final value = entry.value;

      // Handle FileData object
      processedFiles[key] = await _createMultipartFile(
        filePath: value.filePath,
        bytes: value.bytes,
        filename: value.filename,
        contentType: value.contentType,
      );
    }

    final formData = FormData.fromMap({
      if (data != null) ...data,
      ...processedFiles,
    });

    final response = await _dio.request<T>(
      path,
      data: formData,
      queryParameters: queryParameters,
      options: options.copyWith(method: methodType.apiValue),
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
    return response;
  }

  /// Helper method to create MultipartFile based on platform
  Future<MultipartFile> _createMultipartFile({
    String? filePath,
    Uint8List? bytes,
    required String filename,
    (String, String)? contentType,
  }) async {
    DioMediaType? mediaType;
    if (contentType != null) {
      mediaType = DioMediaType(contentType.$1, contentType.$2);
    }

    if (kIsWeb || bytes != null) {
      // Web or explicit bytes
      return MultipartFile.fromBytes(
        bytes ?? [],
        filename: filename,
        contentType: mediaType,
      );
    } else if (filePath != null) {
      // Mobile with file path
      return await MultipartFile.fromFile(
        filePath,
        filename: filename,
        contentType: mediaType,
      );
    } else {
      throw ArgumentError('Either filePath or bytes must be provided');
    }
  }

  // Helper method to merge retry options
  Options _mergeRetryOptions(Options? options, RetryOptions? retryOptions) {
    final mergedOptions = options ?? Options();
    mergedOptions.extra ??= {};

    if (retryOptions != null) {
      mergedOptions.extra!['maxRetries'] = retryOptions.maxRetries;
      mergedOptions.extra!['retryDelay'] = retryOptions.retryDelay;
    } else if (!mergedOptions.extra!.containsKey('maxRetries')) {
      // Use default values if not specified
      mergedOptions.extra!['maxRetries'] = defaultMaxRetries;
      mergedOptions.extra!['retryDelay'] = defaultRetryDelay;
    }

    return mergedOptions;
  }

  //? Here's how to use each approach:
  //! 1. Automatic Retry (via Interceptor)
  // This happens automatically for all requests:
  // try {
  //   final response = await apiService.get('/endpoint',
  //       options: Options(extra: {'retryCount': 0}),); //? For handle Number of retries
  // Success
  // } catch (e) {
  // All retries failed
  // }

  //! 2. Manual Retry
  //* final cancelToken = CancelToken();
  // try {
  //   final response = await apiService.retryableRequest<Map<String, dynamic>>(
  //     '/complex-endpoint',
  //     method: 'POST', //! Must Be in uppercase
  //     data: {'key': 'value'},
  //     maxRetries: 5, //! Max Retries
  //     retryDelay: Duration(seconds: 2),
  //     cancelToken: cancelToken,
  //     retryCondition: (error) {
  //       if (error.response?.statusCode == 429) { // Too Many Requests
  //         final retryAfter = error.response?.headers['retry-after']?.first;
  //         if (retryAfter != null) {
  //           final seconds = int.tryParse(retryAfter);
  //           if (seconds != null) {
  //             return true;
  //           }
  //         }
  //       }
  //       return error.type == DioExceptionType.connectionTimeout;
  //     },
  //     onRetry: (attemptNumber, exception) {
  //       if (attemptNumber == 3) {
  //         cancelToken.cancel('Cancelling after 3 retries');
  //       }
  //     },
  //   );

  //   print('Success: ${response.data}');
  // } catch (e) {
  //   print('Failed: $e');
  // }

  // Retry request for manual retry
  @override
  Future<Response<T>> retryableRequest<T>(
    String path, {
    MethodType methodType = MethodType.get,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    int maxRetries = 3,
    Duration? retryDelay,
    bool Function(DioException)? retryCondition,
    void Function(int, Exception)? onRetry,
  }) async {
    int attempts = 0;
    late Exception lastException;

    while (attempts < maxRetries) {
      try {
        final response = await _dio.request<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options:
              options?.copyWith(method: methodType.apiValue) ??
              Options(method: methodType.apiValue),
          cancelToken: cancelToken,
        );
        return response;
      } on DioException catch (e) {
        lastException = e;
        attempts++;

        final shouldRetry =
            retryCondition?.call(e) ?? _defaultRetryCondition(e);

        if (!shouldRetry || attempts >= maxRetries) {
          rethrow;
        }

        onRetry?.call(attempts, e);

        if (retryDelay != null) {
          await Future.delayed(retryDelay);
        }
      }
    }

    throw lastException;
  }

  bool _defaultRetryCondition(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        (!kIsWeb && error.error is SocketException) ||
        (error.response?.statusCode != null &&
            error.response!.statusCode! >= 500);
  }
}
