import 'package:flutter/foundation.dart';

/// How one error type should read in a crash report.
///
/// Return one from an [ErrorDescriber] when a default `toString()` throws the
/// useful detail away. Both fields are scrubbed by `CrashReporter` before they
/// leave the device, so a describer may interpolate freely — but see the
/// warning on [ErrorDescriber] about which fields to reach for.
@immutable
class CrashDescription {
  const CrashDescription(this.type, this.message);

  /// The name shown before the colon, conventionally the error's class name.
  ///
  /// Kept because Crashlytics groups by stack trace, so nothing is lost by the
  /// reported object not literally being a `DioException` — but a report that
  /// said only "scrubbed error" would be unreadable.
  final String type;

  /// The one-line detail: what failed, where, with what status.
  final String message;

  @override
  String toString() => '$type: $message';
}

/// Turns one kind of error into a readable line, or returns `null` to pass.
///
/// `CrashReporter` tries its describers in order and falls back to
/// `error.toString()`.
///
/// ⛔ Build the message from the *parts* you want, never from a whole request
/// object. On an API that authenticates by query parameter, a URI is a
/// credential; a path is not. The scrub that follows is a second line of
/// defence, not the first.
typedef ErrorDescriber = CrashDescription? Function(Object error);
