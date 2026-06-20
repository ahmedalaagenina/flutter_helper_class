import 'package:flutter/material.dart';
import 'package:idara_esign/core/widgets/dialogs.dart';

/// Visual definition of one swipe direction for [DismissibleTile].
class SwipeAction {
  const SwipeAction({
    required this.icon,
    required this.color,
    this.label,
    this.foregroundColor = Colors.white,
  });

  final IconData icon;
  final Color color;

  /// Optional caption shown under the icon (e.g. "Delete", "Archive").
  final String? label;
  final Color foregroundColor;
}

/// A reusable swipe-to-act row built on Flutter's built-in [Dismissible] — no
/// extra package required. Drop it around any list item to get swipe gestures
/// with sensible defaults, optional confirmation, and RTL-correct backgrounds.
///
/// Direction is inferred from which actions you provide (override with
/// [direction] if needed):
/// * [endAction] only  → swipe end→start (trailing reveal).
/// * [startAction] only → swipe start→end (leading reveal).
/// * both              → swipe either way.
///
/// Confirmation: pass a custom [confirmDismiss], or set [confirmTitle]
/// (+ optional [confirmMessage]) to get a built-in yes/no dialog before the
/// item is removed. The widget holds no hardcoded copy — pass localized
/// strings so it stays reusable across apps.
///
/// ```dart
/// DismissibleTile.delete(
///   itemKey: ValueKey(item.id),
///   confirmTitle: S.of(context).deleteItem,
///   confirmMessage: S.of(context).deleteItemConfirm,
///   onDelete: () => bloc.add(DeleteItem(item.id)),
///   child: ItemRow(item),
/// );
/// ```
class DismissibleTile extends StatelessWidget {
  const DismissibleTile({
    super.key,
    required this.itemKey,
    required this.child,
    this.startAction,
    this.endAction,
    this.direction,
    this.onDismissed,
    this.confirmDismiss,
    this.confirmTitle,
    this.confirmMessage,
    this.confirmActionLabel,
    this.confirmCancelLabel,
    this.dismissThreshold = 0.4,
    this.movementDuration = const Duration(milliseconds: 200),
  }) : assert(
         startAction != null || endAction != null,
         'Provide at least one of startAction / endAction.',
       );

  /// Unique, stable key for the item (e.g. `ValueKey(item.id)`). Required by
  /// [Dismissible] so it can correctly animate the right row out of a list.
  final Key itemKey;
  final Widget child;

  /// Background revealed when swiping start→end (left→right in LTR).
  final SwipeAction? startAction;

  /// Background revealed when swiping end→start (right→left in LTR).
  final SwipeAction? endAction;

  /// Override the auto-derived swipe direction.
  final DismissDirection? direction;

  /// Called after the item is actually dismissed (post-animation / confirm).
  final void Function(DismissDirection direction)? onDismissed;

  /// Full control over confirmation. Takes precedence over [confirmTitle].
  /// Return `true` to dismiss, `false`/`null` to snap back.
  final Future<bool?> Function(DismissDirection direction)? confirmDismiss;

  /// When set (and [confirmDismiss] is null), a yes/no dialog with this title
  /// is shown before dismissal.
  final String? confirmTitle;
  final String? confirmMessage;
  final String? confirmActionLabel;
  final String? confirmCancelLabel;

  /// Fraction of width the user must swipe past to dismiss (0–1).
  final double dismissThreshold;
  final Duration movementDuration;

  DismissDirection get _effectiveDirection {
    if (direction != null) return direction!;
    if (startAction != null && endAction != null) {
      return DismissDirection.horizontal;
    }
    if (endAction != null) return DismissDirection.endToStart;
    return DismissDirection.startToEnd;
  }

  Future<bool?> Function(DismissDirection)? _resolveConfirm(
    BuildContext context,
  ) {
    if (confirmDismiss != null) return confirmDismiss;
    if (confirmTitle == null) return null;
    return (_) => Dialogs.showYesNoDialog(
      context,
      title: confirmTitle!,
      content: confirmMessage ?? '',
      yesButtonText: confirmActionLabel,
      noButtonText: confirmCancelLabel,
    );
  }

  Widget _pane(SwipeAction action, AlignmentGeometry alignment) {
    return Container(
      color: action.color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(action.icon, color: action.foregroundColor),
          if (action.label != null) ...[
            const SizedBox(height: 4),
            Text(
              action.label!,
              style: TextStyle(
                color: action.foregroundColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // [Dismissible] asserts that a `background` exists whenever a
    // `secondaryBackground` is given. So: with both actions we map them to
    // background (leading) + secondaryBackground (trailing); with a single
    // action we always use `background` and align it to the correct edge —
    // Dismissible falls back to `background` for both directions when
    // `secondaryBackground` is null.
    Widget? background;
    Widget? secondaryBackground;
    if (startAction != null && endAction != null) {
      background = _pane(startAction!, AlignmentDirectional.centerStart);
      secondaryBackground = _pane(endAction!, AlignmentDirectional.centerEnd);
    } else if (endAction != null) {
      background = _pane(endAction!, AlignmentDirectional.centerEnd);
    } else if (startAction != null) {
      background = _pane(startAction!, AlignmentDirectional.centerStart);
    }

    return Dismissible(
      key: itemKey,
      direction: _effectiveDirection,
      movementDuration: movementDuration,
      dismissThresholds: {
        DismissDirection.startToEnd: dismissThreshold,
        DismissDirection.endToStart: dismissThreshold,
      },
      confirmDismiss: _resolveConfirm(context),
      onDismissed: onDismissed,
      background: background,
      secondaryBackground: secondaryBackground,
      child: child,
    );
  }
}
