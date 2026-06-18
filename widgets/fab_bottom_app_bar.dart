import 'package:flutter/material.dart';

class FABBottomAppBarItem {
  const FABBottomAppBarItem({
    required this.iconData,
    required this.selectedIconData,
    required this.text,
  });

  final IconData iconData;
  final IconData selectedIconData;
  final String text;
}

class FABBottomAppBar extends StatelessWidget {
  const FABBottomAppBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTabSelected,
    this.centerItemText,
    this.height = 64.0,
    this.iconSize = 24.0,
    this.backgroundColor,
    this.color,
    this.selectedColor,
  }) : assert(
         items.length == 2 || items.length == 4,
         'FABBottomAppBar requires exactly 2 or 4 items',
       );

  final List<FABBottomAppBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final String? centerItemText;
  final double height;
  final double iconSize;
  final Color? backgroundColor;
  final Color? color;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    // Build tab items, then insert the center spacer at the midpoint
    final List<Widget> tabs = List.generate(items.length, (index) {
      return _TabItem(
        item: items[index],
        index: index,
        selectedIndex: selectedIndex,
        height: height,
        iconSize: iconSize,
        color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
        selectedColor: selectedColor ?? Theme.of(context).colorScheme.primary,
        onPressed: onTabSelected,
      );
    });

    tabs.insert(
      tabs.length >> 1, // inserts at index 2 for 4 items → perfect center
      _CenterSpacer(
        height: height,
        iconSize: iconSize,
        label: centerItemText,
        color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );

    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      padding: EdgeInsets.zero,
      height: height,
      color: backgroundColor ?? Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: tabs,
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.item,
    required this.index,
    required this.selectedIndex,
    required this.height,
    required this.iconSize,
    required this.color,
    required this.selectedColor,
    required this.onPressed,
  });

  final FABBottomAppBarItem item;
  final int index;
  final int selectedIndex;
  final double height;
  final double iconSize;
  final Color color;
  final Color selectedColor;
  final ValueChanged<int> onPressed;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedIndex == index;
    final iconColor = isSelected ? selectedColor : color;

    return Expanded(
      child: SizedBox(
        height: height,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => onPressed(index),
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    isSelected ? item.selectedIconData : item.iconData,
                    key: ValueKey(isSelected),
                    color: iconColor,
                    size: iconSize,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.text,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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

class _CenterSpacer extends StatelessWidget {
  const _CenterSpacer({
    required this.height,
    required this.iconSize,
    required this.color,
    this.label,
  });

  final double height;
  final double iconSize;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: height,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: iconSize), // aligns baseline with tab icons
            Text(label ?? '', style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}


/// example 
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:go_router/go_router.dart';
// import 'package:idara_esign/config/routes/routes.dart';
// import 'package:idara_esign/config/theme/theme_extensions.dart';
// import 'package:idara_esign/core/responsive/media_query_values.dart';
// import 'package:idara_esign/core/widgets/widgets.dart';
// import 'package:idara_esign/features/dashboard/presentation/bloc/dashboard_bloc.dart';
// import 'package:idara_esign/features/document/presentation/bloc/documnet/document_bloc.dart';
// import 'package:idara_esign/features/transactions/presentation/bloc/transactions_bloc.dart';
// import 'package:idara_esign/generated/l10n.dart';

// class ScaffoldWithNavBar extends StatefulWidget {
//   const ScaffoldWithNavBar({required this.navigationShell, super.key});

//   final StatefulNavigationShell navigationShell;

//   @override
//   State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
// }

// class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
//   @override
//   Widget build(BuildContext context) {
//     final isBiggerThanMobile = context.isBiggerThanMobile;
//     const mobileTabsCount = 4;

//     if (!isBiggerThanMobile &&
//         widget.navigationShell.currentIndex >= mobileTabsCount) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         widget.navigationShell.goBranch(0);
//       });
//     }

//     final s = S.of(context);

//     return Scaffold(
//       extendBody: true,
//       extendBodyBehindAppBar: true,
//       body: isBiggerThanMobile
//           ? Padding(
//               padding: EdgeInsets.symmetric(horizontal: context.width * 0.05),
//               child: widget.navigationShell,
//             )
//           : SafeArea(bottom: false, child: widget.navigationShell),

//       floatingActionButtonLocation: isBiggerThanMobile
//           ? FloatingActionButtonLocation.endFloat
//           : FloatingActionButtonLocation.centerDocked,
//       floatingActionButton: isBiggerThanMobile
//           ? _buildDesktopFAB(context)
//           : _MobileFAB(
//               currentIndex: widget.navigationShell.currentIndex,
//               onPressed: () => _onMobileFabPressed(context),
//               color: context.colors.primary,
//             ),

//       bottomNavigationBar: isBiggerThanMobile
//           ? null
//           : FABBottomAppBar(
//               selectedIndex: widget.navigationShell.currentIndex.clamp(0, 3),
//               onTabSelected: (i) => _onTap(context, i),
//               backgroundColor: context.colors.surface,
//               color: context.colors.onSurfaceVariant,
//               selectedColor: context.colors.primary,
//               items: [
//                 FABBottomAppBarItem(
//                   iconData: Icons.home_outlined,
//                   selectedIconData: Icons.home,
//                   text: s.navHome,
//                 ),
//                 FABBottomAppBarItem(
//                   iconData: Icons.description_outlined,
//                   selectedIconData: Icons.description,
//                   text: s.navDocs,
//                 ),
//                 FABBottomAppBarItem(
//                   iconData: Icons.group_outlined,
//                   selectedIconData: Icons.group,
//                   text: s.navParticipants,
//                 ),
//                 FABBottomAppBarItem(
//                   iconData: Icons.person_outline,
//                   selectedIconData: Icons.person,
//                   text: s.navAccount,
//                 ),
//               ],
//             ),
//     );
//   }

//   void _onTap(BuildContext context, int index) {
//     switch (index) {
//       case 0:
//         context.read<DashboardBloc>().add(const LoadDashboardEvent());
//         context.read<AuthBloc>().add(const CheckAuthStatusEvent());
//       case 1:
//         context.read<DocumentBloc>().add(const DocumentsRefreshEvent());
//       case 2:
//         context.read<ParticipantsBloc>().add(const ParticipantsRefreshEvent());
//     }

//     widget.navigationShell.goBranch(
//       index,
//       initialLocation: index == widget.navigationShell.currentIndex,
//     );
//   }

//   void _onMobileFabPressed(BuildContext context) {
//     switch (widget.navigationShell.currentIndex) {
//       case 2:
//         _navigateToAddParticipant(context);
//       case 3:
//         _navigateToAddCoins(context);
//       default:
//         _navigateToAddDocument(context);
//     }
//   }

//   Future<void> _navigateToAddDocument(BuildContext context) async {
//     final created = await context.pushNamed(Routes.userDocumentCreate);
//     if (context.mounted) _onDocumentCreated(context, created);
//   }

//   void _onDocumentCreated(BuildContext context, dynamic created) {
//     if (context.mounted && created == true) {
//       context.read<DocumentBloc>().add(const DocumentsRefreshEvent());
//       context.read<DocumentBloc>().add(const DocumentClearStatusesEvent());
//       context.read<DashboardBloc>().add(const LoadDashboardEvent());
//       context.read<TransactionsBloc>().add(
//         const TransactionsFetchWalletOverviewEvent(),
//       );
//     }
//   }

//   Future<void> _navigateToAddParticipant(BuildContext context) async {
//     final created = await context.pushNamed(Routes.participantForm);
//     if (context.mounted && created != null) {
//       context.read<ParticipantsBloc>().add(const ParticipantsRefreshEvent());
//     }
//   }

//   Future<void> _navigateToAddCoins(BuildContext context) async {
//     await context.pushNamed(Routes.packagesMobile);
//     if (context.mounted) {
//       context.read<TransactionsBloc>().add(
//         const TransactionsFetchWalletOverviewEvent(),
//       );
//     }
//   }

//   Widget? _buildDesktopFAB(BuildContext context) {
//     final s = S.of(context);

//     return switch (widget.navigationShell.currentIndex) {
//       0 => FloatingActionButton.extended(
//         heroTag: 'fab',
//         onPressed: () async {
//           final created = await context.pushNamed(Routes.userDocumentCreate);
//           if (context.mounted) _onDocumentCreated(context, created);
//         },
//         backgroundColor: context.colors.primary,
//         foregroundColor: Colors.white,
//         icon: const Icon(Icons.add),
//         label: Text(s.addDocument),
//       ),
//       1 => FloatingActionButton.extended(
//         heroTag: 'fab',
//         onPressed: () async {
//           final created = await context.pushNamed(Routes.userDocumentCreate);
//           if (context.mounted) _onDocumentCreated(context, created);
//         },
//         backgroundColor: context.colors.primary,
//         foregroundColor: Colors.white,
//         icon: const Icon(Icons.add),
//         label: Text(s.addDocument),
//       ),
//       2 => FloatingActionButton.extended(
//         heroTag: 'fab',
//         onPressed: () => _navigateToAddParticipant(context),
//         backgroundColor: context.colors.primary,
//         foregroundColor: Colors.white,
//         icon: const Icon(Icons.add),
//         label: Text(s.addParticipant),
//       ),

//       _ => null,
//     };
//   }
// }

// class _MobileFAB extends StatefulWidget {
//   const _MobileFAB({
//     required this.currentIndex,
//     required this.onPressed,
//     required this.color,
//   });

//   final int currentIndex;
//   final VoidCallback onPressed;
//   final Color color;

//   @override
//   State<_MobileFAB> createState() => _MobileFABState();
// }

// class _MobileFABState extends State<_MobileFAB>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _scaleAnim;
//   late IconData _currentIcon;

//   static IconData _iconForIndex(int index) => switch (index) {
//     2 => Icons.person_add_outlined,
//     3 => Icons.add_card_outlined,
//     _ => Icons.add,
//   };

//   @override
//   void initState() {
//     super.initState();
//     _currentIcon = _iconForIndex(widget.currentIndex);

//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 200),
//     );

//     _scaleAnim = Tween<double>(
//       begin: 0.7,
//       end: 1.0,
//     ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
//   }

//   @override
//   void didUpdateWidget(_MobileFAB oldWidget) {
//     super.didUpdateWidget(oldWidget);

//     final newIcon = _iconForIndex(widget.currentIndex);
//     if (newIcon != _currentIcon) {
//       _currentIcon = newIcon;
//       _controller.forward(from: 0.0);
//     }
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FloatingActionButton(
//       heroTag: 'main_fab',
//       onPressed: widget.onPressed,
//       backgroundColor: widget.color,
//       foregroundColor: Colors.white,
//       shape: const CircleBorder(),
//       elevation: 4,
//       child: ScaleTransition(
//         scale: _scaleAnim.status == AnimationStatus.dismissed
//             ? const AlwaysStoppedAnimation(1.0)
//             : _scaleAnim,
//         child: Icon(_currentIcon, size: 28),
//       ),
//     );
//   }
// }

