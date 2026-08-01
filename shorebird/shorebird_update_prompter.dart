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
    this.stringsBuilder,
    this.logger,
  });

  final GlobalKey<NavigatorState>? navigatorKey;

  /// Fallback strings, used when [stringsBuilder] is null.
  final ShorebirdUpdateStrings strings;

  /// Resolves strings from the live context, so prompts follow the app's
  /// current locale. See `ShorebirdUpdateConfig.stringsBuilder`.
  final ShorebirdUpdateStrings Function(BuildContext context)? stringsBuilder;

  final void Function(String message)? logger;

  BuildContext? get _context => navigatorKey?.currentContext;

  ScaffoldMessengerState? get _messenger {
    final context = _context;
    if (context == null) return null;
    return ScaffoldMessenger.maybeOf(context);
  }

  /// Strings for the current locale, or `null` when there is no context to
  /// render into — in which case there is nothing to show anyway.
  ShorebirdUpdateStrings? get _strings {
    final context = _context;
    if (context == null) {
      _log('No navigator context available; skipping update prompt.');
      return null;
    }
    return stringsBuilder?.call(context) ?? strings;
  }

  /// Offers the user a choice to start the download.
  void askToDownload({
    required ShorebirdPromptStyle style,
    required VoidCallback onDownload,
  }) {
    final text = _strings;
    if (text == null) return;
    switch (style) {
      case ShorebirdPromptStyle.banner:
        _askToDownloadBanner(text, onDownload);
      case ShorebirdPromptStyle.dialog:
        _askToDownloadDialog(text, onDownload);
    }
  }

  /// Indeterminate progress banner shown while the patch downloads.
  void showDownloading() {
    final text = _strings;
    if (text == null) return;
    _showBanner(
      content: Text(text.downloading),
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
    required ShorebirdPromptStyle style,
    VoidCallback? onRestart,
  }) {
    final text = _strings;
    if (text == null) return;
    switch (style) {
      case ShorebirdPromptStyle.banner:
        _showReadyBanner(text, onRestart);
      case ShorebirdPromptStyle.dialog:
        _showReadyDialog(text, onRestart);
    }
  }

  void showError(String message) {
    final text = _strings;
    if (text == null) return;
    _showBanner(
      content: Text('${text.downloadFailed} $message'),
      actions: [
        TextButton(onPressed: hide, child: Text(text.dismiss)),
      ],
    );
  }

  void hide() => _messenger?.hideCurrentMaterialBanner();

  void _askToDownloadBanner(
    ShorebirdUpdateStrings text,
    VoidCallback onDownload,
  ) {
    _showBanner(
      content: Text(text.updateAvailable),
      actions: [
        TextButton(
          onPressed: () {
            hide();
            onDownload();
          },
          child: Text(text.download),
        ),
        TextButton(onPressed: hide, child: Text(text.later)),
      ],
    );
  }

  /// Dismissible, unlike the "ready" dialog: declining a download is a normal
  /// choice, so a back gesture or barrier tap means "Later".
  void _askToDownloadDialog(
    ShorebirdUpdateStrings text,
    VoidCallback onDownload,
  ) {
    final context = _context;
    if (context == null) return;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(text.availableTitle),
            content: Text(text.updateAvailable),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(text.later),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onDownload();
                },
                child: Text(text.download),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showReadyBanner(ShorebirdUpdateStrings text, VoidCallback? onRestart) {
    _showBanner(
      content: Text(text.readyToApply),
      actions: [
        if (onRestart != null)
          TextButton(
            onPressed: () {
              hide();
              onRestart();
            },
            child: Text(text.restartNow),
          ),
        TextButton(
          onPressed: hide,
          child: Text(onRestart != null ? text.later : text.dismiss),
        ),
      ],
    );
  }

  void _showReadyDialog(ShorebirdUpdateStrings text, VoidCallback? onRestart) {
    final context = _context;
    if (context == null) return;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(text.readyTitle),
              content: Text(text.readyToApply),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(onRestart != null ? text.later : text.dismiss),
                ),
                if (onRestart != null)
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      onRestart();
                    },
                    child: Text(text.restartNow),
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
