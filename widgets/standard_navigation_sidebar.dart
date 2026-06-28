import 'package:flutter/material.dart';

/// Data class representing a single item in the sidebar.
class NavigationSidebarItem {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  /// Optional badge to display an unread count.
  final int? badgeCount;

  /// If true, applies the [dangerColor] styling instead of standard colors.
  final bool isDanger;

  /// Specific overrides for this item. If null, the sidebar's default is used.
  final Color? itemColor;
  final Color? selectedColor;

  const NavigationSidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.badgeCount,
    this.isDanger = false,
    this.itemColor,
    this.selectedColor,
  });
}

/// A highly customizable, generic navigation sidebar widget.
class StandardNavigationSidebar extends StatelessWidget {
  /// The list of navigation items.
  final List<NavigationSidebarItem> items;

  /// Optional header widget (e.g., User profile info).
  final Widget? header;

  /// Optional footer widget (e.g., App version, settings).
  final Widget? footer;

  /// Width of the sidebar.
  final double width;

  /// Background color of the entire sidebar.
  final Color? backgroundColor;

  /// Outer padding of the sidebar.
  final EdgeInsetsGeometry padding;

  /// Spacing between individual items.
  final double itemSpacing;

  /// Spacing between the header and the list of items.
  final double headerSpacing;

  /// Spacing between the list of items and the footer.
  final double footerSpacing;

  /// Primary color used for selected items and icons.
  final Color? primaryColor;

  /// Color used for unselected items.
  final Color? onSurfaceColor;

  /// Color used for danger/destructive items (like logout).
  final Color dangerColor;

  /// Text style for the labels.
  final TextStyle? textStyle;

  /// Background color when an item is selected.
  final Color? selectedBackgroundColor;

  /// Background color when an item is hovered.
  final Color? hoverBackgroundColor;

  /// BorderRadius of the item selection background.
  final BorderRadiusGeometry? itemBorderRadius;

  /// Height of an individual item.
  final double itemHeight;

  /// Inner padding of an individual item.
  final EdgeInsetsGeometry itemPadding;

  const StandardNavigationSidebar({
    super.key,
    required this.items,
    this.header,
    this.footer,
    this.width = 280,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(16),
    this.itemSpacing = 8,
    this.headerSpacing = 24,
    this.footerSpacing = 8,
    this.primaryColor,
    this.onSurfaceColor,
    this.dangerColor = Colors.red,
    this.textStyle,
    this.selectedBackgroundColor,
    this.hoverBackgroundColor,
    this.itemBorderRadius,
    this.itemHeight = 48,
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 14),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.surface;

    return Container(
      width: width,
      padding: padding,
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[header!, SizedBox(height: headerSpacing)],

          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, __) => SizedBox(height: itemSpacing),
              itemBuilder: (context, index) {
                return _SidebarItemWidget(
                  item: items[index],
                  primaryColor: primaryColor ?? theme.colorScheme.primary,
                  onSurfaceColor: onSurfaceColor ?? theme.colorScheme.onSurface,
                  dangerColor: dangerColor,
                  textStyle: textStyle ?? theme.textTheme.bodyLarge,
                  selectedBackgroundColor: selectedBackgroundColor,
                  hoverBackgroundColor: hoverBackgroundColor,
                  itemBorderRadius: itemBorderRadius,
                  itemHeight: itemHeight,
                  itemPadding: itemPadding,
                );
              },
            ),
          ),

          if (footer != null) ...[SizedBox(height: footerSpacing), footer!],
        ],
      ),
    );
  }
}

class _SidebarItemWidget extends StatefulWidget {
  final NavigationSidebarItem item;
  final Color primaryColor;
  final Color onSurfaceColor;
  final Color dangerColor;
  final TextStyle? textStyle;
  final Color? selectedBackgroundColor;
  final Color? hoverBackgroundColor;
  final BorderRadiusGeometry? itemBorderRadius;
  final double itemHeight;
  final EdgeInsetsGeometry itemPadding;

  const _SidebarItemWidget({
    required this.item,
    required this.primaryColor,
    required this.onSurfaceColor,
    required this.dangerColor,
    required this.textStyle,
    required this.selectedBackgroundColor,
    required this.hoverBackgroundColor,
    required this.itemBorderRadius,
    required this.itemHeight,
    required this.itemPadding,
  });

  @override
  State<_SidebarItemWidget> createState() => _SidebarItemWidgetState();
}

class _SidebarItemWidgetState extends State<_SidebarItemWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine foreground color
    Color fg;
    if (widget.item.isDanger) {
      fg = widget.dangerColor;
    } else if (widget.item.isSelected) {
      fg = widget.item.selectedColor ?? widget.primaryColor;
    } else {
      fg =
          widget.item.itemColor ??
          widget.onSurfaceColor.withValues(alpha: 0.85);
    }

    // Determine background color based on state
    final hoverColor =
        widget.hoverBackgroundColor ??
        theme.colorScheme.onSurface.withValues(alpha: 0.06);
    final selectedColor =
        widget.selectedBackgroundColor ??
        widget.primaryColor.withValues(alpha: 0.12);

    final bgColor = widget.item.isSelected
        ? selectedColor
        : _hovered
        ? hoverColor
        : Colors.transparent;

    final borderRadius = widget.itemBorderRadius ?? BorderRadius.circular(14);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: widget.itemHeight,
        decoration: BoxDecoration(borderRadius: borderRadius, color: bgColor),
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: borderRadius as BorderRadius?,
            onTap: widget.item.onTap,
            child: Padding(
              padding: widget.itemPadding,
              child: Row(
                children: [
                  Icon(widget.item.icon, size: 22, color: fg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.item.label,
                      style: widget.textStyle?.copyWith(
                        color: fg,
                        fontWeight: widget.item.isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.item.badgeCount != null &&
                      widget.item.badgeCount! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: widget.dangerColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.item.badgeCount! > 99
                            ? '99+'
                            : widget.item.badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// example 
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:go_router/go_router.dart';
// import 'package:idara_esign/config/routes/route_names.dart';
// import 'package:idara_esign/config/theme/theme_extensions.dart';
// import 'package:idara_esign/core/widgets/widgets.dart';
// import 'package:idara_esign/features/auth/presentation/bloc/auth_bloc.dart';
// import 'package:idara_esign/features/dashboard/presentation/bloc/dashboard_bloc.dart';
// import 'package:idara_esign/features/document/presentation/bloc/documnet/document_bloc.dart';
// import 'package:idara_esign/features/notifications/presentation/bloc/notifications_bloc.dart';
// import 'package:idara_esign/features/participants/presentation/bloc/participants_bloc.dart';
// import 'package:idara_esign/generated/l10n.dart';

// class AppSidebar extends StatelessWidget {
//   const AppSidebar({super.key, required this.currentLocation});

//   final String currentLocation;

//   static const List<String> _branchPaths = <String>[
//     Routes.userDashboard,
//     Routes.userDocuments,
//     Routes.userParticipants,
//     Routes.account,
//     Routes.transactions,
//     Routes.packages,
//     Routes.userSignatures,
//     Routes.userStamps,
//     Routes.profileDetails,
//     Routes.notifications,
//     Routes.settings,
//   ];

//   static const Map<String, int> _overrides = <String, int>{
//     Routes.participantForm: 2,
//     Routes.participantDetails: 2,
//     Routes.participantSelection: 2,
//     Routes.userSignatureCreate: 6,
//     Routes.userSignatureEdit: 6,
//     Routes.userSignatureSelection: 6,
//     Routes.userSignaturePlacement: 1,
//     Routes.userStampCreate: 7,
//     Routes.userStampEdit: 7,
//     Routes.userStampSelection: 7,
//     Routes.userDocumentCreate: 1,
//     Routes.userDocumentViewerPath: 1,
//     Routes.userDocumentApproverPath: 1,
//     Routes.userDocumentLogs: 1,
//     Routes.userDocumentDetails: 1,
//     Routes.userDigitalSigning: 1,
//   };

//   static int selectedIndexFor(String location) {
//     for (final entry in _overrides.entries) {
//       final overridePath = entry.key;
//       final cleanPath = overridePath.contains('/:')
//           ? overridePath.substring(0, overridePath.indexOf('/:'))
//           : overridePath;
//       if (location == cleanPath || location.startsWith('$cleanPath/')) {
//         return entry.value;
//       }
//     }
//     for (var i = 0; i < _branchPaths.length; i++) {
//       final p = _branchPaths[i];
//       if (location == p || location.startsWith('$p/')) return i;
//     }
//     return -1;
//   }

//   void _go(BuildContext context, int index) {
//     // --- TEMPORARY REFRESH FEATURE ---
//     // Forces the selected tab's data to refresh from scratch when navigating to it.
//     // If you want to remove this feature in the future, simply delete this switch block.
//     switch (_branchPaths[index]) {
//       case Routes.userDashboard:
//         context.read<DashboardBloc>().add(const LoadDashboardEvent());
//         break;
//       case Routes.userDocuments:
//         context.read<DocumentBloc>().add(const DocumentsRefreshEvent());
//         break;
//       case Routes.userParticipants:
//         context.read<ParticipantsBloc>().add(const ParticipantsRefreshEvent());
//         break;
//       case Routes.notifications:
//         context.read<NotificationsBloc>().add(
//           const NotificationsRefreshEvent(),
//         );
//         break;
//     }
//     // ---------------------------------

//     context.goNamed(_branchPaths[index]);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final surface = context.colors.surface;
//     final primary = context.colors.primary;
//     final onSurface = context.colors.onSurface;
//     final selectedIdx = selectedIndexFor(currentLocation);

//     return StandardNavigationSidebar(
//       width: 280,
//       backgroundColor: surface,
//       primaryColor: primary,
//       onSurfaceColor: onSurface,
//       header: const ProfileHeaderWidget(),
//       footer: const Column(
//         children: [
//           SizedBox(height: 8),
//           Center(child: AppVersionWidget()),
//           SizedBox(height: 8),
//         ],
//       ),
//       items: [
//         NavigationSidebarItem(
//           isSelected: selectedIdx == 0,
//           icon: Icons.home,
//           label: S.of(context).navHome,
//           onTap: () => _go(context, 0),
//         ),
//         NavigationSidebarItem(
//           isSelected: selectedIdx == 1,
//           icon: Icons.description,
//           label: S.of(context).navDocs,
//           onTap: () => _go(context, 1),
//         ),
//         NavigationSidebarItem(
//           isSelected: selectedIdx == 2,
//           icon: Icons.group,
//           label: S.of(context).navParticipants,
//           onTap: () => _go(context, 2),
//         ),
//         NavigationSidebarItem(
//           isSelected: selectedIdx == 5,
//           icon: Icons.monetization_on_outlined,
//           label: S.of(context).packages,
//           onTap: () => _go(context, 5),
//         ),
//         NavigationSidebarItem(
//           isSelected: selectedIdx == 4,
//           icon: Icons.payment_outlined,
//           label: S.of(context).transactionsTitle,
//           onTap: () => _go(context, 4),
//         ),
//         NavigationSidebarItem(
//           isSelected: selectedIdx == 6,
//           icon: Icons.draw_outlined,
//           label: S.of(context).mySignatures,
//           onTap: () => _go(context, 6),
//         ),
//         NavigationSidebarItem(
//           isSelected: selectedIdx == 7,
//           icon: Icons.approval_outlined,
//           label: S.of(context).myStamps,
//           onTap: () => _go(context, 7),
//         ),
//         NavigationSidebarItem(
//           isSelected: selectedIdx == 8,
//           icon: Icons.person_outline,
//           label: S.of(context).profileDetails,
//           onTap: () => _go(context, 8),
//         ),
//         NavigationSidebarItem(
//           isSelected: selectedIdx == 9,
//           icon: Icons.notifications_outlined,
//           label: S.of(context).navNotifications,
//           onTap: () => _go(context, 9),
//           badgeCount: context.watch<NotificationsBloc>().state.unreadCount,
//         ),
//         NavigationSidebarItem(
//           isSelected: selectedIdx == 10,
//           icon: Icons.settings,
//           label: S.of(context).settings,
//           onTap: () => _go(context, 10),
//         ),
//         NavigationSidebarItem(
//           isSelected: false,
//           icon: Icons.logout,
//           label: S.of(context).logOut,
//           isDanger: true,
//           onTap: () async {
//             final isYes = await Dialogs.showYesNoDialog(
//               context,
//               title: S.of(context).signOut,
//               content: S.of(context).signOutConfirmation,
//             );
//             if (isYes && context.mounted) {
//               context.read<AuthBloc>().add(const LogoutEvent());
//             }
//           },
//         ),
//       ],
//     );
//   }
// }

