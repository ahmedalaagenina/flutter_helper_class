import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'app_updater_core.dart';
import 'app_updater_service.dart';

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

class AppUpdaterGuard extends StatefulWidget {
  const AppUpdaterGuard({
    super.key,
    required this.child,
    this.providerType = AppUpdaterProviderType.restful,
    this.restfulUrl,
    this.restfulHeaders,
    this.dio,
    this.customProvider,
    this.silent = false,
    this.languageCode = 'en',
    this.loadingBuilder,
    this.maintenanceBuilder,
    this.forceUpdateBuilder,
    this.outdatedBannerBuilder,
    this.onError,
  });

  final Widget child;
  final AppUpdaterProviderType providerType;
  final String? restfulUrl;
  final Map<String, String>? restfulHeaders;
  final Dio? dio;
  final AppUpdaterProvider? customProvider;
  final bool silent;
  final String languageCode;
  final WidgetBuilder? loadingBuilder;
  final MaintenanceBuilder? maintenanceBuilder;
  final ForceUpdateBuilder? forceUpdateBuilder;
  final OutdatedBannerBuilder? outdatedBannerBuilder;
  final OnAppUpdaterError? onError;

  @override
  State<AppUpdaterGuard> createState() => _AppUpdaterGuardState();
}

class _AppUpdaterGuardState extends State<AppUpdaterGuard> {
  late final AppUpdaterService _service = AppUpdaterService.instance;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> _runCheck() async {
    await _service.init(
      provider: widget.providerType,
      restfulUrl: widget.restfulUrl,
      restfulHeaders: widget.restfulHeaders,
      dio: widget.dio,
      customProvider: widget.customProvider,
      silent: widget.silent,
      languageCode: widget.languageCode,
      onError: widget.onError,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.isInitialized) {
      return widget.loadingBuilder?.call(context) ?? const _DefaultLoading();
    }
    if (_service.isInactive) {
      final message = _service.maintenanceMessage(widget.languageCode);
      return widget.maintenanceBuilder?.call(context, message) ??
          _DefaultMaintenance(message: message);
    }

    if (_service.isForcedUpdate) {
      final message = _service.maintenanceMessage(widget.languageCode);

      return widget.forceUpdateBuilder?.call(context, _service.launchStore) ??
          _DefaultForceUpdate(onUpdate: _service.launchStore, message: message);
    }

    if (_service.isOutdated && !_bannerDismissed) {
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
                  _service.launchStore,
                  () => setState(() => _bannerDismissed = true),
                ) ??
                _DefaultOutdatedBanner(
                  onUpdate: _service.launchStore,
                  onDismiss: () => setState(() => _bannerDismissed = true),
                ),
          ),
        ],
      );
    }

    return widget.child;
  }
}

class _DefaultLoading extends StatelessWidget {
  const _DefaultLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

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
