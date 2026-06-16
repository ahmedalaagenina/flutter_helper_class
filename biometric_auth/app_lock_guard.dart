import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:idara_esign/core/biometric_auth/service/biometric_auth.dart';
import 'package:idara_esign/core/constants/storage_keys.dart';
import 'package:idara_esign/di/injection_container.dart';
import 'package:idara_esign/generated/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user has turned on "require biometric to open the app".
///
/// Read synchronously from the already-warmed [SharedPreferences] singleton so
/// the guard can decide its very first frame without a flash of content. The
/// toggle is owned by `AppLockWidget` in the settings screen.
bool isAppLockEnabled() =>
    getIt<SharedPreferences>().getBool(StorageKeys.useBiometricAuth) ?? false;

enum _LockStatus {
  /// Lock disabled or already authenticated — [AppLockGuard.child] is shown.
  unlocked,

  /// Transient privacy blur (e.g. app-switcher snapshot) that does **not**
  /// require re-authentication — it lifts on its own when the app resumes.
  covered,

  /// Content is covered and the unlock UI is awaiting the user.
  locked,

  /// The system biometric sheet is up; lifecycle events are suppressed.
  authenticating,
}

/// App-wide biometric / device-credential lock screen.
///
/// Wrap the app (inside `MaterialApp.builder`, so localization, theming and
/// directionality are available) to require local authentication when the user
/// has enabled the lock. It guards three moments:
///
/// 1. **Cold start** — if the lock is on, the app opens locked and prompts.
/// 2. **Backgrounding** — content is immediately covered (blurred) so it never
///    leaks into the OS app-switcher snapshot.
/// 3. **Returning to the foreground** — re-prompts after the app has been in
///    the background longer than [lockAfter]; quick excursions (a share sheet,
///    file picker, control center) within the grace window unlock silently.
///
/// This is app-level glue and may depend on app code freely. The reusable,
/// platform-agnostic [BiometricAuthService] under `core/biometric_auth/service`
/// stays dependency-free so it can be copied between projects untouched.
///
/// Design notes — why this avoids the classic "re-prompt loop":
/// - The system biometric sheet itself drives the app through
///   `inactive`/`resumed`. While [_LockStatus.authenticating] we ignore all
///   lifecycle churn, so the sheet never triggers a second prompt.
/// - After a failed/canceled attempt we wait for an explicit tap on *Unlock*
///   ([_awaitingUserRetry]) instead of auto-retrying on the trailing `resumed`
///   the dismissed sheet emits — otherwise a cancel would loop forever.
class AppLockGuard extends StatefulWidget {
  const AppLockGuard({
    super.key,
    required this.child,
    this.lockAfter = const Duration(seconds: 10),
    this.onUnlocked,
  });

  /// The app UI to protect.
  final Widget child;

  /// How long the app may stay backgrounded before a re-prompt is required on
  /// resume. Returning within this window unlocks silently so brief, expected
  /// excursions (file picker, OAuth, share sheet) don't nag the user. Set to
  /// [Duration.zero] to always re-prompt.
  final Duration lockAfter;

  /// Called once each time the app transitions from locked to unlocked. A good
  /// place to revalidate the session or refresh tokens if needed.
  final VoidCallback? onUnlocked;

  @override
  State<AppLockGuard> createState() => _AppLockGuardState();
}

class _AppLockGuardState extends State<AppLockGuard>
    with WidgetsBindingObserver {
  final BiometricAuthService _service = getIt<BiometricAuthService>();

  late _LockStatus _status;
  bool _enabled = false;

  /// Set after a failed/canceled attempt so the trailing `resumed` from the
  /// dismissed sheet doesn't immediately re-prompt; cleared on success or when
  /// the app is genuinely backgrounded again.
  bool _awaitingUserRetry = false;

  /// When the app was last sent to the background, used to apply [lockAfter].
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Decide the first frame synchronously so locked content never flashes.
    _enabled = isAppLockEnabled();
    _status = _enabled ? _LockStatus.locked : _LockStatus.unlocked;

    if (_enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Confirms the device can actually authenticate, then prompts. If support is
  /// missing we unlock rather than trapping the user behind a wall they can't
  /// clear (mirrors [BiometricAuthUnavailable] handling).
  Future<void> _bootstrap() async {
    final supported = await _service.isSupported();
    if (!mounted) return;
    if (!supported) {
      _enabled = false;
      setState(() => _status = _LockStatus.unlocked);
      return;
    }
    _authenticate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-read the preference so toggling the setting at runtime takes effect on
    // the next foreground/background transition without a restart.
    _enabled = isAppLockEnabled();
    if (!_enabled) {
      if (_status != _LockStatus.unlocked) {
        setState(() => _status = _LockStatus.unlocked);
      }
      return;
    }

    // The biometric sheet itself moves us through inactive/resumed — ignore it.
    if (_status == _LockStatus.authenticating) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _onResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _onBackgrounded(state);
      case AppLifecycleState.detached:
        break;
    }
  }

  void _onBackgrounded(AppLifecycleState state) {
    // On Android, `inactive` also fires for focus loss that never leaves the
    // app: the keyboard's SMS-autofill window, permission and biometric
    // dialogs, the notification shade. Covering (and starting the lock clock)
    // on it would flash the lock screen mid-interaction — e.g. while entering
    // an OTP — so wait for `hidden`/`paused`, which still precedes the recents
    // snapshot. On iOS, `inactive` is the app-switcher entry point and must
    // cover immediately so content never reaches the switcher.
    final transientAndroidFocusLoss =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        state == AppLifecycleState.inactive;
    if (transientAndroidFocusLoss) return;

    // Record the timestamp only on the *first* time we leave the foreground in
    // this episode. The foreground transition is `paused → inactive → resumed`
    // on iOS, so that pre-resume `inactive` must NOT reset the clock — otherwise
    // `elapsed` would always be ~0 and the grace window would swallow the lock.
    if (_backgroundedAt == null) {
      _backgroundedAt = DateTime.now();
      _awaitingUserRetry = false; // fresh episode: allow auto-prompt on return.
    }
    // Cover the content immediately so it's hidden in the app-switcher
    // snapshot. Use the transient [_LockStatus.covered] (blur only, no unlock
    // UI): it either lifts silently on a quick return within the grace window
    // or escalates to a real prompt in [_onResumed]. A state that is already
    // `locked` (e.g. awaiting a retry) must not be downgraded.
    if (_status == _LockStatus.unlocked) {
      setState(() => _status = _LockStatus.covered);
    }
  }

  void _onResumed() {
    if (_status != _LockStatus.locked && _status != _LockStatus.covered) {
      return;
    }
    if (_awaitingUserRetry) {
      return;
    }

    final backgroundedAt = _backgroundedAt;
    final elapsed = backgroundedAt == null
        ? null
        : DateTime.now().difference(backgroundedAt);
    final withinGrace = elapsed != null && elapsed < widget.lockAfter;

    // Episode consumed: clear so the next background episode stamps fresh.
    _backgroundedAt = null;

    if (withinGrace) {
      _unlock();
    } else {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_status == _LockStatus.authenticating) return;
    setState(() => _status = _LockStatus.authenticating);

    final result = await _service.authenticate(
      localizedReason: S.of(context).requireBiometricDescription,
    );
    if (!mounted) return;

    switch (result) {
      // Don't lock the user out if the device can no longer authenticate.
      case BiometricAuthSuccess():
      case BiometricAuthUnavailable():
        _unlock();
      case BiometricAuthCanceled():
      case BiometricAuthFailed():
      case BiometricAuthLockedOut():
      case BiometricAuthError():
        _awaitingUserRetry = true;
        setState(() => _status = _LockStatus.locked);
    }
  }

  void _unlock() {
    _awaitingUserRetry = false;
    _backgroundedAt = null;
    setState(() => _status = _LockStatus.unlocked);
    widget.onUnlocked?.call();
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: Always keep widget.child inside the same Stack so the widget
    // tree structure is stable across lock/unlock transitions. If we returned
    // widget.child directly when unlocked, the structural change (Stack →
    // bare child) would cause Flutter to unmount and remount the entire child
    // subtree — destroying the GoRouter navigator state and resetting
    // navigation back to the initial route.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_status != _LockStatus.unlocked)
          _LockOverlay(
            busy: _status == _LockStatus.authenticating,
            // Transient cover: privacy blur only. It lifts by itself on resume
            // (or escalates to a prompt), so showing an unlock CTA would just
            // flash misleading UI during snapshots and system overlays.
            showUnlockUi: _status != _LockStatus.covered,
            onUnlock: _authenticate,
          ),
      ],
    );
  }
}

/// Full-screen blurred cover. With [showUnlockUi] it adds the lock copy and
/// the unlock affordance; without it it's a pure privacy blur for transient
/// covers. Kept private so the guard owns the only entry point.
class _LockOverlay extends StatelessWidget {
  const _LockOverlay({
    required this.busy,
    required this.showUnlockUi,
    required this.onUnlock,
  });

  /// True while the system biometric sheet is showing — the button spins and is
  /// disabled to avoid stacking prompts.
  final bool busy;

  /// False for the transient privacy cover, which resolves on its own.
  final bool showUnlockUi;

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Material(
          color: colors.surface.withValues(alpha: 0.92),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 44,
                        color: colors.primary,
                      ),
                    ),
                    if (showUnlockUi) ...[
                      const SizedBox(height: 24),
                      Text(
                        S.of(context).appLocked,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        S.of(context).requireBiometricDescription,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        onPressed: busy ? null : onUnlock,
                        icon: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.fingerprint_rounded),
                        label: Text(S.of(context).unlockApp),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
