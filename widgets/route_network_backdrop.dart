import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A faint road network with a vehicle tracing one of the routes.
///
/// ## Why a route network rather than particles
///
/// A connected-particle field reads as "generic tech". This says what the
/// product actually does: roads, stops along them, and something moving. The
/// tracer is the whole point — a static map is a picture, a moving dot is
/// tracking.
///
/// ## Restraint is the design
///
/// This sits behind a login form, so legibility wins over decoration: the
/// roads are drawn at a fraction of the surface contrast and the tracer takes
/// several seconds per lap. It should register as texture, not motion you have
/// to look away from.
///
/// Performance, following the same rules as `ParticleField`:
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
  });

  /// Road lines. Use a low-contrast neutral — this must sit behind content.
  final Color color;

  /// Stops and the moving tracer. Defaults to [color].
  final Color? accentColor;

  /// Set false when the backdrop is off-screen to stop the ticker.
  final bool active;

  /// Overall strength, on top of the already-low per-element alphas.
  final double opacity;

  @override
  State<RouteNetworkBackdrop> createState() => _RouteNetworkBackdropState();
}

class _RouteNetworkBackdropState extends State<RouteNetworkBackdrop>
    with SingleTickerProviderStateMixin {
  /// One full traverse of the traced route.
  static const Duration _lapDuration = Duration(seconds: 9);

  late final Ticker _ticker = createTicker(_onTick);

  /// 0→1 progress of the tracer along its route.
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  Duration _elapsed = Duration.zero;

  /// Built once per size — recomputing curves every frame would dominate the
  /// cost of this widget.
  _RouteGeometry? _geometry;
  Size _lastSize = Size.zero;

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
    _elapsed = elapsed;
    final t =
        (_elapsed.inMilliseconds % _lapDuration.inMilliseconds) /
        _lapDuration.inMilliseconds;
    // ValueNotifier rather than setState: only the painter needs to rebuild.
    _progress.value = t;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (size != _lastSize || _geometry == null) {
            _lastSize = size;
            _geometry = _RouteGeometry.build(size);
          }

          return CustomPaint(
            size: size,
            painter: _RouteNetworkPainter(
              geometry: _geometry!,
              progress: _progress,
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

/// The road paths and stop positions for one canvas size.
class _RouteGeometry {
  _RouteGeometry({
    required this.roads,
    required this.tracedRoute,
    required this.tracedMetric,
    required this.stops,
  });

  final List<Path> roads;
  final Path tracedRoute;
  final PathMetric tracedMetric;
  final List<Offset> stops;

  /// Seeded so the layout is identical on every launch — a login screen that
  /// reshuffles its background each time reads as noise, not as a place.
  static _RouteGeometry build(Size size) {
    final random = math.Random(11);
    final roads = <Path>[];

    // Long arterials sweeping across the canvas at shallow angles.
    for (var i = 0; i < 5; i++) {
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
      roads.add(path);
    }

    // Cross streets, to read as a network rather than parallel lines.
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
      roads.add(path);
    }

    // The tracer follows a middle arterial, so it stays in view rather than
    // running along an edge.
    final traced = roads[2];
    final metrics = traced.computeMetrics().toList();
    final tracedMetric = metrics.isNotEmpty
        ? metrics.first
        : (Path()
                ..moveTo(0, size.height / 2)
                ..lineTo(size.width, size.height / 2))
              .computeMetrics()
              .first;

    // A few stops along the traced route — destinations on the journey.
    final stops = <Offset>[];
    for (final fraction in const [0.18, 0.46, 0.78]) {
      final tangent = tracedMetric.getTangentForOffset(
        tracedMetric.length * fraction,
      );
      if (tangent != null) stops.add(tangent.position);
    }

    return _RouteGeometry(
      roads: roads,
      tracedRoute: traced,
      tracedMetric: tracedMetric,
      stops: stops,
    );
  }
}

class _RouteNetworkPainter extends CustomPainter {
  _RouteNetworkPainter({
    required this.geometry,
    required this.progress,
    required this.color,
    required this.accentColor,
    required this.opacity,
  }) : super(repaint: progress);

  final _RouteGeometry geometry;
  final ValueListenable<double> progress;
  final Color color;
  final Color accentColor;
  final double opacity;

  /// Length of the bright trail behind the vehicle, as a fraction of the route.
  static const double _trailFraction = 0.13;

  @override
  void paint(Canvas canvas, Size size) {
    _paintRoads(canvas);
    _paintStops(canvas);
    _paintTracer(canvas);
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

    // The traced route reads slightly stronger, so the eye follows it.
    canvas.drawPath(
      geometry.tracedRoute,
      paint
        ..color = color.withValues(alpha: 0.26 * opacity)
        ..strokeWidth = 1.8,
    );
  }

  void _paintStops(Canvas canvas) {
    for (final stop in geometry.stops) {
      canvas.drawCircle(
        stop,
        3,
        Paint()..color = accentColor.withValues(alpha: 0.30 * opacity),
      );
      canvas.drawCircle(
        stop,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = accentColor.withValues(alpha: 0.18 * opacity),
      );
    }
  }

  void _paintTracer(Canvas canvas) {
    final metric = geometry.tracedMetric;
    final total = metric.length;
    if (total <= 0) return;

    final head = total * progress.value;
    final tail = math.max(0.0, head - total * _trailFraction);

    // The travelled trail, brighter than the road beneath it.
    final trail = metric.extractPath(tail, head);
    canvas.drawPath(
      trail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4
        ..color = accentColor.withValues(alpha: 0.55 * opacity),
    );

    final tangent = metric.getTangentForOffset(head);
    if (tangent == null) return;

    // The vehicle: a soft halo with a solid core, so it reads as a live
    // position rather than a dot sitting on a line.
    canvas.drawCircle(
      tangent.position,
      9,
      Paint()..color = accentColor.withValues(alpha: 0.16 * opacity),
    );
    canvas.drawCircle(
      tangent.position,
      3.6,
      Paint()..color = accentColor.withValues(alpha: 0.95 * opacity),
    );
  }

  @override
  bool shouldRepaint(_RouteNetworkPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.color != color ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.opacity != opacity;
}
