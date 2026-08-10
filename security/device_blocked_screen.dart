import 'package:flutter/material.dart';

import 'device_integrity_result.dart';

/// Text shown on [DeviceBlockedScreen]. Defaults are English; pass localized
/// strings from the host app.
class DeviceGateStrings {
  const DeviceGateStrings({
    this.title = 'Unsupported Device',
    this.unsupportedPlatform =
        'This app runs only on genuine Android phones and iPhones. '
            'Emulators, virtual machines and Windows are not supported.',
    this.emulator = 'An emulator or virtual device was detected. '
        'Please open the app on your real phone.',
    this.compromised = 'This device appears to be rooted or jailbroken. '
        'For content protection the app cannot run here.',
    this.tampered = 'This copy of the app did not come from an official store. '
        'Please reinstall it from Google Play or the App Store.',
    this.developerMode = 'Please turn off Developer options in your device '
        'settings, then reopen the app.',
    this.retry = 'Check again',
    this.referenceLabel = 'Reference',
  });

  final String title;
  final String unsupportedPlatform;
  final String emulator;
  final String compromised;
  final String tampered;
  final String developerMode;
  final String retry;
  final String referenceLabel;

  String forReason(DeviceBlockReason reason) => switch (reason) {
        DeviceBlockReason.unsupportedPlatform => unsupportedPlatform,
        DeviceBlockReason.emulator => emulator,
        DeviceBlockReason.compromised => compromised,
        DeviceBlockReason.tampered => tampered,
        DeviceBlockReason.developerMode => developerMode,
        DeviceBlockReason.none => emulator,
      };
}

/// Colours for [DeviceBlockedScreen]. Defaults fall back to the ambient
/// [ThemeData] when a field is left null.
class DeviceGateTheme {
  const DeviceGateTheme({
    this.background,
    this.accent,
    this.bodyColor,
    this.referenceColor,
  });

  final Color? background;
  final Color? accent;
  final Color? bodyColor;
  final Color? referenceColor;
}

/// Default full-screen explanation of why the app will not run here.
///
/// Replace it wholesale with `DeviceGate.blockedBuilder` if you want your own
/// branding rather than tweaking colours and strings.
class DeviceBlockedScreen extends StatefulWidget {
  const DeviceBlockedScreen({
    super.key,
    required this.result,
    required this.onRetry,
    this.strings = const DeviceGateStrings(),
    this.theme = const DeviceGateTheme(),
    this.showReference = true,
  });

  final DeviceIntegrityResult result;

  /// Runs a full re-check. Awaited, so the button can show progress.
  final Future<void> Function() onRetry;

  final DeviceGateStrings strings;
  final DeviceGateTheme theme;

  /// Show the raw signal list at the bottom. Useful for support; turn it off
  /// if you would rather not tell an attacker which check caught them.
  final bool showReference;

  @override
  State<DeviceBlockedScreen> createState() => _DeviceBlockedScreenState();
}

class _DeviceBlockedScreenState extends State<DeviceBlockedScreen> {
  bool _busy = false;

  IconData get _icon => switch (widget.result.reason) {
        DeviceBlockReason.compromised => Icons.gpp_bad_outlined,
        DeviceBlockReason.tampered => Icons.inventory_2_outlined,
        DeviceBlockReason.developerMode => Icons.developer_mode_outlined,
        _ => Icons.phonelink_erase_outlined,
      };

  /// A full re-check crosses a platform channel and re-scans the filesystem;
  /// without this the button looks dead for a second and gets tapped again.
  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = widget.theme.accent ?? colors.primary;
    final strings = widget.strings;

    return Directionality(
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      child: Material(
        color: widget.theme.background ?? colors.surface,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon, size: 72, color: accent),
                  const SizedBox(height: 24),
                  Text(
                    strings.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    strings.forReason(widget.result.reason),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: widget.theme.bodyColor,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _busy ? null : _retry,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(strings.retry),
                  ),
                  if (widget.showReference) ...[
                    const SizedBox(height: 20),
                    // Lets support tell a genuine emulator from a false
                    // positive without asking the user for logs.
                    Text(
                      '${strings.referenceLabel}: ${widget.result.reference}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.theme.referenceColor ??
                            colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
