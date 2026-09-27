import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:idara_esign/core/notification_manager/web/web_notification_service.dart';
import 'package:idara_esign/core/widgets/app_snack_bars.dart';
import 'package:idara_esign/generated/l10n.dart';

/// Web invitation to turn on notifications, shown on the dashboard.
///
/// The browser prompt only opens from the *Enable* tap inside this dialog. An
/// unprompted `requestPermission` on page load is what Chrome treats as spam
/// (quiet UI, then an auto-block for the whole site), so the ask is ours and
/// the browser's question follows a real click.
///
/// - Web only: mobile asks natively on the first dashboard, which is normal.
/// - Only while the browser is still undecided. Once granted or blocked there
///   is nothing to ask — a blocked site can't show the prompt anyway.
/// - At most once per app session, so returning to the dashboard doesn't nag;
///   an undecided user is asked again next time they open the app.
///
/// Returns true when permission ended up granted.
class WebNotificationPermissionPrompt {
  const WebNotificationPermissionPrompt._();

  static bool _askedThisSession = false;

  static Future<bool> maybeShow(BuildContext context) async {
    if (!kIsWeb || _askedThisSession) return false;
    if (!await WebNotificationService.isUndecided()) return false;
    if (!context.mounted) return false;
    _askedThisSession = true;

    final granted = await showDialog<bool>(
      context: context,
      builder: (_) => const _NotificationPromptDialog(),
    );
    if (granted == true && context.mounted) {
      AppSnackBars.success(
        S.of(context).notificationPromptEnabled,
        context: context,
      );
    }
    return granted == true;
  }
}

class _NotificationPromptDialog extends StatefulWidget {
  const _NotificationPromptDialog();

  @override
  State<_NotificationPromptDialog> createState() =>
      _NotificationPromptDialogState();
}

class _NotificationPromptDialogState extends State<_NotificationPromptDialog> {
  bool _requesting = false;

  Future<void> _enable() async {
    setState(() => _requesting = true);
    final status = await WebNotificationService.requestAndSetUp();
    if (!mounted) return;
    // Whatever the answer, the question has been put; granted or blocked,
    // this dialog has nothing left to offer.
    Navigator.of(context).pop(
      status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final s = S.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  Icons.notifications_active_outlined,
                  size: 46,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                s.notificationPromptTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                s.notificationPromptMessage,
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
                  onPressed: _requesting ? null : _enable,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _requesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.notifications_outlined, size: 20),
                  label: Text(
                    s.notificationPromptConfirm,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _requesting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    s.notificationPromptDismiss,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
