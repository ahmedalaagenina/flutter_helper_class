import 'dart:async';

import 'package:dio/dio.dart';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:idara_tracking_app/core/util/log_scrubber.dart';

/// Crash reporting, with every credential removed on the way out.
///
/// ⛔ **Nothing reaches Crashlytics without passing through [LogScrubber].**
/// GPSWOX authenticates by query parameter, so `user_api_hash` — a permanent
/// fleet credential, see CLAUDE.md §0.3 — sits in every request URL and in any
/// string built from one. Dio's own `toString()` happens not to include the
/// URI today, but that is a detail of the current version, not a guarantee;
/// anything that interpolated `requestOptions.uri`, a wrapped error, or a
/// server body echoing the hash would carry it. Scrubbing is unconditional so
/// the guarantee does not depend on a dependency's formatting.
///
/// It also makes reports *useful*: see [describe].
abstract final class CrashReporter {
  /// Installs the global error handlers.
  ///
  /// Collection is **off in debug**: local crashes are already visible in the
  /// console, and uploading them pollutes the release signal.
  static Future<void> initialize() async {
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

    if (kDebugMode) return;

    // Framework errors — a failed build, a layout assertion.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      previousOnError?.call(details);
      unawaited(_recordFlutterError(details));
    };

    // Everything the framework did not catch: an async gap, a bloc handler, an
    // isolate. This is where DioExceptions surface, which is the leak that
    // matters most.
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(record(error, stack, fatal: true));
      return true;
    };
  }

  /// Records an error with its text scrubbed.
  ///
  /// [reason] is scrubbed too — a caller may have interpolated a URL into it.
  static Future<void> record(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (kDebugMode) return;

    await FirebaseCrashlytics.instance.recordError(
      _ScrubbedError.from(error),
      stack,
      reason: reason == null ? null : LogScrubber.scrub(reason),
      fatal: fatal,
    );
  }

  /// A breadcrumb. Scrubbed, because these are the most casually written
  /// strings in the codebase.
  static void log(String message) {
    if (kDebugMode) return;
    FirebaseCrashlytics.instance.log(LogScrubber.scrub(message));
  }

  /// The exact text this would send for [error]. Exposed for tests, so the
  /// guarantee can be asserted rather than assumed.
  @visibleForTesting
  static String describe(Object error) => _ScrubbedError.from(error).toString();

  static Future<void> _recordFlutterError(FlutterErrorDetails details) {
    return FirebaseCrashlytics.instance.recordError(
      _ScrubbedError.from(details.exception),
      details.stack,
      reason: details.context == null
          ? null
          : LogScrubber.scrub(details.context.toString()),
      fatal: true,
    );
  }
}

/// Stands in for the real error so Crashlytics never sees its `toString()`.
///
/// The original type name is kept in the message: Crashlytics groups by stack
/// trace, so nothing is lost by not being a `DioException`, but a report that
/// said only "scrubbed error" would be unreadable.
class _ScrubbedError implements Exception {
  const _ScrubbedError(this.type, this.message);

  factory _ScrubbedError.from(Object error) => error is DioException
      ? _ScrubbedError('DioException', _describeRequest(error))
      : _ScrubbedError(
          error.runtimeType.toString(),
          LogScrubber.scrub(error.toString()),
        );

  /// Describes a failed request without its credential.
  ///
  /// `DioException.toString()` is `DioException [bad response]: null` for most
  /// GPSWOX failures — the endpoint, the method and the status are all in
  /// `requestOptions`, and none of them survive the default. A report saying
  /// only "bad response" cannot be acted on.
  ///
  /// ⛔ Built from `path`, never `uri`. `uri` includes the query string, and
  /// on GPSWOX the query string is where the credential lives. The scrub at
  /// the end is a second line of defence, not the first.
  static String _describeRequest(DioException error) {
    final request = error.requestOptions;
    final status = error.response?.statusCode;

    return LogScrubber.scrub(
      [
        error.type.name,
        '${request.method} ${request.path}',
        if (status != null) 'HTTP $status',
        ?error.message,
      ].join(' · '),
    );
  }

  final String type;
  final String message;

  @override
  String toString() => '$type: $message';
}
