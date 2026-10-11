import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a value (an email, a code, a link) with a copy button; tapping it
/// copies the value and the icon morphs into a check with a "Copied" label
/// for a moment.
///
/// ```dart
/// CopyToClipboardButton(
///   text: 'hello@example.com',
///   label: l10n.copyEmail,
///   copiedLabel: l10n.copied,
/// );
/// ```
///
/// * If the browser refuses clipboard access (permissions), it does not
///   claim success: the value stays visible to copy by hand.
/// * Announced as a live region, so screen readers say "Copied".
/// * Keyboard accessible (Tab + Enter/Space), light haptic on success.
/// * Reduced motion swaps the icon without the spin.
class CopyToClipboardButton extends StatefulWidget {
  const CopyToClipboardButton({
    super.key,
    required this.text,
    required this.label,
    required this.copiedLabel,
    this.displayText,
    this.textStyle,
    this.accentColor,
    this.successColor,
    this.backgroundColor,
    this.borderColor,
    this.resetAfter = const Duration(milliseconds: 2200),
    this.showLabel = true,
    this.onCopied,
  });

  /// The value written to the clipboard.
  final String text;

  /// Button label before copying, e.g. "Copy email".
  final String label;

  /// Label after copying, e.g. "Copied".
  final String copiedLabel;

  /// What is shown on the left; defaults to [text].
  final String? displayText;
  final TextStyle? textStyle;

  /// Icon/label color before copying; defaults to the theme's primary.
  final Color? accentColor;

  /// Icon/label/border color after copying; defaults to a green.
  final Color? successColor;
  final Color? backgroundColor;
  final Color? borderColor;

  /// How long the "Copied" state stays before resetting.
  final Duration resetAfter;

  /// Hide the text label (icon only) on narrow layouts.
  final bool showLabel;

  /// Called after a successful copy.
  final VoidCallback? onCopied;

  @override
  State<CopyToClipboardButton> createState() => _CopyToClipboardButtonState();
}

class _CopyToClipboardButtonState extends State<CopyToClipboardButton> {
  bool _copied = false;
  bool _hovered = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.text));
    } on Object {
      // Clipboard blocked (browser permission, insecure context): keep the
      // UI honest and leave the value on screen.
      return;
    }
    if (!mounted) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() => _copied = true);
    widget.onCopied?.call();
    _reset?.cancel();
    _reset = Timer(widget.resetAfter, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final success = widget.successColor ?? const Color(0xFF2E9E6A);
    final accent = _copied ? success : (widget.accentColor ?? colors.primary);
    final reduce = MediaQuery.disableAnimationsOf(context);

    // One semantics node: a button whose label changes to "Copied", marked
    // as a live region so screen readers announce the change. (A live region
    // on an inner Text would be hidden by excludeSemantics.)
    return Semantics(
      button: true,
      liveRegion: true,
      label: _copied
          ? widget.copiedLabel
          : '${widget.label}: ${widget.displayText ?? widget.text}',
      onTap: _copy,
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _copy();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: _copy,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _copied
                    ? success
                    : (_hovered
                          ? accent
                          : (widget.borderColor ?? colors.outlineVariant)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.displayText ?? widget.text,
                      style: widget.textStyle ?? theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: reduce
                            ? Duration.zero
                            : const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOutBack,
                        transitionBuilder: (child, animation) =>
                            RotationTransition(
                              turns: Tween(
                                begin: -0.15,
                                end: 0.0,
                              ).animate(animation),
                              child: ScaleTransition(
                                scale: animation,
                                child: child,
                              ),
                            ),
                        child: Icon(
                          _copied
                              ? Icons.check_rounded
                              : Icons.content_copy_rounded,
                          key: ValueKey(_copied),
                          size: 18,
                          color: accent,
                        ),
                      ),
                      if (widget.showLabel) ...[
                        const SizedBox(width: 8),
                        Text(
                          _copied ? widget.copiedLabel : widget.label,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: accent,
                          ),
                        ),
                      ],
                    ],
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
