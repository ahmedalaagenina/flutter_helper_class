import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

import 'device_blocked_screen.dart';
import 'device_integrity.dart';
import 'device_integrity_result.dart';

/// Signature for a custom block screen.
typedef DeviceBlockedBuilder = Widget Function(
  BuildContext context,
  DeviceIntegrityResult result,
  Future<void> Function() retry,
);

/// Root-level gate that refuses to show the app on an unsupported device.
///
/// **Where to put it: [MaterialApp.builder], not `home`.** Above the Navigator
/// it also covers routes opened from notifications and deep links, and it
/// survives auth flows that finish with
/// `Navigator.pushAndRemoveUntil(..., (route) => false)` — a gate placed in
/// `home` gets navigated straight past by that call.
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => DeviceGate(child: child!),
///   home: const SplashPage(),
/// )
/// ```
///
/// Call `DeviceIntegrity.evaluate()` in `main()` before `runApp` so the first
/// build already has a verdict. Without it the gate shows [pendingBuilder]
/// until the async check lands, a frame or two later.
class DeviceGate extends StatefulWidget {
  const DeviceGate({
    super.key,
    required this.child,
    this.allowWhen,
    this.refreshOn,
    this.recheckOnResume = true,
    this.strings = const DeviceGateStrings(),
    this.theme = const DeviceGateTheme(),
    this.showReference = !kReleaseMode,
    this.blockedBuilder,
    this.pendingBuilder,
  });

  /// The app. Rendered whenever the device is allowed.
  final Widget child;

  /// Extra predicate, re-read on every build, that lets [child] through even
  /// on a blocked device.
  ///
  /// The usual reason is store review: Apple and Google test on emulators, and
  /// if reviewer accounts are only recognised *after* sign-in, the sign-in flow
  /// has to stay reachable. Passing `() => !userHasAccount` opens the gate on a
  /// fresh install and closes it the moment an account exists.
  final bool Function()? allowWhen;

  /// Rebuild the gate whenever this fires — pass your auth [ChangeNotifier] so
  /// the gate closes as soon as someone signs in on an emulator, and opens as
  /// soon as a reviewer signs in with a tester account.
  final Listenable? refreshOn;

  /// Re-run the cheap checks when the app returns to the foreground. Catches
  /// someone enabling developer options while the app is backgrounded, and
  /// lets a user who turned them *off* back in without reinstalling.
  ///
  /// The filesystem fingerprints are not re-scanned here — they cannot change
  /// under a running app, and ~50 `stat` calls per resume is real jank. The
  /// "check again" button does a full re-scan.
  final bool recheckOnResume;

  final DeviceGateStrings strings;
  final DeviceGateTheme theme;

  /// Show the raw signal list on the block screen. Defaults to off in release:
  /// it tells support which check fired, but it tells an attacker the same.
  final bool showReference;

  /// Replaces [DeviceBlockedScreen] entirely. When set, [strings], [theme] and
  /// [showReference] are ignored.
  final DeviceBlockedBuilder? blockedBuilder;

  /// Shown while the very first verdict is still being computed.
  ///
  /// Defaults to a blank surface rather than [child]: app content must never
  /// be painted, not even for one frame, on a device that is about to be
  /// blocked. Pass your splash screen here if you have one.
  final WidgetBuilder? pendingBuilder;

  @override
  State<DeviceGate> createState() => _DeviceGateState();
}

class _DeviceGateState extends State<DeviceGate> with WidgetsBindingObserver {
  bool _rechecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.refreshOn?.addListener(_onRefreshSignal);
    // Covers the case where the host forgot to evaluate before runApp.
    // DeviceIntegrity de-duplicates this against main()'s own call.
    if (DeviceIntegrity.lastResult == null) _recheck();
  }

  @override
  void didUpdateWidget(DeviceGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshOn != widget.refreshOn) {
      oldWidget.refreshOn?.removeListener(_onRefreshSignal);
      widget.refreshOn?.addListener(_onRefreshSignal);
    }
  }

  @override
  void dispose() {
    widget.refreshOn?.removeListener(_onRefreshSignal);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-reads [DeviceGate.allowWhen] / the cached verdict. Does not re-run the
  /// platform checks — the device cannot have changed.
  void _onRefreshSignal() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.recheckOnResume && state == AppLifecycleState.resumed) {
      _recheck();
    }
  }

  Future<void> _recheck({bool deep = false}) async {
    if (_rechecking) return;
    _rechecking = true;
    try {
      await DeviceIntegrity.evaluate(force: true, deep: deep);
    } finally {
      _rechecking = false;
      if (mounted) setState(() {});
    }
  }

  Widget _pending(BuildContext context) =>
      widget.pendingBuilder?.call(context) ??
      ColoredBox(
        color: widget.theme.background ?? Theme.of(context).colorScheme.surface,
        child: const SizedBox.expand(),
      );

  @override
  Widget build(BuildContext context) {
    // `verdict`, not `lastResult`: it folds in the bypass on every read, so a
    // reviewer flag that flips after sign-in takes effect on the next rebuild.
    final result = DeviceIntegrity.verdict;
    if (result == null) return _pending(context);
    if (result.isAllowed) return widget.child;
    if (widget.allowWhen?.call() ?? false) return widget.child;

    // No PopScope: this paints above the Navigator, so there is no route to pop
    // back to and nothing underneath is reachable.
    return widget.blockedBuilder?.call(
          context,
          result,
          () => _recheck(deep: true),
        ) ??
        DeviceBlockedScreen(
          result: result,
          onRetry: () => _recheck(deep: true),
          strings: widget.strings,
          theme: widget.theme,
          showReference: widget.showReference,
        );
  }
}
