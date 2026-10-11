import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A 2D value (an [Offset]) pulled toward a target by a spring.
///
/// Use it for anything that chases a moving target, like a magnetic button,
/// a tilt angle or a cursor follower. Those retarget on every pointer move,
/// which is where springs beat tweens: the current velocity carries over,
/// so the motion stays smooth however often the target changes.
///
/// The ticker only runs while the value is moving, so an idle widget costs
/// no frames. Listen to it (it is a [ChangeNotifier]) with an
/// [AnimatedBuilder] or a CustomPainter's `repaint`.
///
/// ```dart
/// late final _offset = SpringOffset(vsync: this, spring: Springs.snappy);
/// ...
/// _offset.animateTo(pointerDelta);
/// AnimatedBuilder(
///   animation: _offset,
///   builder: (_, child) => Transform.translate(offset: _offset.value, child: child),
///   child: child,
/// );
/// ```
class SpringOffset extends ChangeNotifier {
  SpringOffset({
    required TickerProvider vsync,
    required SpringDescription spring,
    Offset initial = Offset.zero,
    // Not an initializing formal on purpose: `this._spring` as a named
    // parameter needs a very recent Dart (private named parameters), and
    // these files are copied into apps with older SDK constraints.
    // ignore: prefer_initializing_formals
  }) : _spring = spring,
       _value = initial,
       _target = initial {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;
  SpringDescription _spring;
  Offset _value;
  Offset _target;
  Offset _velocity = Offset.zero;
  Duration? _last;

  /// Current position.
  Offset get value => _value;

  /// Where the spring is heading.
  Offset get target => _target;

  /// True while the spring is still moving (the ticker is running).
  bool get isMoving => _ticker.isActive;

  /// Changes the spring used for future motion.
  set spring(SpringDescription spring) => _spring = spring;

  /// Starts (or retargets) the motion, keeping the current velocity.
  void animateTo(Offset target, {SpringDescription? spring}) {
    if (spring != null) _spring = spring;
    _target = target;
    if (!_ticker.isActive) {
      _last = null;
      _ticker.start();
    }
  }

  /// Moves instantly, with no animation.
  void jumpTo(Offset value) {
    _value = value;
    _target = value;
    _velocity = Offset.zero;
    if (_ticker.isActive) _ticker.stop();
    notifyListeners();
  }

  void _tick(Duration elapsed) {
    final last = _last ?? elapsed;
    _last = elapsed;
    // Clamp dt so a dropped frame (or a backgrounded tab) can't explode the
    // integration, then integrate in small sub-steps for stability.
    var dt = (elapsed - last).inMicroseconds / 1e6;
    if (dt <= 0) dt = 1 / 60;
    if (dt > 1 / 20) dt = 1 / 20;

    const step = 1 / 240;
    final k = _spring.stiffness;
    final c = _spring.damping;
    final m = _spring.mass;
    var remaining = dt;
    while (remaining > 0) {
      final h = remaining < step ? remaining : step;
      final accel = ((_target - _value) * k - _velocity * c) / m;
      _velocity += accel * h;
      _value += _velocity * h;
      remaining -= h;
    }

    if ((_target - _value).distance < 0.01 && _velocity.distance < 0.05) {
      _value = _target;
      _velocity = Offset.zero;
      _ticker.stop();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
