import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// Relative on purpose: the motion/ folder is copied into apps as one unit.
// ignore: always_use_package_imports
import 'springs.dart';
// ignore: always_use_package_imports
import 'viewport_visibility.dart';

/// Tells its builder how far the reader has scrolled through this widget,
/// as a number from 0 to 1.
///
/// Great for scroll-driven effects: a timeline line that draws itself, a
/// progress bar for an article, parallax. The value is a [ValueListenable],
/// so you can repaint just a CustomPaint without rebuilding anything.
///
/// ```dart
/// ScrollProgress(
///   builder: (context, progress, child) => CustomPaint(
///     painter: LinePainter(progress), // LinePainter(..) : super(repaint: progress)
///     child: child,
///   ),
///   child: const TimelineContent(),
/// );
/// ```
///
/// * 0 = the reading line has not reached the widget's top yet, 1 = it has
///   passed the widget's bottom.
/// * [readingLine] is a fraction of the visible viewport height (0.6 means a
///   bit below the middle, where people actually read).
/// * Updates are coalesced to one per frame and only notify on change.
/// * Reduced motion reports 1 (everything shown, nothing animates).
class ScrollProgress extends StatefulWidget {
  const ScrollProgress({
    super.key,
    required this.builder,
    this.readingLine = 0.6,
    this.child,
  });

  final Widget Function(
    BuildContext context,
    ValueListenable<double> progress,
    Widget? child,
  )
  builder;

  /// Position of the reading line as a fraction of the viewport height.
  final double readingLine;

  /// Optional subtree passed through to [builder] unchanged.
  final Widget? child;

  @override
  State<ScrollProgress> createState() => _ScrollProgressState();
}

class _ScrollProgressState extends State<ScrollProgress>
    with ViewportVisibilityMixin {
  final _progress = ValueNotifier<double>(0);

  @override
  void handleViewportGeometry(Rect widgetRect, Rect visibleArea) {
    if (context.reduceMotion) {
      _progress.value = 1;
      return;
    }
    if (widgetRect.height <= 0) return;
    final line = visibleArea.top + visibleArea.height * widget.readingLine;
    _progress.value = ((line - widgetRect.top) / widgetRect.height).clamp(
      0.0,
      1.0,
    );
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    scheduleVisibilityCheck();
    return widget.builder(context, _progress, widget.child);
  }
}
