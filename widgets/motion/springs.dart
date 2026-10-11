// Motion toolkit core. Copy the whole `widgets/motion/` folder into an app:
// the files import each other with relative paths and need nothing but the
// Flutter SDK.
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Ready-made springs, so every animation in an app feels like one physical
/// system instead of a set of unrelated tweens.
///
/// A spring is described by stiffness (how hard it pulls toward the target)
/// and a damping ratio (1.0 = settles with no overshoot, below 1.0 = a small
/// bounce). Unlike a duration-based tween, a spring keeps its velocity when
/// the target changes mid-flight, so interrupted animations never "jump".
///
/// ```dart
/// controller.animateWith(SpringSimulation(Springs.snappy, from, to, 0));
/// ```
abstract final class Springs {
  /// Entrances and layout changes: calm, no visible overshoot.
  static final gentle = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 140,
    ratio: 0.92,
  );

  /// Hover and press feedback: fast and tight.
  static final snappy = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 520,
    ratio: 0.82,
  );

  /// Releases (e.g. a magnetic button letting go): a small, playful wobble.
  static final playful = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 260,
    ratio: 0.5,
  );

  /// Pointer followers: critically damped, so they never overshoot.
  static final follow = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 700,
  );
}

/// Turns a spring into a [Curve], for APIs that want a curve and a duration
/// (AnimatedContainer, AnimatedSwitcher, Interval, ...).
///
/// The matching duration is [duration] (the spring's settle time).
///
/// Important: an underdamped spring overshoots, so this curve can return
/// values slightly above 1.0. Never feed its *output* into another [Curve]
/// (for example a CurvedAnimation used as the parent of an Interval): every
/// Curve asserts that its input is within 0..1, and the overshoot will trip
/// that assert in debug builds. Use it as the last curve in a chain.
///
/// ```dart
/// final curve = SpringCurve(Springs.gentle);
/// AnimatedContainer(duration: curve.duration, curve: curve, ...);
/// ```
class SpringCurve extends Curve {
  SpringCurve(SpringDescription spring)
    : _simulation = SpringSimulation(spring, 0, 1, 0),
      _settleSeconds = _settleTime(spring);

  final SpringSimulation _simulation;
  final double _settleSeconds;

  /// How long the spring takes to settle; use it as the animation duration.
  Duration get duration =>
      Duration(microseconds: (_settleSeconds * 1e6).round());

  static double _settleTime(SpringDescription spring) {
    final sim = SpringSimulation(
      spring,
      0,
      1,
      0,
      tolerance: const Tolerance(velocity: 0.01),
    );
    var t = 0.0;
    while (!sim.isDone(t) && t < 4) {
      t += 1 / 120;
    }
    return t;
  }

  @override
  double transformInternal(double t) => _simulation.x(t * _settleSeconds);
}

/// `context.reduceMotion`: true when the user asked the OS for less motion.
///
/// Every widget in this folder checks it and falls back to a calm, static
/// version. On the web, wrap the app in `ReducedMotionScope` so the
/// browser's `prefers-reduced-motion` setting is honoured too.
extension MotionX on BuildContext {
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);
}
