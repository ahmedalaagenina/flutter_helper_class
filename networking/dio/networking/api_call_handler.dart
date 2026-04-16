import 'package:dartz/dartz.dart';
import 'networking.dart';

typedef Data<T> = Either<AppFailure, T>;

enum DataSourceType { remote, cache }

class Result<T> {
  final Data<T> data;
  final DataSourceType source;

  const Result({required this.data, required this.source});

  bool get isFromRemote => source == DataSourceType.remote;
  bool get isFromCache => source == DataSourceType.cache;
  bool get isSuccess => data.isRight();
  bool get isFailure => data.isLeft();
  T? get value => data.fold((_) => null, (r) => r);
  AppFailure? get failure => data.fold((l) => l, (_) => null);
}

class ApiCallHandler {
  static Future<Result<T>> handle<T>({
    required NetworkInfo networkInfo,

    required Future<T> Function() remoteCall,
    Future<void> Function(T data)? cacheCall,
    T? Function()? getCachedData,
  }) async {
    final isConnected = await networkInfo.isConnected;
    if (!isConnected && getCachedData != null) {
      try {
        final cachedData = getCachedData();

        if (cachedData != null) {
          return Result<T>(
            data: Right(cachedData),
            source: DataSourceType.cache,
          );
        }
      } catch (_) {}

      return Result<T>(
        data: const Left(NetworkFailure('No internet connection')),
        source: DataSourceType.remote,
      );
    }
    try {
      final remoteData = await remoteCall();

      if (cacheCall != null) {
        try {
          await cacheCall(remoteData);
        } catch (_) {}
      }

      return Result<T>(data: Right(remoteData), source: DataSourceType.remote);
    } catch (error) {
      final failure = ApiFailureHandler.handle(error);
      if (getCachedData != null) {
        try {
          final cachedData = getCachedData();

          if (cachedData != null) {
            return Result<T>(
              data: Right(cachedData),
              source: DataSourceType.cache,
            );
          }
        } catch (_) {}
      }
      return Result<T>(data: Left(failure), source: DataSourceType.remote);
    }
  }
}
