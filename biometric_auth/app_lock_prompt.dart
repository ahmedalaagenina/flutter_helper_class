import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:idara_esign/core/biometric_auth/service/biometric_auth.dart';
import 'package:idara_esign/core/constants/storage_keys.dart';
import 'package:idara_esign/core/widgets/app_snack_bars.dart';
import 'package:idara_esign/di/injection_container.dart';
import 'package:idara_esign/generated/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One-time, opt-in invitation to turn on the biometric app lock.
///
/// Best-practice behavior:
/// - Shown **at most once, ever** (tracked by [StorageKeys.appLockPromptShown]).
/// - Skipped when it can't help: on web, when the device can't authenticate, or
///   when the lock is already enabled.
/// - Marked as shown *before* the dialog appears, so an app kill mid-dialog
///   never brings it back.
/// - Enables the lock **inline**: tapping *Enable* runs a real biometric check
///   and only flips [StorageKeys.useBiometricAuth] on success — the user
///   confirms with their own face/finger, exactly like the Settings toggle. If
///   they dismiss it, nothing happens; they can still enable it later in
///   Settings.
///
/// Call from a screen that only authenticated users reach (e.g. the dashboard),
/// after the first frame.
class AppLockPrompt {
  const AppLockPrompt._();

  static Future<void> maybeShow(BuildContext context) async {
    if (kIsWeb) return;

    final prefs = getIt<SharedPreferences>();
    final alreadyShown = prefs.getBool(StorageKeys.appLockPromptShown) ?? false;
    if (alreadyShown) return;

    // Nothing to suggest if it's already on — just retire the prompt.
    final alreadyEnabled = prefs.getBool(StorageKeys.useBiometricAuth) ?? false;
    if (alreadyEnabled) {
      await prefs.setBool(StorageKeys.appLockPromptShown, true);
      return;
    }

    // Don't pitch a feature the device can't deliver.
    final supported = await getIt<BiometricAuthService>().isSupported();
    if (!supported || !context.mounted) return;

    // Retire the prompt up-front: it must never appear a second time.
    await prefs.setBool(StorageKeys.appLockPromptShown, true);
    if (!context.mounted) return;

    final enabled = await showDialog<bool>(
      context: context,
      builder: (_) => const _AppLockPromptDialog(),
    );

    if (enabled == true && context.mounted) {
      AppSnackBars.success(S.of(context).appLockEnabled, context: context);
    }
  }
}

class _AppLockPromptDialog extends StatefulWidget {
  const _AppLockPromptDialog();

  @override
  State<_AppLockPromptDialog> createState() => _AppLockPromptDialogState();
}

class _AppLockPromptDialogState extends State<_AppLockPromptDialog> {
  bool _enabling = false;

  Future<void> _enable() async {
    setState(() => _enabling = true);

    // Require a successful biometric check before turning the lock on, so the
    // user can't enable something they then can't pass.
    final result = await getIt<BiometricAuthService>().authenticate(
      localizedReason: S.current.requireBiometricDescription,
    );
    if (!mounted) return;

    if (result.isSuccess) {
      await getIt<SharedPreferences>().setBool(
        StorageKeys.useBiometricAuth,
        true,
      );
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    // Auth failed/canceled — keep the dialog open so they can retry.
    setState(() => _enabling = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hero biometric mark.
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primary.withValues(alpha: 0.18),
                    colors.primary.withValues(alpha: 0.04),
                  ],
                ),
              ),
              child: Icon(
                Icons.fingerprint_rounded,
                size: 46,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              S.of(context).appLockPromptTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              S.of(context).appLockPromptMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _enabling ? null : _enable,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _enabling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.fingerprint_rounded, size: 20),
                label: Text(
                  S.of(context).appLockPromptConfirm,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _enabling
                    ? null
                    : () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  S.of(context).appLockPromptDismiss,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
