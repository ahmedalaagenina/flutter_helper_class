import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// Public entry types
// ─────────────────────────────────────────────

/// Base class for sidebar navigation entries.
sealed class NavEntry {
  const NavEntry();
}

/// A single tappable navigation item.
class NavItem extends NavEntry {
  const NavItem({
    required this.index,
    required this.icon,
    required this.label,
    this.badgeCount,
    this.isDanger = false,
    this.onTap,
  });

  final int index;
  final IconData icon;
  final String label;
  final int? badgeCount;
  final bool isDanger;
  final VoidCallback? onTap;
}

/// A collapsible group that contains [NavItem] children.
class NavGroup extends NavEntry {
  const NavGroup({
    required this.key,
    required this.icon,
    required this.label,
    required this.children,
  });

  final String key;
  final IconData icon;
  final String label;
  final List<NavItem> children;
}

// ─────────────────────────────────────────────
// CollapsibleNavSidebar
// ─────────────────────────────────────────────

/// A vertical sidebar with flat items and collapsible groups.
///
/// Usage:
/// ```dart
/// CollapsibleNavSidebar(
///   entries: [
///     NavItem(index: 0, icon: Icons.home, label: 'Home'),
///     NavGroup(
///       key: 'finance',
///       icon: Icons.account_balance_outlined,
///       label: 'Finance',
///       children: [
///         NavItem(index: 1, icon: Icons.wallet, label: 'Wallets'),
///         NavItem(index: 2, icon: Icons.receipt, label: 'Transactions'),
///       ],
///     ),
///   ],
///   selectedIndex: 0,
///   onIndexSelected: (i) => setState(() => _index = i),
///   header: Image.asset('assets/logo.png'),
///   footer: TextButton(onPressed: logout, child: Text('Logout')),
/// )
/// ```
class CollapsibleNavSidebar extends StatefulWidget {
  const CollapsibleNavSidebar({
    super.key,
    required this.entries,
    required this.selectedIndex,
    required this.onIndexSelected,
    this.header,
    this.footer,
    this.width = 270,
    this.backgroundColor,
    this.borderColor,
    this.activeColor,
  });

  /// The navigation tree. Mix [NavItem] and [NavGroup] freely.
  final List<NavEntry> entries;

  /// The currently active branch index.
  final int selectedIndex;

  /// Called when the user taps a navigation item.
  final ValueChanged<int> onIndexSelected;

  /// Optional widget shown above the nav list (e.g. logo).
  final Widget? header;

  /// Optional widget shown below the nav list (e.g. logout button).
  final Widget? footer;

  /// Sidebar width. Defaults to 270.
  final double width;

  /// Background color. Defaults to [ColorScheme.surface].
  final Color? backgroundColor;

  /// Right border color. Defaults to [ColorScheme.outlineVariant].
  final Color? borderColor;

  /// Accent color for active items. Defaults to [ColorScheme.primary].
  final Color? activeColor;

  @override
  State<CollapsibleNavSidebar> createState() => _CollapsibleNavSidebarState();
}

class _CollapsibleNavSidebarState extends State<CollapsibleNavSidebar> {
  String? _expandedKey;
  int? _lastSyncedIndex;

  @override
  void didUpdateWidget(CollapsibleNavSidebar old) {
    super.didUpdateWidget(old);
    // Auto-expand the group that contains the newly active index.
    _syncExpandedGroup();
  }

  void _syncExpandedGroup() {
    if (_lastSyncedIndex == widget.selectedIndex) return;
    _lastSyncedIndex = widget.selectedIndex;

    for (final entry in widget.entries) {
      if (entry is NavGroup) {
        final match = entry.children.any(
          (c) => c.index == widget.selectedIndex,
        );
        if (match) {
          // Only expand; never collapse an already-open group on navigation.
          if (_expandedKey != entry.key) {
            setState(() => _expandedKey = entry.key);
          }
          return;
        }
      }
    }
  }

  void _toggleGroup(String key) {
    setState(() {
      _expandedKey = _expandedKey == key ? null : key;
    });
  }

  @override
  Widget build(BuildContext context) {
    _syncExpandedGroup();

    final cs = Theme.of(context).colorScheme;
    final bg = widget.backgroundColor ?? cs.surface;
    final border = widget.borderColor ?? cs.outlineVariant;
    final active = widget.activeColor ?? cs.primary;

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────
              if (widget.header != null) ...[
                widget.header!,
                const SizedBox(height: 24),
              ],

              // ── Nav list ────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in widget.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _buildEntry(entry, active, cs),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Footer ──────────────────────────────────
              if (widget.footer != null) ...[
                const SizedBox(height: 8),
                Divider(color: border, height: 1),
                const SizedBox(height: 16),
                widget.footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntry(NavEntry entry, Color active, ColorScheme cs) {
    return switch (entry) {
      NavItem() => _NavItemTile(
          item: entry,
          active: entry.index == widget.selectedIndex,
          activeColor: active,
          cs: cs,
          onTap: () => widget.onIndexSelected(entry.index),
        ),
      NavGroup() => _NavGroupTile(
          group: entry,
          expanded: _expandedKey == entry.key,
          selectedIndex: widget.selectedIndex,
          activeColor: active,
          cs: cs,
          onHeaderTap: () => _toggleGroup(entry.key),
          onItemTap: widget.onIndexSelected,
        ),
    };
  }
}

// ─────────────────────────────────────────────
// _NavItemTile  (top-level leaf)
// ─────────────────────────────────────────────

class _NavItemTile extends StatelessWidget {
  const _NavItemTile({
    required this.item,
    required this.active,
    required this.activeColor,
    required this.cs,
    required this.onTap,
  });

  final NavItem item;
  final bool active;
  final Color activeColor;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = item.isDanger ? Colors.red : activeColor;
    final iconColor = item.isDanger ? Colors.red : (active ? effectiveActiveColor : cs.onSurfaceVariant);
    final textColor = item.isDanger ? Colors.red : (active ? effectiveActiveColor : cs.onSurface);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: item.onTap ?? onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active && !item.isDanger
                ? effectiveActiveColor.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 20,
                color: iconColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: textColor,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (item.badgeCount != null && item.badgeCount! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${item.badgeCount}',
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
    );
  }
}

// ─────────────────────────────────────────────
// _NavGroupTile  (accordion header + children)
// ─────────────────────────────────────────────

class _NavGroupTile extends StatelessWidget {
  const _NavGroupTile({
    required this.group,
    required this.expanded,
    required this.selectedIndex,
    required this.activeColor,
    required this.cs,
    required this.onHeaderTap,
    required this.onItemTap,
  });

  final NavGroup group;
  final bool expanded;
  final int selectedIndex;
  final Color activeColor;
  final ColorScheme cs;
  final VoidCallback onHeaderTap;
  final ValueChanged<int> onItemTap;

  bool get _hasActiveChild =>
      group.children.any((c) => c.index == selectedIndex);

  @override
  Widget build(BuildContext context) {
    final headerActive = _hasActiveChild || expanded;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          // ── Group header ──────────────────────────────
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onHeaderTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _hasActiveChild && !expanded
                      ? activeColor.withValues(alpha: 0.06)
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    // Icon badge
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: headerActive
                            ? activeColor.withValues(alpha: 0.12)
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        group.icon,
                        size: 18,
                        color: headerActive ? activeColor : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        group.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: headerActive ? activeColor : cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // Active-child dot when group is collapsed
                    if (_hasActiveChild && !expanded)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsetsDirectional.only(end: 8),
                        decoration: BoxDecoration(
                          color: activeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    // Chevron
                    AnimatedRotation(
                      turns: expanded ? 0.0 : -0.25,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 22,
                        color: headerActive ? activeColor : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Children (animated) ───────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(sizeFactor: animation, child: child),
              ),
              child: expanded
                  ? _GroupChildren(
                      key: ValueKey('children-${group.key}'),
                      children: group.children,
                      selectedIndex: selectedIndex,
                      activeColor: activeColor,
                      cs: cs,
                      onTap: onItemTap,
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _GroupChildren  (tree line + child tiles)
// ─────────────────────────────────────────────

class _GroupChildren extends StatelessWidget {
  const _GroupChildren({
    super.key,
    required this.children,
    required this.selectedIndex,
    required this.activeColor,
    required this.cs,
    required this.onTap,
  });

  final List<NavItem> children;
  final int selectedIndex;
  final Color activeColor;
  final ColorScheme cs;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: 26,
        end: 4,
        top: 4,
        bottom: 8,
      ),
      child: Stack(
        children: [
          // Vertical tree line
          PositionedDirectional(
            start: 0,
            top: 6,
            bottom: 6,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in children)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _NavChildTile(
                      item: item,
                      active: item.index == selectedIndex,
                      activeColor: activeColor,
                      cs: cs,
                      onTap: () => onTap(item.index),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _NavChildTile  (child inside a group)
// ─────────────────────────────────────────────

class _NavChildTile extends StatelessWidget {
  const _NavChildTile({
    required this.item,
    required this.active,
    required this.activeColor,
    required this.cs,
    required this.onTap,
  });

  final NavItem item;
  final bool active;
  final Color activeColor;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = item.isDanger ? Colors.red : activeColor;
    final iconColor = item.isDanger ? Colors.red : (active ? effectiveActiveColor : cs.onSurfaceVariant);
    final textColor = item.isDanger ? Colors.red : (active ? effectiveActiveColor : cs.onSurface);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: item.onTap ?? onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: active && !item.isDanger
                ? effectiveActiveColor.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 18,
                color: iconColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (item.badgeCount != null && item.badgeCount! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsetsDirectional.only(end: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${item.badgeCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              // Active dot
              if (active && !item.isDanger)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: effectiveActiveColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
