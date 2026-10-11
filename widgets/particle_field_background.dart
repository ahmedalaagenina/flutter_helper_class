import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_theme.dart';

/// Lightweight connected-particle background for the hero.
///
/// Perf notes: fixed particle count, single CustomPaint behind a
/// RepaintBoundary, and the ticker stops whenever [active] is false
/// (i.e. the hero is scrolled out of view) or animations are disabled.
class ParticleField extends StatefulWidget {
  final bool active;

  const ParticleField({super.key, this.active = true});

  @override
  State<ParticleField> createState() => _ParticleFieldState();
}

class _Particle {
  double x, y, vx, vy, radius;
  _Particle(this.x, this.y, this.vx, this.vy, this.radius);
}

class _ParticleFieldState extends State<ParticleField>
    with SingleTickerProviderStateMixin {
  static const int _count = 42;
  static const double _linkDistance = 140;

  late final Ticker _ticker;
  final List<_Particle> _particles = [];
  final Random _random = Random(7);
  Duration _last = Duration.zero;
  Offset? _pointer;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _count; i++) {
      _particles.add(
        _Particle(
          _random.nextDouble(),
          _random.nextDouble(),
          (_random.nextDouble() - .5) * .02,
          (_random.nextDouble() - .5) * .02,
          _random.nextDouble() * 1.6 + .8,
        ),
      );
    }
    _ticker = createTicker(_onTick);
    if (widget.active) _ticker.start();
  }

  @override
  void didUpdateWidget(ParticleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!widget.active && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.016
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;

    for (final p in _particles) {
      p.x += p.vx * dt * 3;
      p.y += p.vy * dt * 3;
      if (p.x < 0 || p.x > 1) p.vx = -p.vx;
      if (p.y < 0 || p.y > 1) p.vy = -p.vy;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.expand();
    }
    final t = context.tokens;
    return MouseRegion(
      opaque: false,
      hitTestBehavior: HitTestBehavior.translucent,
      onHover: (e) => _pointer = e.localPosition,
      onExit: (_) => _pointer = null,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ParticlePainter(
            particles: _particles,
            pointer: _pointer,
            color: t.accentA,
            linkColor: t.accentB,
            linkDistance: _linkDistance,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Offset? pointer;
  final Color color;
  final Color linkColor;
  final double linkDistance;

  _ParticlePainter({
    required this.particles,
    required this.pointer,
    required this.color,
    required this.linkColor,
    required this.linkDistance,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = color.withValues(alpha: .45);
    final linkPaint = Paint()..strokeWidth = 1;

    final points = [
      for (final p in particles) Offset(p.x * size.width, p.y * size.height),
    ];

    for (var i = 0; i < points.length; i++) {
      for (var j = i + 1; j < points.length; j++) {
        final d = (points[i] - points[j]).distance;
        if (d < linkDistance) {
          linkPaint.color =
              linkColor.withValues(alpha: (1 - d / linkDistance) * .13);
          canvas.drawLine(points[i], points[j], linkPaint);
        }
      }
      // Link particles to the cursor for a subtle interactive touch.
      if (pointer != null) {
        final d = (points[i] - pointer!).distance;
        if (d < linkDistance * 1.4) {
          linkPaint.color =
              color.withValues(alpha: (1 - d / (linkDistance * 1.4)) * .25);
          canvas.drawLine(points[i], pointer!, linkPaint);
        }
      }
      canvas.drawCircle(points[i], particles[i].radius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}
