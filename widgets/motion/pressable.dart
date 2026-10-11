import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

// Relative on purpose: the motion/ folder is copied into apps as one unit.
// ignore: always_use_package_imports
import 'cursor_follower.dart';
// ignore: always_use_package_imports
import 'springs.dart';

/// One building block for anything tappable (buttons, links, cards), with
/// hover, keyboard focus, a springy press and correct accessibility built
/// in. You draw the look; it handles the behaviour.
///
/// ```dart
/// Pressable(
///   semanticLabel: l10n.downloadCv,
///   onTap: downloadCv,
///   builder: (context, states) => AnimatedContainer(
///     duration: const Duration(milliseconds: 160),
///     color: states.contains(WidgetState.hovered) ? hoverColor : color,
///     child: Text(l10n.downloadCv),
///   ),
/// );
/// ```
///
/// * Keyboard: Tab focuses it, Enter/Space activates it, and a focus ring
///   is drawn for keyboard users only (never on mouse clicks).
/// * Screen readers hear [semanticLabel] once (the visual child is
///   excluded), as a button, or as a link when [linkUrl] is set.
/// * Press feedback is a spring scale; reduced motion turns it off.
/// * Grows the `CursorFollower` ring on hover when one is present.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.builder,
    required this.semanticLabel,
    this.onTap,
    this.linkUrl,
    this.tooltip,
    this.pressScale = 0.96,
    this.focusRadius = 12,
    this.focusColor,
    this.mouseCursor = SystemMouseCursors.click,
  });

  /// Builds the visuals for the current states ([WidgetState.hovered],
  /// [WidgetState.pressed], [WidgetState.focused], [WidgetState.disabled]).
  final Widget Function(BuildContext context, Set<WidgetState> states) builder;

  /// What a screen reader announces.
  final String semanticLabel;

  /// Called on tap, Enter or Space. Null disables the widget.
  final VoidCallback? onTap;

  /// When set, the widget is announced as a link to this URL. Opening the
  /// URL is still up to [onTap] (e.g. with url_launcher in your app).
  final Uri? linkUrl;
  final String? tooltip;

  /// Scale while pressed (1 = no press effect).
  final double pressScale;

  /// Corner radius of the keyboard focus ring.
  final double focusRadius;

  /// Focus ring color; defaults to the theme's primary color.
  final Color? focusColor;
  final MouseCursor mouseCursor;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  bool _hovered = false;
  bool _pressed = false;
  bool _focusVisible = false;
  CursorController? _cursor;

  bool get _enabled => widget.onTap != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cursor = CursorScope.maybeOf(context);
  }

  @override
  void dispose() {
    if (_hovered) _cursor?.exit();
    _scale.dispose();
    super.dispose();
  }

  void _activate() => widget.onTap?.call();

  void _springTo(double target) {
    if (context.reduceMotion) {
      _scale.value = 1;
      return;
    }
    _scale.animateWith(
      SpringSimulation(Springs.snappy, _scale.value, target, _scale.velocity),
    );
  }

  void _setPressed(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
    _springTo(pressed ? widget.pressScale : 1);
  }

  void _setHovered(bool hovered) {
    if (_hovered == hovered) return;
    setState(() => _hovered = hovered);
    hovered ? _cursor?.enter() : _cursor?.exit();
  }

  @override
  Widget build(BuildContext context) {
    final states = <WidgetState>{
      if (_hovered) WidgetState.hovered,
      if (_pressed) WidgetState.pressed,
      if (_focusVisible) WidgetState.focused,
      if (!_enabled) WidgetState.disabled,
    };

    Widget child = FocusableActionDetector(
      enabled: _enabled,
      mouseCursor: _enabled ? widget.mouseCursor : MouseCursor.defer,
      onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
      onShowHoverHighlight: _setHovered,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _setPressed(true) : null,
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTapCancel: _enabled ? () => _setPressed(false) : null,
        onTap: _enabled ? _activate : null,
        child: CustomPaint(
          foregroundPainter: _FocusRingPainter(
            visible: _focusVisible,
            radius: widget.focusRadius,
            color: widget.focusColor ?? Theme.of(context).colorScheme.primary,
          ),
          child: ScaleTransition(
            scale: _scale,
            child: widget.builder(context, states),
          ),
        ),
      ),
    );

    child = Semantics(
      button: widget.linkUrl == null,
      link: widget.linkUrl != null,
      linkUrl: widget.linkUrl,
      enabled: _enabled,
      label: widget.semanticLabel,
      onTap: _enabled ? _activate : null,
      excludeSemantics: true,
      child: child,
    );

    final tooltip = widget.tooltip;
    if (tooltip != null) {
      child = Tooltip(message: tooltip, excludeFromSemantics: true, child: child);
    }
    return child;
  }
}

/// Draws a 2px ring just outside the widget, only for keyboard focus.
class _FocusRingPainter extends CustomPainter {
  _FocusRingPainter({
    required this.visible,
    required this.radius,
    required this.color,
  });

  final bool visible;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).inflate(3),
        Radius.circular(radius + 3),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.visible != visible || old.radius != radius || old.color != color;
}
