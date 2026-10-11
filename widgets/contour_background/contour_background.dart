// ContourBackground: an animated topographic-map background drawn by a GLSL
// fragment shader. Standalone: needs only the Flutter SDK.
//
// SETUP (once per app)
//   1. Copy `contour.frag` (next to this file) into your app, for example to
//      `shaders/contour.frag` beside pubspec.yaml.
//   2. Declare it in pubspec.yaml, inside the `flutter:` section:
//
//        flutter:
//          shaders:
//            - shaders/contour.frag
//
//   3. Stop the app and run it again. Shaders are compiled at build time, so
//      a hot reload won't pick up a newly declared one.
//
// If you put the shader somewhere else, pass that path as `shaderAsset`.
// When the shader can't be loaded, the widget paints a plain
// `backgroundColor` instead, and prints a hint in debug builds.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// An animated topographic map: faint contour lines drift slowly across the
/// area, and bunch up and glow around the pointer as if a hill rose under it.
/// With no pointer (on touch screens, or after the mouse leaves) a gentle
/// hill wanders on its own, so the background never looks frozen.
///
/// ```dart
/// ContourBackground(
///   active: isHeroVisible, // pause while scrolled off screen
///   fadeBottom: 0.28, // melt into the page below
///   child: const HeroContent(),
/// )
/// ```
///
/// * Setup: `contour.frag` must be declared under `flutter: shaders:` in
///   pubspec.yaml (steps at the top of this file). Until it loads, or if it
///   can't, the area is filled with [backgroundColor].
/// * Performance: one shader whose uniforms change each frame, in its own
///   [RepaintBoundary], so neither [child] nor the rest of the screen is
///   repainted by the animation. The ticker runs only while [active] is
///   true, motion is allowed and something is actually changing.
/// * Reduced motion: when the OS asks for less motion, one still frame is
///   painted and the pointer is ignored.
/// * Accessibility: purely decorative. It adds no semantics and keeps
///   [child]'s. The pointer is only observed, never claimed, so taps and
///   scrolls on [child] work as usual.
class ContourBackground extends StatefulWidget {
  /// Creates an animated contour background. Colours left null come from
  /// the ambient [Theme]'s colour scheme, so light and dark mode both work.
  const ContourBackground({
    super.key,
    this.child,
    this.backgroundColor,
    this.lineColor,
    this.glowColor,
    this.lineOpacity = 0.12,
    this.levels = 9,
    this.speed = 1,
    this.active = true,
    this.interactive = true,
    this.fadeTop = 0,
    this.fadeBottom = 0,
    this.shaderAsset = 'shaders/contour.frag',
  }) : assert(
         lineOpacity >= 0 && lineOpacity <= 1,
         'lineOpacity must be between 0 and 1.',
       ),
       assert(levels > 0, 'levels must be greater than 0.'),
       assert(speed >= 0, 'speed must not be negative.'),
       assert(fadeTop >= 0 && fadeTop <= 1, 'fadeTop must be between 0 and 1.'),
       assert(
         fadeBottom >= 0 && fadeBottom <= 1,
         'fadeBottom must be between 0 and 1.',
       );

  /// Content painted on top of the field. The widget takes the child's
  /// size; without one it fills the available space (so it needs bounded
  /// constraints, e.g. inside `Positioned.fill`).
  ///
  /// Prefer this over stacking content above the widget yourself: the
  /// pointer is then tracked over the content too.
  final Widget? child;

  /// Fills the area behind the lines. Defaults to `colorScheme.surface`.
  /// May be translucent, to let whatever is behind show through.
  final Color? backgroundColor;

  /// Contour line colour. Defaults to `colorScheme.onSurfaceVariant`.
  /// Its alpha multiplies [lineOpacity].
  final Color? lineColor;

  /// Colour the lines take on near the pointer, plus a faint glow there.
  /// Defaults to `colorScheme.primary`. Its alpha scales the glow.
  final Color? glowColor;

  /// Base opacity of the contour lines, 0 to 1. Every fifth line is drawn
  /// about twice as strong, and lines near the pointer stronger still, so
  /// keep this low: the widget sits behind content.
  final double lineOpacity;

  /// Contour density: lines per unit of terrain height. Higher values pack
  /// the lines closer together.
  final double levels;

  /// Drift speed multiplier. 1 is a slow, calm drift; 0 freezes the terrain
  /// while the hill still follows the pointer.
  final double speed;

  /// Whether the animation runs. Set it to false while the widget is off
  /// screen (scrolled away, behind another page) so it costs nothing.
  final bool active;

  /// Whether the field reacts to a mouse, finger or stylus over this
  /// widget's area.
  final bool interactive;

  /// Fraction of the height (0 to 1) over which the lines fade in from the
  /// top edge. 0 means no fade.
  final double fadeTop;

  /// Fraction of the height (0 to 1) over which the lines fade out toward
  /// the bottom edge, e.g. so a hero section melts into the page below.
  /// 0 means no fade.
  final double fadeBottom;

  /// Asset key of the shader, exactly as declared in pubspec.yaml.
  final String shaderAsset;

  @override
  State<ContourBackground> createState() => _ContourBackgroundState();
}

class _ContourBackgroundState extends State<ContourBackground>
    with SingleTickerProviderStateMixin {
  /// Programs that finished loading, shared by every instance, so a second
  /// instance gets its shader synchronously instead of flashing the
  /// fallback colour for a frame.
  static final Map<String, ui.FragmentProgram> _programs = {};

  /// One load per asset key, shared by instances that start together. A
  /// failed load resolves to null and is not retried (assets don't change
  /// while the app runs).
  static final Map<String, Future<ui.FragmentProgram?>> _loads = {};

  /// Every time frequency in the shader is a multiple of 0.01 rad/s, so the
  /// field repeats exactly every 200π seconds. Wrapping uTime there keeps
  /// GPU float precision without a visible jump.
  static const double _timePeriod = 200 * math.pi;

  /// Seconds without a pointer before the hill starts to wander.
  static const double _idleDelay = 2;

  /// Hill strength with no pointer; a live pointer gets the full 1.0.
  static const double _idlePresence = 0.55;

  /// The hill's spring (mass 1, stiffness 140, damping ratio 0.92). It
  /// trails the pointer slightly, which reads as weight rather than lag.
  static const double _stiffness = 140;
  static const double _damping = 21.77; // 2 * 0.92 * sqrt(140)

  /// Longest frame step simulated. A dropped frame or a paused tab counts
  /// as this much, so nothing jumps when ticking resumes.
  static const double _maxStep = 1 / 20;

  late final Ticker _ticker;
  final _ContourFrame _frame = _ContourFrame();
  ui.FragmentShader? _shader;
  bool _reduceMotion = false;

  Duration? _lastElapsed;

  /// Drift time in seconds, scaled by speed. Never wrapped here: the CPU
  /// side has double precision, only the uniform is wrapped.
  double _clock = 0;

  /// Live pointer position in local pixels, or null when there is none.
  Offset? _pointer;

  /// Seconds since the pointer was last present. Starts "idle", so the hill
  /// wanders from the first frame.
  double _sincePointer = _idleDelay;

  Offset _hillTarget = Offset.zero;
  Offset _hill = Offset.zero;
  Offset _hillVelocity = Offset.zero;
  bool _hillPlaced = false;
  double _presence = 0;

  /// True when a speed-0 field has settled: the ticker is stopped until
  /// something changes again.
  bool _resting = false;

  @override
  void initState() {
    super.initState();
    // Created here rather than lazily, so dispose never creates a ticker.
    _ticker = createTicker(_onTick);
    _loadShader();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduceMotion) _pointer = null;
    _syncTicker();
  }

  @override
  void didUpdateWidget(ContourBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shaderAsset != widget.shaderAsset) _loadShader();
    if (!widget.interactive) _clearPointer();
    if (oldWidget.speed != widget.speed) _wake();
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _shader?.dispose();
    super.dispose();
  }

  /// Starts using the shader for [ContourBackground.shaderAsset]: right away
  /// when it's already loaded, otherwise once loading completes. The current
  /// shader (if any) stays in use until then.
  void _loadShader() {
    final asset = widget.shaderAsset;
    final loaded = _programs[asset];
    if (loaded != null) {
      _setShader(loaded.fragmentShader());
      return;
    }
    final load = _loads[asset] ??= _loadProgram(asset);
    unawaited(
      load.then((program) {
        // The widget may be gone, or pointed at another asset, by now.
        if (!mounted || asset != widget.shaderAsset) return;
        setState(() => _setShader(program?.fragmentShader()));
        _syncTicker();
      }),
    );
  }

  static Future<ui.FragmentProgram?> _loadProgram(String asset) async {
    try {
      final program = await ui.FragmentProgram.fromAsset(asset);
      _programs[asset] = program;
      return program;
    } catch (error) {
      // Usually the shader isn't declared under `flutter: shaders:` in
      // pubspec.yaml, or the app wasn't restarted after declaring it.
      if (kDebugMode) {
        debugPrint(
          'ContourBackground: could not load the shader "$asset" ($error). '
          'Painting a plain background instead.',
        );
      }
      return null;
    }
  }

  void _setShader(ui.FragmentShader? shader) {
    _shader?.dispose();
    _shader = shader;
  }

  void _syncTicker() {
    final shouldRun =
        widget.active && !_reduceMotion && _shader != null && !_resting;
    if (shouldRun && !_ticker.isActive) {
      _lastElapsed = null; // elapsed restarts from zero on every start
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
  }

  /// Restarts a rested (speed 0, settled) field after something changed.
  void _wake() {
    if (!_resting) return;
    _resting = false;
    _syncTicker();
  }

  void _onPointer(PointerEvent event) {
    _pointer = event.localPosition;
    _wake();
  }

  void _onPointerEnd(PointerEvent event) {
    // A lifted finger or stylus is gone; a mouse is still hovering.
    if (event.kind != PointerDeviceKind.mouse) _clearPointer();
  }

  void _clearPointer() {
    if (_pointer == null) return;
    _pointer = null;
    _wake();
  }

  void _onTick(Duration elapsed) {
    final last = _lastElapsed ?? elapsed;
    _lastElapsed = elapsed;
    final dt = math.min((elapsed - last).inMicroseconds / 1e6, _maxStep);

    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return;

    _clock += dt * widget.speed;
    final pointer = _pointer;
    _sincePointer = pointer == null ? _sincePointer + dt : 0;
    final idle = pointer == null && _sincePointer >= _idleDelay;
    if (pointer != null) {
      _hillTarget = pointer;
    } else if (idle) {
      _hillTarget = _wanderPoint(box.size);
    }
    // Otherwise the hill waits where the pointer left, until the idle delay.

    if (!_hillPlaced) {
      // Start on target instead of gliding in from a corner.
      _hill = _hillTarget;
      _hillPlaced = true;
    }
    _stepSpring(dt);

    final presenceTarget = pointer == null ? _idlePresence : 1.0;
    _presence += (presenceTarget - _presence) * (1 - math.exp(-dt * 3));

    // With no drift, the field stops changing once the hill settles: stop
    // ticking until the pointer (or a new speed) wakes it.
    if (widget.speed == 0 &&
        (pointer != null || idle) &&
        (_hillTarget - _hill).distance < 0.1 &&
        _hillVelocity.distance < 0.1 &&
        (presenceTarget - _presence).abs() < 0.002) {
      _hill = _hillTarget;
      _hillVelocity = Offset.zero;
      _presence = presenceTarget;
      _resting = true;
      _ticker.stop();
    }

    _frame.update(_clock % _timePeriod, _hill, _presence);
  }

  /// Advances the hill's spring by [dt] seconds in small fixed sub-steps,
  /// which keeps the integration stable at any frame rate.
  void _stepSpring(double dt) {
    const step = 1 / 240;
    var remaining = dt;
    while (remaining > 0) {
      final h = math.min(remaining, step);
      final acceleration =
          (_hillTarget - _hill) * _stiffness - _hillVelocity * _damping;
      _hillVelocity += acceleration * h;
      _hill += _hillVelocity * h;
      remaining -= h;
    }
  }

  /// Where the idle hill heads: a slow Lissajous loop around the centre.
  /// It uses the unwrapped clock, so it never jumps when uTime wraps.
  Offset _wanderPoint(Size size) {
    final s = _clock * 0.18;
    return Offset(
      size.width * (0.5 + 0.3 * math.sin(s * 1.3)),
      size.height * (0.5 + 0.22 * math.sin(s * 0.9 + 1.1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final follow = widget.interactive && !_reduceMotion;
    // The tree keeps the same shape whatever the flags or the shader state
    // are (only callbacks and the painter change), so [child] never loses
    // its state when the shader loads or a setting flips.
    return Listener(
      onPointerDown: follow ? _onPointer : null,
      onPointerMove: follow ? _onPointer : null,
      onPointerHover: follow ? _onPointer : null,
      onPointerUp: follow ? _onPointerEnd : null,
      onPointerCancel: follow ? _onPointerEnd : null,
      child: MouseRegion(
        opaque: false,
        onExit: follow ? (_) => _clearPointer() : null,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _ContourPainter(
              frame: _frame,
              shader: _shader,
              background: widget.backgroundColor ?? colors.surface,
              line: widget.lineColor ?? colors.onSurfaceVariant,
              glow: widget.glowColor ?? colors.primary,
              lineOpacity: widget.lineOpacity,
              levels: widget.levels,
              fadeTop: widget.fadeTop,
              fadeBottom: widget.fadeBottom,
            ),
            // Its own layer, so repainting the field every frame never
            // re-records the content on top.
            child: widget.child == null
                ? const SizedBox.expand()
                : RepaintBoundary(child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// The per-frame values the shader needs. The ticker writes them and the
/// painter repaints from them, without rebuilding any widget.
class _ContourFrame extends ChangeNotifier {
  double _time = 0;
  Offset _hill = Offset.zero;
  double _presence = 0;

  double get time => _time;
  Offset get hill => _hill;
  double get presence => _presence;

  void update(double time, Offset hill, double presence) {
    _time = time;
    _hill = hill;
    _presence = presence;
    notifyListeners();
  }
}

/// Paints the field with the shader once it's ready, otherwise a flat fill.
class _ContourPainter extends CustomPainter {
  _ContourPainter({
    required this.frame,
    required this.shader,
    required this.background,
    required this.line,
    required this.glow,
    required this.lineOpacity,
    required this.levels,
    required this.fadeTop,
    required this.fadeBottom,
  }) : super(repaint: frame);

  final _ContourFrame frame;
  final ui.FragmentShader? shader;
  final Color background;
  final Color line;
  final Color glow;
  final double lineOpacity;
  final double levels;
  final double fadeTop;
  final double fadeBottom;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final shader = this.shader;
    if (shader == null) {
      canvas.drawRect(rect, Paint()..color = background);
      return;
    }

    // Indices follow the uniform order in contour.frag.
    var i = 0;
    void put(double value) => shader.setFloat(i++, value);
    void putColor(Color color) {
      put(color.r);
      put(color.g);
      put(color.b);
      put(color.a);
    }

    put(size.width);
    put(size.height);
    put(frame.time);
    put(frame.hill.dx);
    put(frame.hill.dy);
    put(frame.presence);
    putColor(background);
    putColor(line);
    putColor(glow);
    put(lineOpacity);
    put(levels);
    put(fadeTop);
    put(fadeBottom);
    canvas.drawRect(rect, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ContourPainter oldDelegate) =>
      oldDelegate.shader != shader ||
      oldDelegate.background != background ||
      oldDelegate.line != line ||
      oldDelegate.glow != glow ||
      oldDelegate.lineOpacity != lineOpacity ||
      oldDelegate.levels != levels ||
      oldDelegate.fadeTop != fadeTop ||
      oldDelegate.fadeBottom != fadeBottom;
}
