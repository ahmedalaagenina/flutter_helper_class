import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

// Relative on purpose: the motion/ folder is copied into apps as one unit.
// ignore: always_use_package_imports
import 'spring_offset.dart';
// ignore: always_use_package_imports
import 'springs.dart';

/// Rotates its child in 3D toward the mouse, with real perspective, like a
/// card or phone you can look around.
///
/// By default the angle follows the mouse over the widget. Pass [input]
/// (an offset in -1..1 on both axes) to drive it from anything else:
/// scroll position, a page offset, the mouse over a bigger area.
///
/// ```dart
/// Tilt(
///   maxAngle: 0.15,
///   overlayBuilder: (context, tilt) => Glare(tilt: tilt), // optional shine
///   child: ProductCard(product),
/// );
/// ```
///
/// * Perspective comes from matrix entry (3, 2): without it a rotation
///   around X or Y just squashes the widget flat.
/// * Its own RepaintBoundary: tilting never repaints the surrounding screen.
/// * Off with reduced motion.
class Tilt extends StatefulWidget {
  const Tilt({
    super.key,
    required this.child,
    this.input,
    this.maxAngle = 0.14,
    this.perspective = 0.0011,
    this.overlayBuilder,
    this.spring,
  });

  final Widget child;

  /// External tilt source in -1..1. When null, the mouse over this widget
  /// drives the tilt.
  final ValueListenable<Offset>? input;

  /// Maximum rotation per axis, in radians (0.14 rad is about 8 degrees).
  final double maxAngle;

  /// Strength of the perspective effect.
  final double perspective;

  /// Optional layer painted on top of the child, receiving the current
  /// normalized tilt (for a glare that moves with the angle).
  final Widget Function(BuildContext context, Offset tilt)? overlayBuilder;

  /// Spring used to follow the input; defaults to [Springs.gentle].
  final SpringDescription? spring;

  @override
  State<Tilt> createState() => _TiltState();
}

class _TiltState extends State<Tilt> with SingleTickerProviderStateMixin {
  late final _tilt = SpringOffset(
    vsync: this,
    spring: widget.spring ?? Springs.gentle,
  );

  @override
  void initState() {
    super.initState();
    widget.input?.addListener(_onInput);
  }

  @override
  void didUpdateWidget(Tilt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.input != widget.input) {
      oldWidget.input?.removeListener(_onInput);
      widget.input?.addListener(_onInput);
    }
    if (widget.spring != null) _tilt.spring = widget.spring!;
  }

  @override
  void dispose() {
    widget.input?.removeListener(_onInput);
    _tilt.dispose();
    super.dispose();
  }

  void _onInput() {
    final input = widget.input;
    if (input != null) _tilt.animateTo(_clamp(input.value));
  }

  Offset _clamp(Offset o) =>
      Offset(o.dx.clamp(-1.0, 1.0), o.dy.clamp(-1.0, 1.0));

  void _onHover(PointerHoverEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final size = box.size;
    _tilt.animateTo(
      _clamp(
        Offset(
          event.localPosition.dx / size.width * 2 - 1,
          event.localPosition.dy / size.height * 2 - 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return widget.child;

    Widget result = AnimatedBuilder(
      animation: _tilt,
      builder: (context, child) {
        final t = _tilt.value;
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, widget.perspective)
          ..rotateX(-t.dy * widget.maxAngle)
          ..rotateY(t.dx * widget.maxAngle);
        final overlay = widget.overlayBuilder;
        return Transform(
          transform: matrix,
          alignment: Alignment.center,
          child: overlay == null
              ? child
              : Stack(
                  children: [
                    child!,
                    Positioned.fill(
                      child: IgnorePointer(child: overlay(context, t)),
                    ),
                  ],
                ),
        );
      },
      child: widget.child,
    );

    result = RepaintBoundary(child: result);

    if (widget.input == null) {
      result = MouseRegion(
        opaque: false,
        onHover: _onHover,
        onExit: (_) => _tilt.animateTo(Offset.zero),
        child: result,
      );
    }
    return result;
  }
}
