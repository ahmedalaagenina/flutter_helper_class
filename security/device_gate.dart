import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scio_phile/config/security/device_guard.dart';
import 'package:scio_phile/constants/app_colors.dart';
import 'package:scio_phile/generated/l10n.dart';

/// Refuses to show the app on a device that failed [DeviceGuard].
///
/// **Mount it from `MaterialApp.builder`, not from `home`.** Above the Navigator
/// it also covers routes opened from notifications and deep links, and it
/// survives the auth flow's `pushAndRemoveUntil(..., (route) => false)` — a gate
/// placed in `home` gets navigated straight past by that call.
class DeviceGate extends StatefulWidget {
  const DeviceGate({super.key, required this.child, this.onBlocked});

  final Widget child;

  /// Fired when the verdict turns into a block.
  ///
  /// Removing the Navigator disposes every page below it, but anything owned
  /// *above* the gate — a provider holding a video controller, for instance —
  /// survives and keeps running behind the block screen. Use this to stop it.
  final VoidCallback? onBlocked;

  @override
  State<DeviceGate> createState() => _DeviceGateState();
}

class _DeviceGateState extends State<DeviceGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DeviceGuard.verdict.addListener(_onVerdictChanged);
  }

  @override
  void dispose() {
    DeviceGuard.verdict.removeListener(_onVerdictChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onVerdictChanged() {
    if (DeviceGuard.isBlocked) widget.onBlocked?.call();
  }

  /// Re-checks on every resume: developer options can be switched on, or a root
  /// manager unhidden, while the app sits in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    DeviceGuard.evaluate();
    // Only while blocked, so a remote policy change can release a user without
    // a reinstall — and an allowed session does not read Firestore every resume.
    if (DeviceGuard.isBlocked) DeviceGuard.refreshPolicy();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DeviceVerdict>(
      valueListenable: DeviceGuard.verdict,
      builder: (context, verdict, _) => verdict.isAllowed
          ? widget.child
          : _BlockedScreen(verdict: verdict),
    );
  }
}

class _BlockedScreen extends StatefulWidget {
  const _BlockedScreen({required this.verdict});

  final DeviceVerdict verdict;

  @override
  State<_BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<_BlockedScreen> {
  bool _checking = false;

  Future<void> _recheck() async {
    setState(() => _checking = true);
    // Both: the user may have turned developer options off, or support may have
    // exempted them remotely.
    await Future.wait([DeviceGuard.evaluate(), DeviceGuard.refreshPolicy()]);
    if (mounted) setState(() => _checking = false);
  }

  String _message(S s) => switch (widget.verdict.reason) {
        DeviceBlockReason.emulator => s.emulatorOrVirtualDeviceDetected,
        DeviceBlockReason.compromised => s.rootedOrJailbrokenDeviceDetected,
        // USB debugging lives inside developer options, so the instruction the
        // user needs is the same one.
        DeviceBlockReason.developerMode ||
        DeviceBlockReason.usbDebugging =>
          s.developerOptionsMustBeTurnedOff,
        DeviceBlockReason.unsupportedPlatform ||
        DeviceBlockReason.none =>
          s.thisAppRunsOnlyOnGenuineAndroidPhonesAndIPhones,
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.mainWhite,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.phonelink_erase_rounded,
                  size: 72.r,
                  color: AppColors.mainBlue,
                ),
                SizedBox(height: 24.h),
                Text(
                  s.unsupportedDevice,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mainBlue,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  _message(s),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15.sp, height: 1.5),
                ),
                SizedBox(height: 28.h),
                if (_checking)
                  const CircularProgressIndicator()
                else
                  TextButton(
                    onPressed: _recheck,
                    child: Text(
                      s.checkAgain,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                SizedBox(height: 24.h),
                // Quoted in support tickets: identifies which signals fired
                // without telling the user what to spoof.
                Text(
                  '${s.deviceCheckReference}: ${widget.verdict.reference}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.secondaryGrey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
