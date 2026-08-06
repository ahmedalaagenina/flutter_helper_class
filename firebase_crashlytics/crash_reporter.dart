import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'crash_description.dart';
import 'crash_reporter_config.dart';
import 'log_scrubber.dart';

/// Crash reporting, with every credential removed on the way out.
///
/// ⛔ **Nothing reaches Crashlytics without passing through a [LogScrubber].**
/// Error strings are built for a console, not for upload: an HTTP exception can
/// carry the URL that failed, and on an API that authenticates by query
/// parameter that URL *is* a credential. Whether a given client's `toString()`
/// includes the URI today is a detail of its current version, not a promise, so
/// the scrub is unconditional — the guarantee must not depend on a
/// dependency's formatting.
///
/// It also makes reports *useful*: see [CrashReporterConfig.describers].
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
///   await CrashReporter.initialize();
///   runApp(const MyApp());
/// }
/// ```
abstract final class CrashReporter {
  static CrashReporterConfig _config = const CrashReporterConfig();
  static bool _enabled = false;
  static bool _handlersInstalled = false;

  /// The active configuration. `initialize` has not run until this is replaced.
  static CrashReporterConfig get config => _config;

  /// Whether reports are being uploaded. `false` in debug unless
  /// [CrashReporterConfig.collectionEnabled] says otherwise.
  static bool get isEnabled => _enabled;

  static LogScrubber get _scrubber => _config.scrubber ?? LogScrubber.instance;

  /// Installs the global error handlers. Call after `Firebase.initializeApp`.
  ///
  /// Safe to call again to swap configuration — the handlers are only installed
  /// once, so a second call re-points the reporter without stacking hooks.
  static Future<void> initialize({
    CrashReporterConfig config = const CrashReporterConfig(),
  }) async {
    _config = config;
    _enabled = config.collectionEnabled ?? !kDebugMode;

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(_enabled);

    // Nothing is installed while disabled, deliberately. Claiming
    // `PlatformDispatcher.onError` and returning `true` marks the error handled
    // and stops the default handler printing it — which would make a debug run
    // quieter than one with no crash reporting at all.
    if (!_enabled || _handlersInstalled) return;
    _handlersInstalled = true;

    if (config.catchFlutterErrors) {
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        previousOnError?.call(details);
        unawaited(recordFlutterError(details));
      };
    }

    if (config.catchPlatformErrors) {
      final previousOnError = PlatformDispatcher.instance.onError;
      PlatformDispatcher.instance.onError = (error, stack) {
        unawaited(record(error, stack, fatal: true));
        // Defer to whoever was there before; otherwise report it as handled.
        return previousOnError?.call(error, stack) ?? true;
      };
    }
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
    if (!_enabled || !(_config.shouldReport?.call(error, stack) ?? true)) {
      final logger = _config.logger;
      if (logger != null) {
        logger(
          [_describe(error).toString(), ?_scrubber.scrubOrNull(reason)].join(' — '),
        );
      }
      return;
    }

    final safeReason = _scrubber.scrubOrNull(reason);
    final description = _describe(error);

    // A throw here would come from inside an error handler — an uninitialized
    // Firebase, a plugin missing on this platform. Swallow it, or the report of
    // a crash becomes a crash.
    try {
      await FirebaseCrashlytics.instance.recordError(
        description,
        stack,
        reason: safeReason,
        fatal: fatal,
      );
    } catch (failure) {
      _config.logger?.call('CrashReporter could not report: $failure');
    }
  }

  /// Records a framework error — a failed build, a layout assertion.
  ///
  /// Called for you when [CrashReporterConfig.catchFlutterErrors] is on. Call
  /// it yourself from a custom `FlutterError.onError`, or from an
  /// `ErrorWidget.builder`.
  static Future<void> recordFlutterError(FlutterErrorDetails details) {
    return record(
      details.exception,
      details.stack,
      reason: details.context?.toString(),
      fatal: _config.flutterErrorsAreFatal,
    );
  }

  /// A breadcrumb. Scrubbed, because these are the most casually written
  /// strings in the codebase.
  static void log(String message) {
    if (!_enabled) {
      final logger = _config.logger;
      if (logger != null) logger(_scrubber.scrub(message));
      return;
    }
    FirebaseCrashlytics.instance.log(_scrubber.scrub(message));
  }

  /// Attaches a key to every later report — a screen name, a feature flag, the
  /// id of the record being edited.
  ///
  /// A sensitive [key] (`api_key`, `authorization`, …) has its value dropped
  /// entirely rather than scrubbed; string values are scrubbed.
  static Future<void> setCustomKey(String key, Object value) async {
    if (!_enabled) return;
    final scrubber = _scrubber;
    final safe = scrubber.isSensitiveKey(key)
        ? scrubber.redacted
        : value is String
        ? scrubber.scrub(value)
        : value;
    await FirebaseCrashlytics.instance.setCustomKey(key, safe);
  }

  /// Ties reports to an account, so one user's crashes can be found.
  ///
  /// Pass an opaque id — never an email, phone number or session token. Clear
  /// it with `''` on sign-out.
  static Future<void> setUserIdentifier(String identifier) async {
    if (!_enabled) return;
    await FirebaseCrashlytics.instance.setUserIdentifier(
      _scrubber.scrub(identifier),
    );
  }

  /// Turns collection on or off after startup — for a privacy setting, or a
  /// consent prompt.
  static Future<void> setCollectionEnabled(bool enabled) async {
    _enabled = enabled;
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
  }

  /// The exact text this would send for [error]. Exposed for tests, so the
  /// guarantee can be asserted rather than assumed.
  ///
  /// ```dart
  /// expect(
  ///   LogScrubber.instance.looksSensitive(CrashReporter.describe(error)),
  ///   isFalse,
  /// );
  /// ```
  @visibleForTesting
  static String describe(Object error) => _describe(error).toString();

  /// Wraps [error] so Crashlytics never sees its own `toString()`.
  ///
  /// The scrub happens here, once, on whatever a describer produced — so a
  /// describer cannot forget it.
  static _ScrubbedError _describe(Object error) {
    final scrubber = _scrubber;

    for (final describer in _config.describers) {
      final description = describer(error);
      if (description != null) {
        return _ScrubbedError(
          description.type,
          scrubber.scrub(description.message),
        );
      }
    }

    return _ScrubbedError(
      error.runtimeType.toString(),
      scrubber.scrub(error.toString()),
    );
  }
}

/// Stands in for the real error so its raw text can never be uploaded.
///
/// The original type name is kept in the message: Crashlytics groups by stack
/// trace, so nothing is lost by the reported object not literally being a
/// `DioException`, but a report that said only "scrubbed error" would be
/// unreadable.
class _ScrubbedError implements Exception {
  const _ScrubbedError(this.type, this.message);

  final String type;
  final String message;

  @override
  String toString() => message.isEmpty ? type : '$type: $message';
}
