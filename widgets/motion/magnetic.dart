import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

// Relative on purpose: the motion/ folder is copied into apps as one unit.
// ignore: always_use_package_imports
import 'spring_offset.dart';
// ignore: always_use_package_imports
import 'springs.dart';

/// Pulls its child a little toward the mouse while hovered, then lets go
/// with a small spring wobble. Makes buttons feel alive on desktop.
///
/// ```dart
/// Magnetic(child: ElevatedButton(onPressed: send, child: Text(l10n.send)));
/// ```
///
/// * Mouse only (touch has no hover), and off with reduced motion.
/// * The movement lives in its own RepaintBoundary, so following the mouse
///   repaints only this widget.
/// * Hit testing follows the moved child, like a real magnet.
class Magnetic extends StatefulWidget {
  const Magnetic({
    super.key,
    required this.child,
    this.strength = 0.3,
    this.maxOffset = 10,
    this.followSpring,
    this.releaseSpring,
  });

  final Widget child;

  /// How much of the pointer's distance from the center the child follows.
  final double strength;

  /// Hard limit on the displacement, in logical pixels.
  final double maxOffset;

  /// Spring while following the mouse; defaults to [Springs.snappy].
  final SpringDescription? followSpring;

  /// Spring when the mouse leaves; defaults to [Springs.playful].
  final SpringDescription? releaseSpring;

  @override
  State<Magnetic> createState() => _MagneticState();
}

class _MagneticState extends State<Magnetic>
    with SingleTickerProviderStateMixin {
  late final _offset = SpringOffset(vsync: this, spring: Springs.snappy);

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _onHover(PointerHoverEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final delta =
        (event.localPosition - box.size.center(Offset.zero)) * widget.strength;
    final distance = delta.distance;
    final clamped = distance > widget.maxOffset
        ? delta * (widget.maxOffset / distance)
        : delta;
    _offset.animateTo(clamped, spring: widget.followSpring ?? Springs.snappy);
  }

  void _onExit(PointerExitEvent _) => _offset.animateTo(
    Offset.zero,
    spring: widget.releaseSpring ?? Springs.playful,
  );

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return widget.child;
    return MouseRegion(
      opaque: false,
      onHover: _onHover,
      onExit: _onExit,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _offset,
          builder: (context, child) =>
              Transform.translate(offset: _offset.value, child: child),
          child: widget.child,
        ),
      ),
    );
  }
}
