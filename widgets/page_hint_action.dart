import 'package:flutter/material.dart';
import 'package:idara_esign/config/theme/theme.dart';

/// An app-bar action that reveals a page's explanatory line on tap.
///
/// A one-sentence page description is helpful the first time and clutter every
/// time after, and on a narrow screen it costs three lines of the list it is
/// describing. Behind an info icon it stays reachable without paying for the
/// space permanently.
///
/// Built on [Tooltip] in manual trigger mode rather than a dialog or a sheet:
/// the framework already handles anchoring, screen-edge flipping and
/// dismiss-on-tap-outside, and hovering still works on the web.
class PageHintAction extends StatefulWidget {
  const PageHintAction({
    super.key,
    required this.message,
    this.semanticLabel,
    this.icon = Icons.info_outline,
  });

  final String message;

  /// Read instead of the icon by a screen reader. The message itself is
  /// announced when the tooltip opens, so this only has to name the control.
  final String? semanticLabel;

  final IconData icon;

  @override
  State<PageHintAction> createState() => _PageHintActionState();
}

class _PageHintActionState extends State<PageHintAction> {
  final _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Tooltip(
      key: _tooltipKey,
      message: widget.message,
      // Manual: the IconButton consumes the tap, so the button opens the
      // tooltip itself instead of competing with Tooltip's own gesture.
      triggerMode: TooltipTriggerMode.manual,
      showDuration: const Duration(seconds: 8),
      preferBelow: true,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      textStyle: context.textTheme.bodySmall?.copyWith(
        color: colors.onInverseSurface,
        height: 1.4,
      ),
      decoration: BoxDecoration(
        color: colors.inverseSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        // No `tooltip:` here — it would fight the wrapper for the same gesture.
        onPressed: () => _tooltipKey.currentState?.ensureTooltipVisible(),
        icon: Icon(widget.icon, size: 20),
        color: colors.onSurfaceVariant,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
        splashRadius: 20,
      ),
    );
  }
}
