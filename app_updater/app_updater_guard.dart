import 'package:flutter/material.dart';

import 'app_updater.dart';

typedef MaintenanceBuilder =
    Widget Function(BuildContext context, String? message);
typedef ForceUpdateBuilder =
    Widget Function(BuildContext context, VoidCallback onUpdate);
typedef OutdatedBannerBuilder =
    Widget Function(
      BuildContext context,
      VoidCallback onUpdate,
      VoidCallback onDismiss,
    );
typedef OnAppUpdaterResult = void Function(AppUpdaterResult result);
typedef OnAppUpdaterError = void Function(Object error, StackTrace? stack);

class AppUpdaterGuard extends StatefulWidget {
  const AppUpdaterGuard({
    super.key,
    required this.child,
    required this.provider,
    this.silent = false,
    this.languageCode = 'en',
    this.renderChildWhileLoading = true,
    this.loadingBuilder,
    this.maintenanceBuilder,
    this.forceUpdateBuilder,
    this.outdatedBannerBuilder,
    this.onResult,
    this.onError,
  });

  final Widget child;
  final AppUpdaterProvider provider;
  final bool silent;
  final String languageCode;
  final bool renderChildWhileLoading;
  final WidgetBuilder? loadingBuilder;
  final MaintenanceBuilder? maintenanceBuilder;
  final ForceUpdateBuilder? forceUpdateBuilder;
  final OutdatedBannerBuilder? outdatedBannerBuilder;
  final OnAppUpdaterResult? onResult;
  final OnAppUpdaterError? onError;

  @override
  State<AppUpdaterGuard> createState() => _AppUpdaterGuardState();
}

class _AppUpdaterGuardState extends State<AppUpdaterGuard> {
  AppUpdaterResult? _result;
  bool _bannerDismissed = false;
  bool _initialized = false;
  int _checkVersion = 0;

  bool get _isMaintenance => _result?.status == AppUpdaterStatus.maintenance;
  bool get _isForcedUpdate => _result?.status == AppUpdaterStatus.forcedUpdate;
  bool get _isOutdated => _result?.status == AppUpdaterStatus.outdated;

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  @override
  void didUpdateWidget(covariant AppUpdaterGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.provider != oldWidget.provider) {
      _bannerDismissed = false;
      _runCheck();
    }
  }

  Future<void> _runCheck() async {
    final checkVersion = ++_checkVersion;

    if (_initialized || _result != null) {
      setState(() {
        _result = null;
        _initialized = false;
      });
    }

    try {
      final result = await AppUpdater.check(
        provider: widget.provider,
        silent: widget.silent,
      );

      if (!mounted || checkVersion != _checkVersion) return;
      widget.onResult?.call(result);
      setState(() {
        _result = result;
        _initialized = true;
      });
    } catch (error, stackTrace) {
      widget.onError?.call(error, stackTrace);
      if (!widget.silent) {
        debugPrint('[AppUpdaterGuard] Error: $error');
      }
      if (!mounted || checkVersion != _checkVersion) return;
      setState(() => _initialized = true);
    }
  }

  Future<void> _launchStore() async {
    try {
      await AppUpdater.launchDownloadUrl(_result?.downloadUrl);
    } catch (error) {
      if (!widget.silent) {
        debugPrint('[AppUpdaterGuard] Could not launch store URL: $error');
      }
    }
  }

  String? _message(String languageCode) {
    return _result?.getMessageForLanguage(languageCode);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      if (widget.loadingBuilder != null) {
        return widget.loadingBuilder!(context);
      }
      return widget.renderChildWhileLoading
          ? widget.child
          : const SizedBox.shrink();
    }
    if (_isMaintenance) {
      final message = _message(widget.languageCode);
      return widget.maintenanceBuilder?.call(context, message) ??
          _DefaultMaintenance(message: message);
    }

    if (_isForcedUpdate) {
      final message = _message(widget.languageCode);

      return widget.forceUpdateBuilder?.call(context, _launchStore) ??
          _DefaultForceUpdate(onUpdate: _launchStore, message: message);
    }

    if (_isOutdated && !_bannerDismissed) {
      return Stack(
        children: [
          widget.child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child:
                widget.outdatedBannerBuilder?.call(
                  context,
                  _launchStore,
                  () => setState(() => _bannerDismissed = true),
                ) ??
                _DefaultOutdatedBanner(
                  onUpdate: _launchStore,
                  onDismiss: () => setState(() => _bannerDismissed = true),
                ),
          ),
        ],
      );
    }

    return widget.child;
  }
}

// a simple default widget to show if no widget is provided (Default UI)
class _DefaultMaintenance extends StatelessWidget {
  const _DefaultMaintenance({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.build_circle_outlined,
                size: 72,
                color: Colors.orange,
              ),
              const SizedBox(height: 24),
              const Text(
                'Under Maintenance',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                message ?? 'We\'ll be back shortly. Please try again later.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultForceUpdate extends StatelessWidget {
  const _DefaultForceUpdate({required this.onUpdate, this.message});

  final VoidCallback onUpdate;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.system_update_alt, size: 72, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'Update Required',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                message ??
                    'A new version is required to continue. Please update the app.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onUpdate,
                icon: const Icon(Icons.download),
                label: const Text('Update Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultOutdatedBanner extends StatelessWidget {
  const _DefaultOutdatedBanner({
    required this.onUpdate,
    required this.onDismiss,
  });

  final VoidCallback onUpdate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: Colors.blue.shade700,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.new_releases_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'A new version is available!',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: onUpdate,
                child: const Text(
                  'Update',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
