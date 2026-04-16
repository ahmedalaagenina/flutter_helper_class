import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:idara_driver/core/networking/networking.dart';

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final bool shouldRetryOnTimeout;

  final safeMethods = [
    MethodType.post.apiValue,
    MethodType.get.apiValue,
    MethodType.put.apiValue,
    MethodType.delete.apiValue,
    MethodType.head.apiValue,
    MethodType.options.apiValue,
  ];

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.shouldRetryOnTimeout = true,
  });

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final extraMap = err.requestOptions.extra;
    final retryCount = extraMap['retryCount'] ?? 0;
    final maxRetries = extraMap['maxRetries'] ?? this.maxRetries;
    final retryDelay = extraMap['retryDelay'] ?? initialDelay;

    if (_shouldRetry(err) && retryCount < maxRetries) {
      final serverRequestedDelay = _getRetryAfterDelay(err.response);
      final delay =
          serverRequestedDelay ?? _calculateDelay(retryCount, retryDelay);
      err.requestOptions.extra['retryCount'] = retryCount + 1;

      debugPrint(
        'RetryInterceptor: Retrying [${err.requestOptions.path}] - '
        'Attempt ${retryCount + 1} after ${delay.inMilliseconds}ms',
      );

      await Future.delayed(delay);

      try {
        final response = await dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } on DioException catch (e) {
        return handler.next(e);
      }
    }

    return handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    final method = err.requestOptions.method.toUpperCase();
    final isSafeMethod = safeMethods.contains(method);

    if (shouldRetryOnTimeout &&
        err.type == DioExceptionType.connectionTimeout) {
      return true;
    }

    // Receive Timeout (The reply arrived but was delayed, it's dangerous to retry the POST)
    if (err.type == DioExceptionType.receiveTimeout && isSafeMethod) {
      return true;
    }

    if (!kIsWeb && err.error is SocketException) {
      return true;
    }
    if (err.response?.statusCode == 429) {
      return true;
    }
    if (err.response?.statusCode != null &&
        err.response!.statusCode! >= 500 &&
        isSafeMethod) {
      return true;
    }

    return false;
  }

  Duration? _getRetryAfterDelay(Response? response) {
    if (response == null) return null;

    var retryAfterHeader = response.headers.value('retry-after');
    retryAfterHeader ??= response.headers.value('retry_after');
    if (retryAfterHeader == null) return null;
    final intSeconds = int.tryParse(retryAfterHeader);
    if (intSeconds != null) {
      return Duration(seconds: intSeconds);
    }
    try {
      final date = HttpDate.parse(retryAfterHeader);
      final difference = date.difference(DateTime.now().toUtc());
      return difference.isNegative ? Duration.zero : difference;
    } catch (e) {
      debugPrint('Failed to parse Retry-After header: $e');
      return null;
    }
  }

  Duration _calculateDelay(int retryCount, Duration baseDelay) {
    // Exponential backoff with jitter
    final exponentialDelay = baseDelay * (pow(2, retryCount) as int);
    // The jitter here makes the time between 50% and 100% of the exponential delay
    final withJitter = exponentialDelay * (0.5 + Random().nextDouble() / 2);

    return Duration(
      milliseconds: min(withJitter.inMilliseconds, maxDelay.inMilliseconds),
    );
  }
}
