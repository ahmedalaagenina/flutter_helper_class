import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One action in a [CommandPalette] (e.g. "Go to settings", "Copy email").
class PaletteItem {
  const PaletteItem({
    required this.label,
    required this.icon,
    required this.onSelect,
    this.hint,
    this.keywords = const [],
  });

  final String label;
  final Widget icon;

  /// Runs after the palette closes.
  final VoidCallback onSelect;

  /// Small text on the right (defaults to the group title).
  final String? hint;

  /// Extra search terms, e.g. `['mail', 'contact']` for a "Send email" item.
  final List<String> keywords;
}

/// A titled group of [PaletteItem]s (e.g. "Pages", "Actions").
class PaletteGroup {
  const PaletteGroup({required this.title, required this.items});

  final String title;
  final List<PaletteItem> items;
}

/// A ⌘K / Ctrl+K style search box that lists actions: type to filter,
/// ↑/↓ to move, Enter to run, Esc to close.
///
/// ```dart
/// CommandPalette.show(
///   context,
///   searchHint: l10n.searchActions,
///   noMatchesText: l10n.noMatches,
///   groups: [
///     PaletteGroup(title: l10n.pages, items: [
///       PaletteItem(label: l10n.settings, icon: const Icon(Icons.settings),
///           onSelect: () => context.go('/settings')),
///     ]),
///   ],
/// );
/// ```
///
/// * Matches the label, the group title and each item's keywords.
/// * The keyboard selection always stays scrolled into view; hovering a row
///   selects it too, so mouse and keyboard never disagree.
/// * Styled from the ambient Theme (colorScheme and textTheme).
/// * Use [CommandPaletteShortcut] to open it with ⌘K / Ctrl+K.
class CommandPalette extends StatefulWidget {
  const CommandPalette({
    super.key,
    required this.groups,
    required this.searchHint,
    required this.noMatchesText,
    this.maxWidth = 560,
  });

  final List<PaletteGroup> groups;
  final String searchHint;
  final String noMatchesText;
  final double maxWidth;

  /// Opens the palette as a dialog.
  static Future<void> show(
    BuildContext context, {
    required List<PaletteGroup> groups,
    required String searchHint,
    required String noMatchesText,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => CommandPalette(
        groups: groups,
        searchHint: searchHint,
        noMatchesText: noMatchesText,
      ),
    );
  }

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  static const double _rowHeight = 46;

  final _query = TextEditingController();
  final _scroll = ScrollController();
  int _selected = 0;

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<(String, PaletteItem)> get _results {
    final q = _query.text.trim().toLowerCase();
    return [
      for (final group in widget.groups)
        for (final item in group.items)
          if (q.isEmpty ||
              item.label.toLowerCase().contains(q) ||
              group.title.toLowerCase().contains(q) ||
              item.keywords.any((k) => k.toLowerCase().contains(q)))
            (group.title, item),
    ];
  }

  void _move(int delta, int count) {
    if (count == 0) return;
    setState(() => _selected = (_selected + delta) % count);
    if (!_scroll.hasClients) return;
    final top = _selected * _rowHeight;
    final viewport = _scroll.position.viewportDimension;
    if (top < _scroll.offset) {
      _scroll.jumpTo(top);
    } else if (top + _rowHeight > _scroll.offset + viewport) {
      _scroll.jumpTo(top + _rowHeight - viewport);
    }
  }

  void _run(PaletteItem item) {
    Navigator.of(context).pop();
    item.onSelect();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final results = _results;
    if (_selected >= results.length) _selected = 0;

    return Align(
      alignment: const Alignment(0, -0.55),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: widget.maxWidth,
            maxHeight: 520,
          ),
          child: Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colors.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                    _move(1, results.length),
                const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                    _move(-1, results.length),
                const SingleActivator(LogicalKeyboardKey.enter): () {
                  if (results.isNotEmpty) _run(results[_selected].$2);
                },
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: colors.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _query,
                            autofocus: true,
                            onChanged: (_) => setState(() => _selected = 0),
                            decoration: InputDecoration(
                              hintText: widget.searchHint,
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colors.outlineVariant),
                  Flexible(
                    child: results.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              widget.noMatchesText,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shrinkWrap: true,
                            itemExtent: _rowHeight,
                            itemCount: results.length,
                            itemBuilder: (context, i) {
                              final (group, item) = results[i];
                              return _PaletteRow(
                                item: item,
                                group: group,
                                selected: i == _selected,
                                onHover: () => setState(() => _selected = i),
                                onTap: () => _run(item),
                              );
                            },
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

class _PaletteRow extends StatelessWidget {
  const _PaletteRow({
    required this.item,
    required this.group,
    required this.selected,
    required this.onHover,
    required this.onTap,
  });

  final PaletteItem item;
  final String group;
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onHover(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? colors.surfaceContainerHighest : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                IconTheme.merge(
                  data: IconThemeData(
                    size: 18,
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                  child: item.icon,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(width: 12),
                // Capped, not Flexible: a Flexible would split the free space
                // with the label and push the hint to the middle of the row.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    item.hint ?? group,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
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

/// Opens a palette with ⌘K on Apple devices and Ctrl+K everywhere else.
///
/// Wrap a page with it; [onOpen] usually calls [CommandPalette.show].
///
/// ```dart
/// CommandPaletteShortcut(
///   onOpen: () => CommandPalette.show(context, groups: groups,
///       searchHint: l10n.search, noMatchesText: l10n.noMatches),
///   child: const HomePage(),
/// );
/// ```
///
/// * Holds keyboard focus for the page (autofocus) so the shortcut works
///   before anything is tapped.
/// * [shortcutLabel] tells you what to show in a hint ("⌘K" or "Ctrl + K").
class CommandPaletteShortcut extends StatelessWidget {
  const CommandPaletteShortcut({
    super.key,
    required this.onOpen,
    required this.child,
  });

  final VoidCallback onOpen;
  final Widget child;

  static bool get _isApple =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// "⌘K" on Apple devices, "Ctrl + K" elsewhere (for hint text).
  static String get shortcutLabel => _isApple ? '⌘K' : 'Ctrl + K';

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): onOpen,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): onOpen,
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
