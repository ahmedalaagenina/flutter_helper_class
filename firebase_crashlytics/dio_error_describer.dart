import 'package:dio/dio.dart';

import 'crash_description.dart';

/// Describes a failed Dio request without its credential.
///
/// Not exported from `crash_reporting.dart` — it is the one file here that
/// needs `dio`. Wire it up explicitly, and delete the file if you use another
/// HTTP client:
///
/// ```dart
/// CrashReporter.initialize(
///   config: const CrashReporterConfig(describers: [describeDioError]),
/// );
/// ```
///
/// ## Why it exists
///
/// `DioException.toString()` is `DioException [bad response]: null` for most
/// failures — the endpoint, the method and the status all live on
/// `requestOptions`, and none of them survive the default. A report saying only
/// "bad response" cannot be acted on.
///
/// ⛔ Built from `path`, never `uri`. `uri` includes the query string, and on an
/// API that authenticates by query parameter the query string is where the
/// credential lives. Response bodies are left out for the same reason: they
/// echo back whatever was sent, plus whatever the account owns.
CrashDescription? describeDioError(Object error) {
  if (error is! DioException) return null;

  final request = error.requestOptions;
  final status = error.response?.statusCode;

  return CrashDescription(
    'DioException',
    [
      error.type.name,
      '${request.method} ${request.path}',
      if (status != null) 'HTTP $status',
      ?error.message,
    ].join(' · '),
  );
}
