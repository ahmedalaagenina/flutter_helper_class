import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A faint road network with vehicles tracing some of the routes.
///
/// ## Why a route network rather than particles
///
/// A connected-particle field reads as "generic tech". This says what the
/// product actually does: roads, stops along them, and things moving. The
/// tracers are the whole point — a static map is a picture, a moving dot is
/// tracking.
///
/// ## Restraint is the design
///
/// This sits behind a login form, so legibility wins over decoration: roads
/// are drawn at a fraction of the surface contrast and a lap takes several
/// seconds. It should register as texture, not motion you have to look away
/// from.
///
/// Performance:
/// - geometry is built once per size, not per frame
/// - a single [CustomPaint] behind a [RepaintBoundary]
/// - the ticker stops when [active] is false or the platform asks for reduced
///   motion, in which case the routes still draw but nothing moves
class RouteNetworkBackdrop extends StatefulWidget {
  const RouteNetworkBackdrop({
    super.key,
    required this.color,
    this.accentColor,
    this.active = true,
    this.opacity = 1,
    this.tracerCount = 3,
  });

  /// Road lines. Use a low-contrast neutral — this must sit behind content.
  final Color color;

  /// Stops and the moving tracers. Defaults to [color].
  final Color? accentColor;

  /// Set false when the backdrop is off-screen to stop the ticker.
  final bool active;

  /// Overall strength, on top of the already-low per-element alphas.
  final double opacity;

  /// How many vehicles travel the network.
  ///
  /// Clamped to the number of arterial routes available. Each gets its own
  /// route, starting phase and speed, so they never move in lockstep — which
  /// would read as an animation rather than as traffic.
  final int tracerCount;

  @override
  State<RouteNetworkBackdrop> createState() => _RouteNetworkBackdropState();
}

class _RouteNetworkBackdropState extends State<RouteNetworkBackdrop>
    with SingleTickerProviderStateMixin {
  /// One full traverse at speed 1.0.
  static const Duration _lapDuration = Duration(seconds: 9);

  late final Ticker _ticker = createTicker(_onTick);

  /// 0→1 master clock. Each tracer derives its own position from this.
  final ValueNotifier<double> _clock = ValueNotifier<double>(0);

  /// Built once per size — recomputing curves and path metrics every frame
  /// would dominate the cost of this widget.
  _RouteGeometry? _geometry;
  Size _lastSize = Size.zero;
  int _lastTracerCount = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(RouteNetworkBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) _syncTicker();
  }

  void _syncTicker() {
    // Honour the OS "reduce motion" setting: the roads still render, they just
    // hold still.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final shouldRun = widget.active && !reduceMotion;

    if (shouldRun && !_ticker.isActive) {
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final lapMs = _lapDuration.inMilliseconds;
    // ValueNotifier rather than setState: only the painter needs to repaint.
    _clock.value = (elapsed.inMilliseconds % lapMs) / lapMs;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);

          if (size != _lastSize ||
              widget.tracerCount != _lastTracerCount ||
              _geometry == null) {
            _lastSize = size;
            _lastTracerCount = widget.tracerCount;
            _geometry = _RouteGeometry.build(size, widget.tracerCount);
          }

          return CustomPaint(
            size: size,
            painter: _RouteNetworkPainter(
              geometry: _geometry!,
              clock: _clock,
              color: widget.color,
              accentColor: widget.accentColor ?? widget.color,
              opacity: widget.opacity,
            ),
          );
        },
      ),
    );
  }
}

/// A route with a vehicle on it.
class _TracedRoute {
  const _TracedRoute({
    required this.metric,
    required this.phase,
    required this.speed,
    required this.stops,
  });

  final PathMetric metric;

  /// Starting offset around the lap, so vehicles are spread out rather than
  /// all departing together.
  final double phase;

  /// Lap-rate multiplier. Slight variation stops them staying in formation.
  final double speed;

  final List<Offset> stops;

  /// Where this vehicle is, 0→1 along its route, for a given master clock.
  double headAt(double clock) => (clock * speed + phase) % 1.0;
}

/// The road paths and traced routes for one canvas size.
class _RouteGeometry {
  _RouteGeometry({
    required this.roads,
    required this.tracedPaths,
    required this.traced,
  });

  final List<Path> roads;

  /// Drawn slightly stronger than the rest, so the eye follows them.
  final List<Path> tracedPaths;

  final List<_TracedRoute> traced;

  /// How many of the generated roads are long arterials (the rest are cross
  /// streets, which are too short to carry a vehicle convincingly).
  static const int _arterialCount = 5;

  /// Seeded so the layout is identical on every launch — a login screen that
  /// reshuffles its background each time reads as noise, not as a place.
  static _RouteGeometry build(Size size, int tracerCount) {
    if (size.isEmpty) {
      return _RouteGeometry(
        roads: const [],
        tracedPaths: const [],
        traced: const [],
      );
    }
    // change the number make forms changed
    final random = math.Random(9);
    final arterials = <Path>[];
    final crossStreets = <Path>[];

    // Long arterials sweeping across the canvas at shallow angles.
    for (var i = 0; i < _arterialCount; i++) {
      final startY = size.height * (0.08 + i * 0.2);
      final path = Path()..moveTo(-size.width * 0.1, startY);

      var x = -size.width * 0.1;
      var y = startY;
      while (x < size.width * 1.1) {
        final nextX = x + size.width * (0.28 + random.nextDouble() * 0.2);
        final nextY = y + (random.nextDouble() - 0.5) * size.height * 0.16;
        // Quadratic through a midpoint gives roads a natural bend rather than
        // the polyline look of straight segments.
        path.quadraticBezierTo((x + nextX) / 2, y, nextX, nextY);
        x = nextX;
        y = nextY;
      }
      arterials.add(path);
    }

    // Cross streets, so it reads as a network rather than parallel lines.
    for (var i = 0; i < 4; i++) {
      final startX = size.width * (0.15 + i * 0.24);
      final path = Path()..moveTo(startX, -size.height * 0.05);
      var x = startX;
      var y = -size.height * 0.05;
      while (y < size.height * 1.05) {
        final nextY = y + size.height * (0.3 + random.nextDouble() * 0.2);
        final nextX = x + (random.nextDouble() - 0.5) * size.width * 0.12;
        path.quadraticBezierTo(x, (y + nextY) / 2, nextX, nextY);
        x = nextX;
        y = nextY;
      }
      crossStreets.add(path);
    }

    // Spread the vehicles across the arterials instead of taking the first N,
    // so they are not all clustered at the top of the screen.
    final count = tracerCount.clamp(0, arterials.length);
    final traced = <_TracedRoute>[];
    final tracedPaths = <Path>[];

    for (var i = 0; i < count; i++) {
      final index = count == 1
          ? arterials.length ~/ 2
          : (i * (arterials.length - 1) / (count - 1)).round();

      final path = arterials[index];
      final metrics = path.computeMetrics().toList();
      if (metrics.isEmpty) continue;
      final metric = metrics.first;

      // A few stops along the route — destinations on the journey.
      final stops = <Offset>[];
      for (final fraction in const [0.22, 0.55, 0.84]) {
        final tangent = metric.getTangentForOffset(metric.length * fraction);
        if (tangent != null) stops.add(tangent.position);
      }

      traced.add(
        _TracedRoute(
          metric: metric,
          phase: i / count,
          speed: 0.82 + i * 0.13,
          stops: stops,
        ),
      );
      tracedPaths.add(path);
    }

    return _RouteGeometry(
      roads: [...arterials, ...crossStreets],
      tracedPaths: tracedPaths,
      traced: traced,
    );
  }
}

class _RouteNetworkPainter extends CustomPainter {
  _RouteNetworkPainter({
    required this.geometry,
    required this.clock,
    required this.color,
    required this.accentColor,
    required this.opacity,
  }) : super(repaint: clock);

  final _RouteGeometry geometry;
  final ValueListenable<double> clock;
  final Color color;
  final Color accentColor;
  final double opacity;

  /// Length of the bright trail behind a vehicle, as a fraction of its route.
  static const double _trailFraction = 0.13;

  @override
  void paint(Canvas canvas, Size size) {
    _paintRoads(canvas);
    _paintStops(canvas);
    _paintTracers(canvas);
  }

  void _paintRoads(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.16 * opacity)
      ..strokeWidth = 1.4;

    for (final road in geometry.roads) {
      canvas.drawPath(road, paint);
    }

    paint
      ..color = color.withValues(alpha: 0.26 * opacity)
      ..strokeWidth = 1.8;
    for (final path in geometry.tracedPaths) {
      canvas.drawPath(path, paint);
    }
  }

  void _paintStops(Canvas canvas) {
    final fill = Paint()..color = accentColor.withValues(alpha: 0.30 * opacity);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = accentColor.withValues(alpha: 0.18 * opacity);

    for (final route in geometry.traced) {
      for (final stop in route.stops) {
        canvas.drawCircle(stop, 3, fill);
        canvas.drawCircle(stop, 6, ring);
      }
    }
  }

  void _paintTracers(Canvas canvas) {
    final trailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4
      ..color = accentColor.withValues(alpha: 0.55 * opacity);
    final haloPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.16 * opacity);
    final corePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.95 * opacity);

    for (final route in geometry.traced) {
      final total = route.metric.length;
      if (total <= 0) continue;

      final head = total * route.headAt(clock.value);
      final tail = math.max(0.0, head - total * _trailFraction);

      canvas.drawPath(route.metric.extractPath(tail, head), trailPaint);

      final tangent = route.metric.getTangentForOffset(head);
      if (tangent == null) continue;

      // A soft halo with a solid core, so it reads as a live position rather
      // than a dot sitting on a line.
      canvas.drawCircle(tangent.position, 9, haloPaint);
      canvas.drawCircle(tangent.position, 3.6, corePaint);
    }
  }

  @override
  bool shouldRepaint(_RouteNetworkPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.color != color ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.opacity != opacity;
}
