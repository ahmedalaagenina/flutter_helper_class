import 'package:flutter/foundation.dart';

/// Every user facing string, so the helper can be dropped into a localized app
/// without carrying its own translations.
///
/// Pass localized values from your own `S.of(context)` / `AppLocalizations`:
///
/// ```dart
/// strings: ShorebirdUpdateStrings(
///   readyToApply: S.current.updateReady,
///   restartNow: S.current.restartNow,
/// ),
/// ```
@immutable
class ShorebirdUpdateStrings {
  const ShorebirdUpdateStrings({
    this.availableTitle = 'Update Available',
    this.updateAvailable = 'A new update is available.',
    this.download = 'Download',
    this.later = 'Later',
    this.downloading = 'Downloading update...',
    this.readyTitle = 'Update Ready',
    this.readyToApply =
        'Update ready. It will be applied the next time you open the app.',
    this.restartNow = 'Restart now',
    this.dismiss = 'Dismiss',
    this.downloadFailed = 'Could not download the update.',
  });

  /// Title of the "update available" prompt. Dialog style only.
  final String availableTitle;
  final String updateAvailable;
  final String download;
  final String later;
  final String downloading;

  /// Title of the "update ready" prompt. Dialog style only.
  final String readyTitle;
  final String readyToApply;
  final String restartNow;
  final String dismiss;
  final String downloadFailed;
}
