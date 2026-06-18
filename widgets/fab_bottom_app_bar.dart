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
