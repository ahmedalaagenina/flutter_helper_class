import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:idara_driver/core/networking/networking.dart';
import 'package:idara_driver/core/util/app_log.dart';

typedef Data<T> = Either<AppFailure, T>;

enum DataSourceType { remote, cache, offlineQueued }

class Result<T> {
  final Data<T> data;
  final DataSourceType source;

  const Result({required this.data, required this.source});

  bool get isFromRemote => source == DataSourceType.remote;
  bool get isFromCache => source == DataSourceType.cache;
  bool get isOfflineQueued => source == DataSourceType.offlineQueued;
  bool get isSuccess => data.isRight();
  bool get isFailure => data.isLeft();

  T? get value => data.fold((_) => null, (r) => r);
  AppFailure? get failure => data.fold((l) => l, (_) => null);

  /// Convenience: true when queued offline OR succeeded from remote/cache
  bool get isActionable => isSuccess || isOfflineQueued;

  @override
  String toString() => 'Result(source: $source, data: $data)';
}

class ApiCallHandler {
  ApiCallHandler._();

  static Future<Result<T>> handleRead<T>({
    // if null it will use the DioCacheInterceptor to cache the response
    // and if it not null will depend on the HiveCacheService
    NetworkInfo? networkInfo,
    required Future<T> Function() remoteCall,
    Future<void> Function(T data)? cacheCall,
    Future<T?> Function()? getCachedData,
  }) async {
    final isConnected = await networkInfo?.isConnected;

    if (isConnected == false) {
      return _resolveCache<T>(
        getCachedData: getCachedData,
        fallback: const NetworkFailure(),
      );
    }

    try {
      final remoteData = await remoteCall();
      await _runCacheCall(cacheCall, remoteData);
      return Result<T>(data: Right(remoteData), source: DataSourceType.remote);
    } catch (error) {
      final failure = ApiFailureHandler.handle(error);
      return _resolveCache<T>(getCachedData: getCachedData, fallback: failure);
    }
  }

  static Future<Result<T>> handleWrite<T>({
    required Future<T> Function() remoteCall,
    Future<void> Function(T data)? cacheCall,

    /// this for optimstic update when the request is offline Queued must make (returnSyntheticResponse == false in OfflineSyncInterceptor)
    Future<void> Function()? optimisticCacheCall,
  }) async {
    try {
      final remoteData = await remoteCall();
      await _runCacheCall(cacheCall, remoteData);
      return Result<T>(data: Right(remoteData), source: DataSourceType.remote);
    } on DioException catch (dioError) {
      /// all of this code is for notify the ui that the request is offline Queued must
      /// make (returnSyntheticResponse == false in OfflineSyncInterceptor)
      ///

      ///
      /// without it the code will work but ui will not know that the request is offline Queued must
      /// make (returnSyntheticResponse == true in OfflineSyncInterceptor)
      /// and optimisticCacheCall will not call
      if (_isOfflineError(dioError)) {
        if (optimisticCacheCall != null) {
          try {
            await optimisticCacheCall();
            AppLog.i(
              '[ApiCallHandler.handleWrite] Optimistic cache applied. '
              '${dioError.requestOptions.method} ${dioError.requestOptions.path}',
            );
          } catch (e) {
            AppLog.e(
              '[ApiCallHandler.handleWrite] optimisticCacheCall failed: $e',
            );
          }
        }

        final syncId = dioError.requestOptions.extra['_syncId'] as String?;
        final offlineMessage =
            dioError.requestOptions.extra[OfflineSyncInterceptor
                    .offlineMessageKey]
                as String?;
        AppLog.w(
          '[ApiCallHandler.handleWrite] Offline — queued. syncId: $syncId | '
          '${dioError.requestOptions.method} ${dioError.requestOptions.path}',
        );
        return Result<T>(
          data: Left(
            OfflineQueuedFailure(
              syncId: syncId,
              message:
                  offlineMessage ??
                  'You are offline. Request queued and will sync automatically.',
            ),
          ),
          source: DataSourceType.offlineQueued,
        );
      }

      final failure = ApiFailureHandler.handle(dioError);
      return Result<T>(data: Left(failure), source: DataSourceType.remote);
    } catch (error) {
      AppLog.e('[ApiCallHandler.handleWrite] Unexpected error: $error');
      final failure = ApiFailureHandler.handle(error);
      return Result<T>(data: Left(failure), source: DataSourceType.remote);
    }
  }

  static Future<Result<T>> _resolveCache<T>({
    Future<T?> Function()? getCachedData,
    required AppFailure fallback,
  }) async {
    if (getCachedData != null) {
      try {
        final cached = await getCachedData();
        if (cached != null) {
          return Result<T>(data: Right(cached), source: DataSourceType.cache);
        }
      } catch (e) {
        AppLog.e('[ApiCallHandler._resolveCache] Read failed: $e');
      }
    }
    return Result<T>(data: Left(fallback), source: DataSourceType.remote);
  }

  static Future<void> _runCacheCall<T>(
    Future<void> Function(T data)? cacheCall,
    T data,
  ) async {
    if (cacheCall == null) return;
    try {
      await cacheCall(data);
    } catch (e) {
      AppLog.e('[ApiCallHandler._runCacheCall] Write failed: $e');
    }
  }

  static bool _isOfflineError(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout) return true;
    if (err.type == DioExceptionType.sendTimeout) return true;
    if (err.type == DioExceptionType.connectionError) return true;
    if (!kIsWeb &&
        err.type == DioExceptionType.unknown &&
        err.error is SocketException) {
      return true;
    }
    return false;
  }
}
