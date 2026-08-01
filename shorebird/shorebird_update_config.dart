import 'package:flutter/widgets.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'shorebird_update_options.dart';
import 'shorebird_update_state.dart';
import 'shorebird_update_strings.dart';

/// Tuning knobs for `ShorebirdUpdateManager`.
///
/// Every field has a sensible default; the zero-config
/// `const ShorebirdUpdateConfig()` gives you silent background patching.
@immutable
class ShorebirdUpdateConfig {
  const ShorebirdUpdateConfig({
    this.mode = ShorebirdUpdateMode.silent,
    this.promptStyle = ShorebirdPromptStyle.banner,
    this.track = UpdateTrack.stable,
    this.checkOnStart = true,
    this.checkOnResume = true,
    this.startDelay = const Duration(seconds: 2),
    this.minCheckInterval = const Duration(minutes: 30),
    this.maxRetries = 2,
    this.retryBackoff = const Duration(seconds: 5),
    this.strings = const ShorebirdUpdateStrings(),
    this.stringsBuilder,
    this.onRestartRequested,
    this.onStateChanged,
    this.onError,
    this.logger,
  });

  final ShorebirdUpdateMode mode;

  /// Banner or modal dialog, applied to every prompt this manager shows.
  /// Ignored in [ShorebirdUpdateMode.silent].
  final ShorebirdPromptStyle promptStyle;

  /// Which Shorebird track to pull patches from (`stable`, `beta`, `staging`,
  /// or any custom track you patched to).
  final UpdateTrack track;

  /// Check once shortly after `ShorebirdUpdateManager.initialize`.
  final bool checkOnStart;

  /// Re-check whenever the app returns to the foreground, subject to
  /// [minCheckInterval].
  final bool checkOnResume;

  /// Delay before the first check, so the network is not contended during
  /// app startup.
  final Duration startDelay;

  /// Shortest gap between two automatic checks. Manual
  /// `ShorebirdUpdateManager.checkForUpdate` calls with `force: true` ignore it.
  final Duration minCheckInterval;

  /// Extra download attempts after a failure.
  final int maxRetries;

  /// Base delay between download attempts; grows linearly per attempt.
  final Duration retryBackoff;

  /// Static strings. Ignored when [stringsBuilder] is provided.
  final ShorebirdUpdateStrings strings;

  /// Resolves strings from a [BuildContext] each time a prompt is shown.
  ///
  /// Prefer this over [strings] in a localized app: it runs while the app is
  /// mounted, so `S.of(context)` is valid and the prompt follows the user's
  /// current language even if they switch it mid-session.
  ///
  /// ```dart
  /// stringsBuilder: (context) => ShorebirdUpdateStrings(
  ///   readyToApply: S.of(context).updateReadyBody,
  ///   restartNow: S.of(context).updateRestartNow,
  /// ),
  /// ```
  final ShorebirdUpdateStrings Function(BuildContext context)? stringsBuilder;

  /// Invoked when the user asks to apply a downloaded patch.
  ///
  /// A Shorebird patch is only picked up when the **process** starts, so
  /// rebuilding the widget tree does nothing. Leave this `null` and the manager
  /// will simply tell the user the update applies on next launch. Provide it
  /// (e.g. wired to a package that relaunches the process) if you want a real
  /// "restart now" button.
  final VoidCallback? onRestartRequested;

  /// Convenience hook mirroring `ShorebirdUpdateManager.state`.
  final ValueChanged<ShorebirdUpdateState>? onStateChanged;

  /// Report failures to Crashlytics/Sentry.
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Route internal logs into your own logger. Defaults to `dart:developer`.
  final void Function(String message)? logger;

  ShorebirdUpdateConfig copyWith({
    ShorebirdUpdateMode? mode,
    ShorebirdPromptStyle? promptStyle,
    UpdateTrack? track,
  }) {
    return ShorebirdUpdateConfig(
      mode: mode ?? this.mode,
      promptStyle: promptStyle ?? this.promptStyle,
      track: track ?? this.track,
      checkOnStart: checkOnStart,
      checkOnResume: checkOnResume,
      startDelay: startDelay,
      minCheckInterval: minCheckInterval,
      maxRetries: maxRetries,
      retryBackoff: retryBackoff,
      strings: strings,
      stringsBuilder: stringsBuilder,
      onRestartRequested: onRestartRequested,
      onStateChanged: onStateChanged,
      onError: onError,
      logger: logger,
    );
  }
}
