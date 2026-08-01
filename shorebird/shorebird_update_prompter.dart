import 'dart:async';

import 'package:flutter/material.dart';

import 'shorebird_update_options.dart';
import 'shorebird_update_strings.dart';

/// Renders every piece of update UI.
///
/// Kept separate from the manager so the update logic has no dependency on
/// widgets, and so an app that wants its own look can swap this out.
///
/// Every method is a safe no-op when no navigator context is attached yet, so
/// the manager can run before the first frame without guarding each call.
@immutable
class ShorebirdUpdatePrompter {
  const ShorebirdUpdatePrompter({
    required this.navigatorKey,
    required this.strings,
    this.logger,
  });

  final GlobalKey<NavigatorState>? navigatorKey;
  final ShorebirdUpdateStrings strings;
  final void Function(String message)? logger;

  BuildContext? get _context => navigatorKey?.currentContext;

  ScaffoldMessengerState? get _messenger {
    final context = _context;
    if (context == null) return null;
    return ScaffoldMessenger.maybeOf(context);
  }

  /// Banner offering the user a choice to start the download.
  void askToDownload({required VoidCallback onDownload}) {
    _showBanner(
      content: Text(strings.updateAvailable),
      actions: [
        TextButton(
          onPressed: () {
            hide();
            onDownload();
          },
          child: Text(strings.download),
        ),
        TextButton(onPressed: hide, child: Text(strings.later)),
      ],
    );
  }

  /// Indeterminate progress banner shown while the patch downloads.
  void showDownloading() {
    _showBanner(
      content: Text(strings.downloading),
      actions: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ],
    );
  }

  /// Tells the user a patch is staged.
  ///
  /// [onRestart] is optional: without it the prompt is purely informational,
  /// because the patch applies on the next cold start either way.
  void showReady({
    required ShorebirdReadyPromptStyle style,
    VoidCallback? onRestart,
  }) {
    switch (style) {
      case ShorebirdReadyPromptStyle.banner:
        _showReadyBanner(onRestart);
      case ShorebirdReadyPromptStyle.dialog:
        _showReadyDialog(onRestart);
    }
  }

  void showError(String message) {
    _showBanner(
      content: Text('${strings.downloadFailed} $message'),
      actions: [
        TextButton(onPressed: hide, child: Text(strings.dismiss)),
      ],
    );
  }

  void hide() => _messenger?.hideCurrentMaterialBanner();

  void _showReadyBanner(VoidCallback? onRestart) {
    _showBanner(
      content: Text(strings.readyToApply),
      actions: [
        if (onRestart != null)
          TextButton(
            onPressed: () {
              hide();
              onRestart();
            },
            child: Text(strings.restartNow),
          ),
        TextButton(
          onPressed: hide,
          child: Text(onRestart != null ? strings.later : strings.dismiss),
        ),
      ],
    );
  }

  void _showReadyDialog(VoidCallback? onRestart) {
    final context = _context;
    if (context == null) {
      _log('No navigator context available; skipping update dialog.');
      return;
    }
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(strings.readyTitle),
              content: Text(strings.readyToApply),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    onRestart != null ? strings.later : strings.dismiss,
                  ),
                ),
                if (onRestart != null)
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      onRestart();
                    },
                    child: Text(strings.restartNow),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showBanner({
    required Widget content,
    required List<Widget> actions,
  }) {
    final messenger = _messenger;
    if (messenger == null) {
      _log('No ScaffoldMessenger available; skipping banner.');
      return;
    }
    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(content: content, actions: actions),
      );
  }

  void _log(String message) => logger?.call(message);
}
