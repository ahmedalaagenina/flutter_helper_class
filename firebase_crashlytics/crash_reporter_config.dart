import 'package:flutter/foundation.dart';

import 'crash_description.dart';
import 'log_scrubber.dart';

/// Tuning knobs for `CrashReporter`.
///
/// Every field has a sensible default; the zero-config
/// `const CrashReporterConfig()` gives you scrubbed reporting of every Flutter
/// and platform error, off in debug.
@immutable
class CrashReporterConfig {
  const CrashReporterConfig({
    this.describers = const [],
    this.scrubber,
    this.collectionEnabled,
    this.catchFlutterErrors = true,
    this.catchPlatformErrors = true,
    this.flutterErrorsAreFatal = true,
    this.shouldReport,
    this.logger,
  });

  /// Error-specific formatters, tried in order; the first non-null wins.
  ///
  /// Reach for these when a default `toString()` hides what you need — Dio's,
  /// for instance, is `DioException [bad response]: null`:
  ///
  /// ```dart
  /// const CrashReporterConfig(describers: [describeDioError])
  /// ```
  ///
  /// Whatever a describer returns is scrubbed before it leaves the device, so
  /// the guarantee does not rest on the describer being careful.
  final List<ErrorDescriber> describers;

  /// The scrubber every outgoing string passes through.
  ///
  /// `null` means [LogScrubber.instance] — resolved per call, so assigning that
  /// static after `initialize` still takes effect.
  final LogScrubber? scrubber;

  /// Whether to upload at all. `null` means `!kDebugMode`.
  ///
  /// Debug is off by default because local crashes are already visible in the
  /// console, and uploading them pollutes the release signal. Set `true` only
  /// when you are deliberately testing the pipeline itself.
  final bool? collectionEnabled;

  /// Hook `FlutterError.onError` — a failed build, a layout assertion, an
  /// overflow. Any handler already installed is still called.
  final bool catchFlutterErrors;

  /// Hook `PlatformDispatcher.instance.onError` — everything the framework did
  /// not catch: an async gap, a bloc handler, a stream with no `onError`. This
  /// is where HTTP exceptions surface, which is the leak that matters most.
  final bool catchPlatformErrors;

  /// Whether framework errors are reported as fatal.
  ///
  /// `true` matches FlutterFire's own recommendation (`recordFlutterFatalError`)
  /// and keeps them out of the "non-fatal" bucket where nobody looks. Set
  /// `false` if a noisy widget makes them drown your crash-free-users metric.
  final bool flutterErrorsAreFatal;

  /// Last word on whether one error is worth uploading. `null` reports
  /// everything.
  ///
  /// For the errors that are a fact of mobile life rather than a bug:
  ///
  /// ```dart
  /// shouldReport: (error, stack) => error is! SocketException,
  /// ```
  final bool Function(Object error, StackTrace? stack)? shouldReport;

  /// Where reports go when they are *not* uploaded — in debug, or after
  /// [shouldReport] declines — and where internal failures are noted.
  ///
  /// Receives scrubbed text only. `logger: AppLog.e` is the usual wiring.
  final void Function(String message)? logger;

  CrashReporterConfig copyWith({
    List<ErrorDescriber>? describers,
    LogScrubber? scrubber,
    bool? collectionEnabled,
    bool? catchFlutterErrors,
    bool? catchPlatformErrors,
    bool? flutterErrorsAreFatal,
    bool Function(Object error, StackTrace? stack)? shouldReport,
    void Function(String message)? logger,
  }) {
    return CrashReporterConfig(
      describers: describers ?? this.describers,
      scrubber: scrubber ?? this.scrubber,
      collectionEnabled: collectionEnabled ?? this.collectionEnabled,
      catchFlutterErrors: catchFlutterErrors ?? this.catchFlutterErrors,
      catchPlatformErrors: catchPlatformErrors ?? this.catchPlatformErrors,
      flutterErrorsAreFatal: flutterErrorsAreFatal ?? this.flutterErrorsAreFatal,
      shouldReport: shouldReport ?? this.shouldReport,
      logger: logger ?? this.logger,
    );
  }
}
