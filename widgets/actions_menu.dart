import 'package:flutter/material.dart';
// enum DocAction { log, details, remind, extendExpiry, delete }
// ActionsMenu<DocAction>(
//                   items: [
//                     ActionMenuItem(
//                       value: DocAction.log,
//                       label: S.of(context).actionLog,
//                       icon: Icons.list_alt_outlined,
//                     ),
//                     ActionMenuItem(
//                       value: DocAction.details,
//                       label: S.of(context).actionDetails,
//                       icon: Icons.info_outline,
//                     ),
//                     ActionMenuItem(
//                       value: DocAction.remind,
//                       label: S.of(context).actionRemind,
//                       icon: Icons.notifications_active_outlined,
//                     ),

//                     if (document.status == DocumentStatus.expired) ...[
//                       ActionMenuItem(
//                         value: DocAction.extendExpiry,
//                         label: S.of(context).extendExpiry,
//                         icon: Icons.edit_calendar_outlined,
//                       ),
//                     ],

//                     if (document.status == DocumentStatus.pending) ...[
//                       ActionMenuItem(
//                         value: DocAction.log,
//                         label: '',
//                         icon: Icons.remove,
//                         isDivider: true,
//                       ),
//                       ActionMenuItem(
//                         value: DocAction.delete,
//                         label: S.of(context).actionDelete,
//                         icon: Icons.delete_outline,
//                         danger: true,
//                       ),
//                     ],
//                   ],
//                   onSelected: onAction,
//                   compact: !context.isDesktopLayout,
//                 ),
class ActionMenuItem<T> {
  const ActionMenuItem({
    required this.value,
    required this.label,
    required this.icon,
    this.danger = false,
    this.isDivider = false,
  });

  final T value;
  final String label;
  final IconData icon;
  final bool danger;
  final bool isDivider;
}

class ActionsMenu<T> extends StatelessWidget {
  const ActionsMenu({
    super.key,
    required this.items,
    required this.onSelected,
    this.compact = false,
  });

  final List<ActionMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<T>(
      tooltip: '',
      onSelected: onSelected,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: theme.colorScheme.surface,
      itemBuilder: (_) => <PopupMenuEntry<T>>[
        for (final item in items)
          if (item.isDivider)
            const PopupMenuDivider()
          else
            _item(context, item),
      ],
      child: Container(
        width: compact ? 34 : 40,
        height: compact ? 34 : 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.more_horiz,
          color: theme.colorScheme.onSurface.withOpacity(0.80),
          size: 20,
        ),
      ),
    );
  }

  PopupMenuItem<T> _item(BuildContext context, ActionMenuItem<T> item) {
    final theme = Theme.of(context);
    final fg = item.danger
        ? Colors.red
        : theme.colorScheme.onSurface.withOpacity(0.90);

    return PopupMenuItem<T>(
      value: item.value,
      child: Row(
        children: [
          Icon(item.icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Text(
            item.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
