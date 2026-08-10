import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Slowly drifts [child] around its box, bouncing off the edges.
///
/// Used for the anti-piracy watermark that floats over the video players, so
/// how it animates matters a lot: it sits directly on top of a platform view
/// (the YouTube WebView, ExoPlayer's surface), and anything that dirties the
/// layout on every frame forces that surface to be re-composited — which shows
/// up to the student as stutter and dropped frames during playback.
///
/// So the animation is deliberately paint-only:
///
/// * position is pushed through a [ValueNotifier] instead of `setState`, so
///   only the [Transform] rebuilds — never the subtree or its ancestors;
/// * movement uses [Transform.translate], which is a paint-time offset and
///   triggers no layout pass;
/// * the whole thing sits behind a [RepaintBoundary];
/// * the ticker comes from [SingleTickerProviderStateMixin.createTicker], so it
///   is muted automatically when the player's route is covered instead of
///   burning frames in the background.
///
/// Speed is expressed in logical pixels per frame-at-60fps and converted to a
/// per-second velocity, so the drift looks the same on 60 Hz and 120 Hz panels.
class BouncingAnimationWidget extends StatefulWidget {
  const BouncingAnimationWidget({
    super.key,
    required this.child,
    this.screenHeight,
    this.screenWidth,
    this.speed = 1.0,
    this.changeAuto = false,
    this.changeDirectionInterval = const Duration(minutes: 3),
  });

  final Widget child;
  final double? screenHeight;
  final double? screenWidth;
  final double speed;
  final bool changeAuto;
  final Duration changeDirectionInterval;

  @override
  State<BouncingAnimationWidget> createState() =>
      _BouncingAnimationWidgetState();
}

class _BouncingAnimationWidgetState extends State<BouncingAnimationWidget>
    with SingleTickerProviderStateMixin {
  /// Offset from the centre of the box. Zero means centred, which is why the
  /// child is wrapped in an [Align] — no measurement is needed to place it on
  /// the very first frame.
  final ValueNotifier<Offset> _offset = ValueNotifier(Offset.zero);

  final GlobalKey _childKey = GlobalKey();
  final Random _random = Random();

  late final Ticker _ticker;
  Timer? _directionTimer;

  Duration _lastElapsed = Duration.zero;
  double _dirX = 0, _dirY = 0;
  Size _bounds = Size.zero;
  Size _childSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _changeDirection();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
    if (widget.changeAuto) {
      _directionTimer = Timer.periodic(
        widget.changeDirectionInterval,
        (_) => _changeDirection(),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateBounds();
  }

  @override
  void didUpdateWidget(BouncingAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screenWidth != widget.screenWidth ||
        oldWidget.screenHeight != widget.screenHeight) {
      _updateBounds();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _directionTimer?.cancel();
    _offset.dispose();
    super.dispose();
  }

  void _updateBounds() {
    final size = MediaQuery.maybeSizeOf(context) ?? Size.zero;
    _bounds = Size(
      widget.screenWidth ?? size.width,
      widget.screenHeight ?? size.height,
    );
    // The box may have shrunk (split-view divider drag, rotation) — pull the
    // watermark back inside instead of leaving it stranded off-screen.
    _offset.value = _clamp(_offset.value);
  }

  void _measureAndStart() {
    if (!mounted) return;
    final box = _childKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) _childSize = box.size;
    if (!_ticker.isActive) _ticker.start();
  }

  void _changeDirection() {
    final angle = _random.nextDouble() * 2 * pi;
    _dirX = cos(angle);
    _dirY = sin(angle);
  }

  /// Half-extent the child may travel from the centre, per axis.
  Offset get _limit => Offset(
        max(0, (_bounds.width - _childSize.width) / 2),
        max(0, (_bounds.height - _childSize.height) / 2),
      );

  Offset _clamp(Offset value) {
    final limit = _limit;
    return Offset(
      value.dx.clamp(-limit.dx, limit.dx),
      value.dy.clamp(-limit.dy, limit.dy),
    );
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;

    // Skip the first tick (no previous timestamp) and any long stall — after
    // the app returns from the background a huge delta would teleport the
    // watermark across the video.
    if (dt <= 0 || dt > 0.25) return;

    // The child may not have been laid out when the ticker started.
    if (_childSize.isEmpty) {
      final box = _childKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) _childSize = box.size;
    }

    final limit = _limit;
    if (limit.dx <= 0 && limit.dy <= 0) return;

    final velocity = widget.speed * 60.0; // px/frame@60fps -> px/second
    var x = _offset.value.dx + _dirX * velocity * dt;
    var y = _offset.value.dy + _dirY * velocity * dt;

    if (x <= -limit.dx) {
      x = -limit.dx;
      _dirX = _dirX.abs();
    } else if (x >= limit.dx) {
      x = limit.dx;
      _dirX = -_dirX.abs();
    }

    if (y <= -limit.dy) {
      y = -limit.dy;
      _dirY = _dirY.abs();
    } else if (y >= limit.dy) {
      y = limit.dy;
      _dirY = -_dirY.abs();
    }

    _offset.value = Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Align(
        alignment: Alignment.center,
        child: ValueListenableBuilder<Offset>(
          valueListenable: _offset,
          // `child` is built once and handed to every frame, so only the
          // Transform is rebuilt as the watermark drifts.
          child: KeyedSubtree(key: _childKey, child: widget.child),
          builder: (context, offset, child) {
            return Transform.translate(offset: offset, child: child);
          },
        ),
      ),
    );
  }
}
