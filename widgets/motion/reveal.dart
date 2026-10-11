import 'dart:async';

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

// Relative on purpose: the motion/ folder is copied into apps as one unit.
// ignore: always_use_package_imports
import 'springs.dart';
// ignore: always_use_package_imports
import 'viewport_visibility.dart';

/// Fades and springs its child into place the first time it scrolls into
/// view.
///
/// Use it for entrances that carry meaning (cards of a timeline arriving in
/// order), not on every section: one orchestrated moment reads better than
/// everything sliding in.
///
/// ```dart
/// ListView(
///   children: [
///     for (final (i, item) in items.indexed)
///       Reveal(delay: Duration(milliseconds: 60 * i), child: ItemCard(item)),
///   ],
/// );
/// ```
///
/// * Plays once. After the entrance it stops tracking scrolling and stops
///   wrapping the child, so a revealed widget costs what the plain child
///   costs. A GlobalKey keeps the child's State while the wrappers go away.
/// * The child is cached in a RepaintBoundary during the entrance, so each
///   frame only updates an opacity/transform layer.
/// * Reduced motion shows the child immediately.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 28),
    this.scale = 1,
    this.threshold = 0.12,
    this.spring,
  });

  final Widget child;

  /// Wait before playing once visible (handy for staggering siblings).
  final Duration delay;

  /// Where the child starts, relative to its final position (pixels).
  final Offset offset;

  /// Starting scale (1 = no scale).
  final double scale;

  /// Fraction of the child that must be visible to start.
  final double threshold;

  /// Spring used for the entrance; defaults to [Springs.gentle].
  final SpringDescription? spring;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal>
    with SingleTickerProviderStateMixin, ViewportVisibilityMixin {
  late final AnimationController _progress = AnimationController.unbounded(
    vsync: this,
  );
  final GlobalKey _childKey = GlobalKey();
  Timer? _delayTimer;
  bool _started = false;
  bool _done = false;

  @override
  void onVisibleFractionChanged(double fraction) {
    if (_started || fraction < widget.threshold) return;
    _started = true;
    stopVisibilityTracking();
    if (widget.delay == Duration.zero) {
      _play();
    } else {
      _delayTimer = Timer(widget.delay, _play);
    }
  }

  void _play() {
    if (!mounted) return;
    if (context.reduceMotion) {
      setState(() => _done = true);
      return;
    }
    _progress
        .animateWith(SpringSimulation(widget.spring ?? Springs.gentle, 0, 1, 0))
        .whenComplete(() {
          if (mounted) setState(() => _done = true);
        });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = KeyedSubtree(key: _childKey, child: widget.child);
    if (_done || context.reduceMotion) return child;
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final t = _progress.value;
        final scale = widget.scale + (1 - widget.scale) * t;
        // Translate + scale widgets instead of a hand-built Matrix4: works
        // on any Flutter version (Matrix4.scaleByDouble is recent).
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: widget.offset * (1 - t),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: RepaintBoundary(child: child),
    );
  }
}
