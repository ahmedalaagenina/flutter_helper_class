import 'package:flutter/material.dart';

/// Makes its child resize the sheet, whatever the list is doing.
///
/// `DraggableScrollableSheet` normally only resizes when the inner scroll view
/// is at an edge — sensible for the list, wrong for a grab handle. This drives
/// [controller] from the raw gesture instead, so the header always moves the
/// sheet.
class AppSheetDragArea extends StatefulWidget {
  const AppSheetDragArea({
    required this.controller,
    required this.snapSizes,
    required this.child,
    super.key,
  });

  final DraggableScrollableController controller;

  /// Sorted ascending. The drag settles on whichever is nearest.
  final List<double> snapSizes;

  final Widget child;

  @override
  State<AppSheetDragArea> createState() => _AppSheetDragAreaState();
}

class _AppSheetDragAreaState extends State<AppSheetDragArea> {
  double get _min => widget.snapSizes.first;
  double get _max => widget.snapSizes.last;

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.controller.isAttached) return;

    // Dragging *up* is a negative dy but a larger sheet, hence the subtraction.
    final height = MediaQuery.sizeOf(context).height;
    if (height <= 0) return;

    final next = (widget.controller.size - details.primaryDelta! / height)
        .clamp(_min, _max);
    widget.controller.jumpTo(next);
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.controller.isAttached) return;

    final height = MediaQuery.sizeOf(context).height;
    final current = widget.controller.size;

    // Project the fling a little so a quick flick carries to the next stop
    // rather than snapping back to where the finger left off.
    final velocity = -details.velocity.pixelsPerSecond.dy / height;
    final projected = (current + velocity * 0.12).clamp(_min, _max);

    var target = widget.snapSizes.first;
    for (final size in widget.snapSizes) {
      if ((size - projected).abs() < (target - projected).abs()) target = size;
    }

    widget.controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Opaque so drags starting on the surface between controls are caught
      // too, not just those landing exactly on the handle.
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: widget.child,
    );
  }
}
