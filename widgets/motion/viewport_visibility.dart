import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Lets a [State] know how much of its widget is actually on screen.
///
/// A dependency-free replacement for the visibility_detector package, for
/// widgets inside scroll views. Mix it into a State and react in
/// [onVisibleFractionChanged] (0 = hidden, 1 = fully visible), or override
/// [handleViewportGeometry] to get the raw rectangles (e.g. for scroll
/// progress effects).
///
/// ```dart
/// class _MyState extends State<MyWidget> with ViewportVisibilityMixin {
///   @override
///   void onVisibleFractionChanged(double fraction) {
///     if (fraction > 0.5) startVideo(); else pauseVideo();
///   }
/// }
/// ```
///
/// * Listens to every ancestor Scrollable (a card in a horizontal list
///   inside a vertical page stays correct) and to screen-size changes.
/// * Checks are coalesced to at most one per frame, after layout.
/// * Call [stopVisibilityTracking] once you no longer care (e.g. after a
///   one-shot entrance) so scrolling costs nothing for this widget.
/// * Widgets outside any Scrollable count as visible after their first frame.
mixin ViewportVisibilityMixin<T extends StatefulWidget> on State<T> {
  final List<ScrollPosition> _positions = [];
  bool _checkScheduled = false;
  bool _tracking = true;
  double _lastFraction = -1;

  /// Called when the visible fraction (0..1) changes.
  void onVisibleFractionChanged(double fraction) {}

  /// Called after each check with the widget's rectangle and the area of
  /// the screen it can be seen in, both in global logical pixels.
  ///
  /// The default computes the visible fraction and calls
  /// [onVisibleFractionChanged] when it changes.
  void handleViewportGeometry(Rect widgetRect, Rect visibleArea) {
    final area = widgetRect.width * widgetRect.height;
    final overlap = widgetRect.intersect(visibleArea);
    final fraction = area <= 0 || overlap.width <= 0 || overlap.height <= 0
        ? 0.0
        : (overlap.width * overlap.height / area).clamp(0.0, 1.0);
    if (fraction != _lastFraction) {
      _lastFraction = fraction;
      onVisibleFractionChanged(fraction);
    }
  }

  /// Stops listening to scrolling for this widget.
  void stopVisibilityTracking() {
    _tracking = false;
    _detach();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Registers a dependency, so a resize (rotation, window resize) brings
    // us back here and triggers a fresh check.
    MediaQuery.sizeOf(context);
    if (_tracking) _attach();
    scheduleVisibilityCheck();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  /// Requests a check after the next frame (cheap to call repeatedly).
  void scheduleVisibilityCheck() {
    if (_checkScheduled || !_tracking) return;
    _checkScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _checkScheduled = false;
        if (mounted && _tracking) _check();
      })
      ..ensureVisualUpdate();
  }

  void _attach() {
    _detach();
    var scrollable = Scrollable.maybeOf(context);
    while (scrollable != null) {
      final position = scrollable.position
        ..addListener(scheduleVisibilityCheck);
      _positions.add(position);
      scrollable = Scrollable.maybeOf(scrollable.context);
    }
  }

  void _detach() {
    for (final position in _positions) {
      position.removeListener(scheduleVisibilityCheck);
    }
    _positions.clear();
  }

  void _check() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final widgetRect = box.localToGlobal(Offset.zero) & box.size;

    var visibleArea = Offset.zero & MediaQuery.sizeOf(context);
    var scrollable = Scrollable.maybeOf(context);
    while (scrollable != null) {
      final viewport = scrollable.context.findRenderObject();
      if (viewport is RenderBox && viewport.attached && viewport.hasSize) {
        visibleArea = visibleArea.intersect(
          viewport.localToGlobal(Offset.zero) & viewport.size,
        );
      }
      scrollable = Scrollable.maybeOf(scrollable.context);
    }
    handleViewportGeometry(widgetRect, visibleArea);
  }
}

/// Rebuilds its child with `visible: true/false` as it scrolls in and out of
/// view.
///
/// Use it to pause expensive work (animations, video, shaders) while it is
/// off screen, or to start lazy loading the first time it appears.
///
/// ```dart
/// VisibilityGate(
///   onFirstVisible: () => context.read<FeedCubit>().load(),
///   builder: (context, visible) => FancyChart(animate: visible),
/// );
/// ```
///
/// * [threshold] is the fraction of the widget that must be on screen.
/// * Rebuilds only when the visible/hidden state flips, not on every scroll.
class VisibilityGate extends StatefulWidget {
  const VisibilityGate({
    super.key,
    required this.builder,
    this.threshold = 0.01,
    this.onFirstVisible,
    this.onVisibilityChanged,
  });

  final Widget Function(BuildContext context, bool visible) builder;

  /// Fraction (0..1) of the widget that must be visible to count as visible.
  final double threshold;

  /// Called once, the first time the widget becomes visible.
  final VoidCallback? onFirstVisible;

  /// Called every time the visible state flips.
  final ValueChanged<bool>? onVisibilityChanged;

  @override
  State<VisibilityGate> createState() => _VisibilityGateState();
}

class _VisibilityGateState extends State<VisibilityGate>
    with ViewportVisibilityMixin {
  bool _visible = false;
  bool _seen = false;

  @override
  void onVisibleFractionChanged(double fraction) {
    final visible = fraction > widget.threshold;
    if (visible && !_seen) {
      _seen = true;
      widget.onFirstVisible?.call();
    }
    if (visible != _visible) {
      setState(() => _visible = visible);
      widget.onVisibilityChanged?.call(visible);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Content size changes can move us without any scrolling.
    scheduleVisibilityCheck();
    return widget.builder(context, _visible);
  }
}
