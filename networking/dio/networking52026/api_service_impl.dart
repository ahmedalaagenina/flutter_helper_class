import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:idara_driver/core/networking/networking.dart';

class ApiServiceImpl implements ApiService {
  final Dio _dio;

  ApiServiceImpl(this._dio);

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
    Map<String, dynamic>? files,
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
    RetryOptions? retryOptions,
  }) async {
    options = _mergeRetryOptions(options, retryOptions);

    options.extra!['recreateFormData'] = () => recreateFormData(files, data);

    // Stash a serializable spec so OfflineSyncInterceptor can persist this
    // upload across an app restart. Bytes-only files (web) are skipped
    // (can't survive Hive); pure-path uploads (mobile) are queueable.
    options.extra![OfflineSyncInterceptor.multipartSpecKey] =
        _buildMultipartSpec(files, data);

    final formData = await recreateFormData(files, data);

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

  /// Builds a JSON-serializable spec of a multipart request so that
  /// [OfflineSyncInterceptor] can persist it for later replay.
  ///
  /// File entries with a real `filePath` are recorded as
  /// `{'filePath': …, 'filename': …}`. Bytes-only files are recorded
  /// with a `null` filePath so the interceptor knows to skip the queue.
  Map<String, dynamic> _buildMultipartSpec(
    Map<String, dynamic>? files,
    Map<String, dynamic>? data,
  ) {
    final filesSpec = <String, dynamic>{};
    if (files != null) {
      for (final entry in files.entries) {
        filesSpec[entry.key] = _fileDataToSpec(entry.value);
      }
    }
    return {
      'files': filesSpec,
      // Only keep JSON-safe scalars/maps/lists from data; drop FileData.
      'data': _jsonSafeMap(data),
    };
  }

  Map<String, dynamic>? _fileDataToSpec(dynamic value) {
    if (value is FileData) {
      return {
        'filePath': value.filePath, // null on web/bytes — handled by capture
        'filename': value.filename,
        if (value.contentType != null)
          'contentType': [value.contentType!.$1, value.contentType!.$2],
      };
    }
    return null;
  }

  Map<String, dynamic>? _jsonSafeMap(Map<String, dynamic>? src) {
    if (src == null) return null;
    final out = <String, dynamic>{};
    for (final entry in src.entries) {
      final v = entry.value;
      if (v is FileData) continue; // dropped — captured in filesSpec
      out[entry.key] = v;
    }
    return out;
  }

  Future<FormData> recreateFormData(
    Map<String, dynamic>? files,
    Map<String, dynamic>? data,
  ) async {
    // Process files from the 'files' map
    final Map<String, dynamic> processedFiles = {};
    if (files != null) {
      for (var entry in files.entries) {
        processedFiles[entry.key] = await _processValue(entry.value);
      }
    }

    // Recursively process the 'data' map to find nested FileData
    final Map<String, dynamic> processedData = {};
    if (data != null) {
      for (var entry in data.entries) {
        processedData[entry.key] = await _processValue(entry.value);
      }
    }

    return FormData.fromMap({...processedData, ...processedFiles});
  }

  /// Recursively processes values to convert FileData to MultipartFile.
  Future<dynamic> _processValue(dynamic value) async {
    if (value is FileData) {
      return await _createMultipartFile(
        filePath: value.filePath,
        bytes: value.bytes,
        filename: value.filename,
        contentType: value.contentType,
      );
    } else if (value is Map<String, dynamic>) {
      final Map<String, dynamic> processedMap = {};
      for (var entry in value.entries) {
        processedMap[entry.key] = await _processValue(entry.value);
      }
      return processedMap;
    } else if (value is List) {
      return await Future.wait(value.map((i) => _processValue(i)));
    }
    return value;
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
    }

    return mergedOptions;
  }
}
