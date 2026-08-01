import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:sanad_rewards/main.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class ShorebirdUpdateManager {
  static final ShorebirdUpdateManager _instance =
      ShorebirdUpdateManager._internal();
  factory ShorebirdUpdateManager() => _instance;
  ShorebirdUpdateManager._internal();

  static ShorebirdUpdater? _updater;
  static bool _isCheckingForUpdates = false;
  static bool _hasRestartedForUpdate = false;
  static bool _isRestartBannerUI = true;
  static UpdateTrack _currentTrack = UpdateTrack.stable;

  static ShorebirdUpdater get updater {
    _updater ??= ShorebirdUpdater();
    return _updater!;
  }

  static bool get isCheckingForUpdates => _isCheckingForUpdates;
  static UpdateTrack get currentTrack => _currentTrack;

  static void initialize({bool isRestartBannerUI = true}) {
    _updater = ShorebirdUpdater();
    _isRestartBannerUI = isRestartBannerUI;
    if (!isShorebirdAvailable()) {
      log('Shorebird is not available');
    }
  }

  static bool isShorebirdAvailable() => _updater?.isAvailable ?? false;

  static void setTrack(UpdateTrack track) {
    _currentTrack = track;
  }

  static Future<Patch?> getCurrentPatch() async {
    try {
      if (!isShorebirdAvailable()) return null;
      return await _updater?.readCurrentPatch();
    } catch (e) {
      log('Error reading current patch: $e');
      return null;
    }
  }

  static Future<void> checkForUpdate({
    bool autoDownload = true,
    VoidCallback? onUpdateAvailable,
    VoidCallback? onNoUpdateAvailable,
    Function(String)? onError,
  }) async {
    if (!isShorebirdAvailable() || _isCheckingForUpdates) return;

    try {
      _isCheckingForUpdates = true;
      final status = await _updater!.checkForUpdate(track: _currentTrack);

      switch (status) {
        case UpdateStatus.upToDate:
          _noUpdateAvailable();
          onNoUpdateAvailable?.call();
        case UpdateStatus.outdated:
          onUpdateAvailable?.call();
          if (autoDownload) {
            await _updateAvailable();
          } else {
            _showUpdateAvailableBanner();
          }
        case UpdateStatus.restartRequired:
          if (!_hasRestartedForUpdate) {
            _showRestartUI();
          }
        case UpdateStatus.unavailable:
          log('Updates unavailable');
      }
    } catch (error) {
      log('Error checking for update: $error');
      onError?.call(error.toString());
    } finally {
      _isCheckingForUpdates = false;
    }
  }

  static void _noUpdateAvailable() {
    log('No update available.');
  }

  static Future<void> _updateAvailable() async {
    await _downloadUpdate();
    _showRestartUI();
  }

  static Future<void> _downloadUpdate() async {
    try {
      await _updater!.update(track: _currentTrack);
    } on UpdateException catch (error) {
      _showErrorBanner(error.message);
    }
  }

  static void _showUpdateAvailableBanner() {
    _showBanner(
      content: Text('New update available on ${_currentTrack.name} track'),
      actions: [
        TextButton(
          onPressed: () async {
            _hideBanner();
            _showDownloadingBanner();
            await _downloadUpdate();
            _hideBanner();
            _showRestartUI();
          },
          child: const Text('Download'),
        ),
        TextButton(onPressed: _hideBanner, child: const Text('Later')),
      ],
    );
  }

  static void _showDownloadingBanner() {
    _showBanner(
      content: const Text('Downloading update...'),
      actions: const [
        SizedBox(height: 14, width: 14, child: CircularProgressIndicator()),
      ],
    );
  }

  static void _showErrorBanner(Object error) {
    _showBanner(
      content: Text('Error downloading update: $error'),
      actions: [
        TextButton(onPressed: _hideBanner, child: const Text('Dismiss')),
      ],
    );
  }

  static void _showRestartUI() {
    _isRestartBannerUI ? _showRestartBanner() : _promptUserToRestart();
  }

  static void _showRestartBanner() {
    _showBanner(
      content: const Text('Update ready! Please restart your app.'),
      actions: [
        TextButton(
          onPressed: () {
            _hasRestartedForUpdate = true;
            _hideBanner();
            RestartWidget.restartApp(navigatorKey.currentState!.context);
          },
          child: const Text('Restart Now'),
        ),
        TextButton(onPressed: _hideBanner, child: const Text('Later')),
      ],
    );
  }

  static void _promptUserToRestart() {
    showDialog(
      context: navigatorKey.currentState!.context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Update Ready'),
            content: const Text(
              'An update has been downloaded. Restart now to apply the changes!',
            ),
            actions: [
              TextButton(
                child: const Text('Later'),
                onPressed: () =>
                    Navigator.of(navigatorKey.currentState!.context).pop(),
              ),
              TextButton(
                onPressed: () {
                  _hasRestartedForUpdate = true;
                  Navigator.of(navigatorKey.currentState!.context).pop();
                  RestartWidget.restartApp(context);
                },
                child: const Text('Restart Now'),
              ),
            ],
          ),
        );
      },
    );
  }

  static void _showBanner({
    required Widget content,
    required List<Widget> actions,
  }) {
    ScaffoldMessenger.of(navigatorKey.currentState!.context)
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(MaterialBanner(content: content, actions: actions));
  }

  static void _hideBanner() {
    ScaffoldMessenger.of(
      navigatorKey.currentState!.context,
    ).hideCurrentMaterialBanner();
  }
}

class RestartWidget extends StatefulWidget {
  const RestartWidget({super.key, required this.child});

  final Widget child;

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()!.restartApp();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: key, child: widget.child);
  }
}
