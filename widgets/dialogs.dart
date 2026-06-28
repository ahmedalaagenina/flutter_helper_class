import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:idara_esign/generated/l10n.dart';

class Dialogs {
  static Future<bool> showYesNoDialog(
    BuildContext context, {
    required String title,
    required String content,
    String? yesButtonText,
    String? noButtonText,
  }) async {
    return await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => context.pop(false),
              child: Text(noButtonText ?? S.of(context).no),
            ),
            TextButton(
              onPressed: () => context.pop(true),
              child: Text(yesButtonText ?? S.of(context).yes),
            ),
          ],
        );
      },
    );
  }

  static Future<void> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String content,
    VoidCallback? onTap,
    bool isDismissible = false,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          content: Text(content, style: const TextStyle(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: onTap ?? () => context.pop(),
              child: Text(S.of(context).confirmation),
            ),
          ],
        );
      },
    );
  }

  static Future<bool> showDeleteConfirmationDialog(
    BuildContext context, {
    required String itemName,
    String? title,
    String? message,
    String? confirmText,
    String? cancelText,
    IconData icon = Icons.delete_outline,
    Color? destructiveColor,
    bool barrierDismissible = true,
  }) async {
    final theme = Theme.of(context);
    final accent = destructiveColor ?? theme.colorScheme.error;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title ?? S.of(context).delete,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: message != null
              ? Text(message, style: const TextStyle(fontSize: 14))
              : RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                    children: [
                      TextSpan(text: '${S.of(context).delete} '),
                      TextSpan(
                        text: '"$itemName"',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: '?'),
                    ],
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(cancelText ?? S.of(context).cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmText ?? S.of(context).delete),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  static Future<void> showWidgetDialog(
    BuildContext context, {
    required Widget content,
    Widget? title,
    EdgeInsetsGeometry? contentPadding,
    double? radius,
    bool isDismissible = false,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius ?? 16),
          ),
          contentPadding: contentPadding ?? EdgeInsets.zero,
          title: title,
          content: content,
        );
      },
    );
  }
}
