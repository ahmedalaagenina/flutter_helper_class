import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:idara_tracking_app/core/networking/networking.dart';
import 'package:idara_tracking_app/core/util/app_log.dart';

typedef Data<T> = Either<AppFailure, T>;

enum DataSourceType { remote, cache, offlineQueued }

/// Which sources a read may pull from, and in what order.
///
/// This governs the **local Hive store only** — i.e. the [LocalStorageApiService]
/// reached through `getCachedData` / `cacheCall`. The HTTP response cache
/// ([DioCacheInterceptor]) is a separate layer, controlled by `CachePolicy`
/// at the `api.get(...)` call site inside `remoteCall`. See
/// [CacheService.networkOnly], [CacheService.cacheFirst] and
/// [CacheService.refreshAndStore] for ready-made policies.
enum CacheMode {
  /// Network first; falls back to Hive when offline or the request fails.
  remoteFirst,

  /// Hive first; only requests the network when Hive has nothing stored.
  cacheFirst,

  /// Network only — Hive is never read, not even on failure.
  remoteOnly,

  /// Hive only — the network is never touched and `remoteCall` never runs.
  cacheOnly,
}

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
    /// Optional pre-flight connectivity gate. When supplied and the device is
    /// offline, the read short-circuits to the Hive store without ever
    /// reaching Dio — which also means [DioCacheInterceptor] gets no chance to
    /// serve its stored copy. When null, `remoteCall` always runs and the
    /// interceptor chain (HTTP cache, retry, offline sync) handles failure.
    ///
    /// Note this selects *when to skip the network*, not *which cache is used*.
    NetworkInfo? networkInfo,

    /// If true (default false), `handleRead` runs a real reachability
    /// probe (HEAD to NetworkInfoImpl.pingUrl) instead of trusting the
    /// OS-level connectivity flag. Slower but defeats captive portals.
    bool verifyReachability = false,

    /// Where this read is allowed to source its data from. Governs the Hive
    /// store only — see [CacheMode].
    CacheMode mode = CacheMode.remoteFirst,

    /// When false, a successful remote read is *not* written back to Hive.
    /// Use for reads you want to serve fresh but never persist.
    bool writeToCache = true,
    required Future<T> Function() remoteCall,
    Future<void> Function(T data)? cacheCall,
    Future<T?> Function()? getCachedData,
  }) async {
    if (mode == CacheMode.cacheOnly) {
      return _resolveCache<T>(
        getCachedData: getCachedData,
        fallback: const NoCachedDataFailure(),
      );
    }

    if (mode == CacheMode.cacheFirst) {
      final cached = await _readCache(getCachedData);
      if (cached != null) {
        return Result<T>(data: Right(cached), source: DataSourceType.cache);
      }
    }

    final bool? online = networkInfo == null
        ? null
        : (verifyReachability
              ? await networkInfo.hasInternetAccess
              : await networkInfo.isConnected);

    if (online == false) {
      return _fallback<T>(mode, getCachedData, const NetworkFailure());
    }

    try {
      final remoteData = await remoteCall();
      if (writeToCache) await _runCacheCall(cacheCall, remoteData);
      return Result<T>(data: Right(remoteData), source: DataSourceType.remote);
    } catch (error) {
      final failure = ApiFailureHandler.handle(error);
      return _fallback<T>(mode, getCachedData, failure);
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
      // Silently drop duplicate in-flight requests — BaseBloc.safeHandle
      // will intercept DuplicateRequestFailure and emit nothing.
      if (dioError.message == DuplicateRequestInterceptor.duplicateMessage) {
        return Result<T>(
          data: Left(const DuplicateRequestFailure()),
          source: DataSourceType.remote,
        );
      }

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

  /// Reads the Hive store, swallowing store errors as a miss.
  static Future<T?> _readCache<T>(Future<T?> Function()? getCachedData) async {
    if (getCachedData == null) return null;
    try {
      return await getCachedData();
    } catch (e) {
      AppLog.e('[ApiCallHandler._readCache] Read failed: $e');
      return null;
    }
  }

  static Future<Result<T>> _resolveCache<T>({
    Future<T?> Function()? getCachedData,
    required AppFailure fallback,
  }) async {
    final cached = await _readCache(getCachedData);
    if (cached != null) {
      return Result<T>(data: Right(cached), source: DataSourceType.cache);
    }
    return Result<T>(data: Left(fallback), source: DataSourceType.remote);
  }

  /// Post-failure fallback. [CacheMode.remoteOnly] surfaces the failure as-is;
  /// every other mode gets one chance at the Hive store first.
  static Future<Result<T>> _fallback<T>(
    CacheMode mode,
    Future<T?> Function()? getCachedData,
    AppFailure failure,
  ) async {
    if (mode == CacheMode.remoteOnly) {
      return Result<T>(data: Left(failure), source: DataSourceType.remote);
    }
    return _resolveCache<T>(getCachedData: getCachedData, fallback: failure);
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
