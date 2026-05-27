import 'package:dio/dio.dart';

/// A single network request observation, emitted by [TelemetryInterceptor]
/// when a request completes (success OR failure).
///
/// Hook this into your analytics / crash reporter / Grafana exporter to get
/// production observability without `debugPrint`.
class TelemetryEvent {
  /// HTTP method (uppercase): GET, POST, …
  final String method;

  /// Path relative to baseUrl. Query string excluded — log it separately
  /// via [queryParameters] if needed (PII risk).
  final String path;

  /// Final HTTP status code. `0` if no response was received (network error).
  final int statusCode;

  /// `true` if [statusCode] is 2xx.
  final bool ok;

  /// Total wall-clock time from request start to completion.
  final Duration duration;

  /// Number of retry attempts performed by [RetryInterceptor].
  /// `0` = succeeded on first try.
  final int retryCount;

  /// `true` if this was an offline-sync replay.
  final bool wasReplay;

  /// Dio error type when [ok] is false, otherwise `null`.
  final DioExceptionType? errorType;

  /// Optional — query params, **not** body (body can be huge / sensitive).
  final Map<String, dynamic>? queryParameters;

  const TelemetryEvent({
    required this.method,
    required this.path,
    required this.statusCode,
    required this.ok,
    required this.duration,
    required this.retryCount,
    required this.wasReplay,
    this.errorType,
    this.queryParameters,
  });

  @override
  String toString() =>
      'TelemetryEvent($method $path → $statusCode in ${duration.inMilliseconds}ms'
      '${retryCount > 0 ? ", retries=$retryCount" : ""}'
      '${wasReplay ? ", replay" : ""}'
      '${errorType != null ? ", err=$errorType" : ""})';
}

/// Stamps a request-start timestamp on every outgoing request, then emits a
/// [TelemetryEvent] on response or error.
///
/// Place at the **top** of the interceptor chain so it observes everything
/// (retries, cache hits, refresh roundtrips). Cache hits emit
/// `Response.statusCode` from cache (typically 200 or 304).
class TelemetryInterceptor extends Interceptor {
  final void Function(TelemetryEvent event) onEvent;

  static const _startKey = '_telemetry_start';

  TelemetryInterceptor({required this.onEvent});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now().microsecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _emit(
      response.requestOptions,
      statusCode: response.statusCode ?? 0,
      errorType: null,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _emit(
      err.requestOptions,
      statusCode: err.response?.statusCode ?? 0,
      errorType: err.type,
    );
    handler.next(err);
  }

  void _emit(
    RequestOptions options, {
    required int statusCode,
    required DioExceptionType? errorType,
  }) {
    final startMicros = options.extra[_startKey] as int?;
    final duration = startMicros == null
        ? Duration.zero
        : Duration(
            microseconds:
                DateTime.now().microsecondsSinceEpoch - startMicros,
          );

    try {
      onEvent(
        TelemetryEvent(
          method: options.method.toUpperCase(),
          path: options.path,
          statusCode: statusCode,
          ok: statusCode >= 200 && statusCode < 300,
          duration: duration,
          retryCount: (options.extra['retryCount'] as int?) ?? 0,
          wasReplay: options.extra['_isOfflineReplay'] == true,
          errorType: errorType,
          queryParameters: options.queryParameters.isEmpty
              ? null
              : options.queryParameters,
        ),
      );
    } catch (_) {
      // Telemetry must never break the request pipeline.
    }
  }
}
