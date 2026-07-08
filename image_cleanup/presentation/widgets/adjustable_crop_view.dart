import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/cleanup_options.dart' show CropShape;

/// Displays an image with a draggable/resizable crop region on top.
///
/// The crop rectangle is expressed in **image pixel coordinates** (same space
/// as the decoded image), so callers can hand it straight to the processing
/// pipeline. With [CropShape.oval] the kept region is the ellipse inscribed
/// in the rectangle; the handles still manipulate the bounding rectangle.
///
/// Drags write straight to [controller] and the overlay painter listens to
/// it (`CustomPainter.repaint`), so dragging repaints only the overlay —
/// the widget tree is not rebuilt per frame.
class AdjustableCropView extends StatefulWidget {
  const AdjustableCropView({
    super.key,
    required this.image,
    required this.controller,
    this.shape = CropShape.rectangle,
  });

  /// The already-decoded image to crop. The widget does not take ownership;
  /// the caller disposes it. Displayed via [RawImage] so no encode/decode
  /// round trip happens.
  final ui.Image image;

  /// Single source of truth for the crop rectangle, in image pixel
  /// coordinates. Drags write to it; external writes (e.g. an auto-detect
  /// reset) repaint the overlay. Owned and disposed by the caller.
  final ValueNotifier<Rect> controller;

  /// Shape of the kept region (rectangle, or the inscribed ellipse).
  final CropShape shape;

  @override
  State<AdjustableCropView> createState() => _AdjustableCropViewState();
}

enum _DragMode {
  none,
  move,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  left,
  top,
  right,
  bottom,
}

/// Where an image of [imageSize] lands inside [viewport] with
/// BoxFit.contain. Shared by layout, hit-testing, and the painter so all
/// three always agree.
Rect _fitRect(Size imageSize, Size viewport) {
  final scale = math.min(
    viewport.width / imageSize.width,
    viewport.height / imageSize.height,
  );
  final w = imageSize.width * scale;
  final h = imageSize.height * scale;
  return Rect.fromLTWH(
    (viewport.width - w) / 2,
    (viewport.height - h) / 2,
    w,
    h,
  );
}

class _AdjustableCropViewState extends State<AdjustableCropView> {
  static const double _cornerHitRadius = 28;
  static const double _edgeHitRadius = 20;

  _DragMode _mode = _DragMode.none;

  /// Latest layout size; kept so gesture handlers can map between display
  /// and image coordinates without a rebuild.
  Size _viewport = Size.zero;

  /// Display-px-per-image-px factor captured at drag start.
  double _dragScale = 1;

  Size get _imageSize =>
      Size(widget.image.width.toDouble(), widget.image.height.toDouble());

  Rect _cropDisplayRect(Rect display, double scale) {
    final crop = widget.controller.value;
    return Rect.fromLTRB(
      display.left + crop.left * scale,
      display.top + crop.top * scale,
      display.left + crop.right * scale,
      display.top + crop.bottom * scale,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final display = _fitRect(_imageSize, _viewport);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: (_) => _mode = _DragMode.none,
          onPanCancel: () => _mode = _DragMode.none,
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: display,
                child: RawImage(
                  image: widget.image,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _CropOverlayPainter(
                    crop: widget.controller,
                    imageSize: _imageSize,
                    shape: widget.shape,
                    accent: Theme.of(context).colorScheme.primary,
                    scrimColor: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onPanStart(DragStartDetails details) {
    // Recompute the display mapping now — the crop may have changed since
    // the last build (drags don't rebuild), so build-time values are stale.
    final display = _fitRect(_imageSize, _viewport);
    _dragScale = display.width / _imageSize.width;
    final cropDisplay = _cropDisplayRect(display, _dragScale);
    final pos = details.localPosition;

    bool near(Offset p) => (pos - p).distance <= _cornerHitRadius;
    final withinX =
        pos.dx >= cropDisplay.left - _edgeHitRadius &&
        pos.dx <= cropDisplay.right + _edgeHitRadius;
    final withinY =
        pos.dy >= cropDisplay.top - _edgeHitRadius &&
        pos.dy <= cropDisplay.bottom + _edgeHitRadius;

    if (near(cropDisplay.topLeft)) {
      _mode = _DragMode.topLeft;
    } else if (near(cropDisplay.topRight)) {
      _mode = _DragMode.topRight;
    } else if (near(cropDisplay.bottomLeft)) {
      _mode = _DragMode.bottomLeft;
    } else if (near(cropDisplay.bottomRight)) {
      _mode = _DragMode.bottomRight;
    } else if (withinY && (pos.dx - cropDisplay.left).abs() <= _edgeHitRadius) {
      _mode = _DragMode.left;
    } else if (withinY && (pos.dx - cropDisplay.right).abs() <= _edgeHitRadius) {
      _mode = _DragMode.right;
    } else if (withinX && (pos.dy - cropDisplay.top).abs() <= _edgeHitRadius) {
      _mode = _DragMode.top;
    } else if (withinX && (pos.dy - cropDisplay.bottom).abs() <= _edgeHitRadius) {
      _mode = _DragMode.bottom;
    } else if (cropDisplay.contains(pos)) {
      _mode = _DragMode.move;
    } else {
      _mode = _DragMode.none;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_mode == _DragMode.none || _dragScale <= 0) return;
    final dx = details.delta.dx / _dragScale;
    final dy = details.delta.dy / _dragScale;
    final imgW = _imageSize.width;
    final imgH = _imageSize.height;
    final r = widget.controller.value;

    if (_mode == _DragMode.move) {
      widget.controller.value = r.translate(
        dx.clamp(-r.left, imgW - r.right),
        dy.clamp(-r.top, imgH - r.bottom),
      );
      return;
    }

    // Keep the crop at least ~28 screen px so handles never overlap — but
    // never larger than the crop's current extent, so the clamp bounds
    // below stay ordered even if the viewport shrank since the crop was
    // last resized (a larger floor would make lower > upper and throw).
    var minSize = math.min(28 / _dragScale, math.min(imgW, imgH));
    minSize = math.min(minSize, math.min(r.width, r.height));

    final movesLeft = _mode == _DragMode.topLeft ||
        _mode == _DragMode.left ||
        _mode == _DragMode.bottomLeft;
    final movesRight = _mode == _DragMode.topRight ||
        _mode == _DragMode.right ||
        _mode == _DragMode.bottomRight;
    final movesTop = _mode == _DragMode.topLeft ||
        _mode == _DragMode.top ||
        _mode == _DragMode.topRight;
    final movesBottom = _mode == _DragMode.bottomLeft ||
        _mode == _DragMode.bottom ||
        _mode == _DragMode.bottomRight;

    widget.controller.value = Rect.fromLTRB(
      movesLeft ? (r.left + dx).clamp(0.0, r.right - minSize) : r.left,
      movesTop ? (r.top + dy).clamp(0.0, r.bottom - minSize) : r.top,
      movesRight ? (r.right + dx).clamp(r.left + minSize, imgW) : r.right,
      movesBottom ? (r.bottom + dy).clamp(r.top + minSize, imgH) : r.bottom,
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter({
    required this.crop,
    required this.imageSize,
    required this.shape,
    required this.accent,
    required this.scrimColor,
  }) : super(repaint: crop);

  /// Listened to via `repaint:` — crop changes repaint without a rebuild.
  final ValueNotifier<Rect> crop;
  final Size imageSize;
  final CropShape shape;
  final Color accent;
  final Color scrimColor;

  @override
  void paint(Canvas canvas, Size size) {
    final imageRect = _fitRect(imageSize, size);
    final scale = imageRect.width / imageSize.width;
    final c = crop.value;
    final cropRect = Rect.fromLTRB(
      imageRect.left + c.left * scale,
      imageRect.top + c.top * scale,
      imageRect.left + c.right * scale,
      imageRect.top + c.bottom * scale,
    );
    final oval = shape == CropShape.oval;

    // Dim everything outside the kept region.
    final scrim = Path()..addRect(imageRect);
    if (oval) {
      scrim.addOval(cropRect);
    } else {
      scrim.addRect(cropRect);
    }
    scrim.fillType = PathFillType.evenOdd;
    canvas.drawPath(scrim, Paint()..color = scrimColor);

    // Border of the kept region.
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;
    if (oval) {
      canvas.drawOval(cropRect, border);
      // Faint bounding box so the handles visibly belong to a rectangle.
      canvas.drawRect(
        cropRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.35),
      );
    } else {
      canvas.drawRect(cropRect, border);

      // Rule-of-thirds guides (rectangle only).
      final guide = Paint()
        ..strokeWidth = 0.8
        ..color = Colors.white.withValues(alpha: 0.45);
      for (var i = 1; i <= 2; i++) {
        final x = cropRect.left + cropRect.width * i / 3;
        final y = cropRect.top + cropRect.height * i / 3;
        canvas.drawLine(
          Offset(x, cropRect.top),
          Offset(x, cropRect.bottom),
          guide,
        );
        canvas.drawLine(
          Offset(cropRect.left, y),
          Offset(cropRect.right, y),
          guide,
        );
      }
    }

    // Corner handles.
    final handleFill = Paint()..color = accent;
    final handleRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;
    for (final corner in [
      cropRect.topLeft,
      cropRect.topRight,
      cropRect.bottomLeft,
      cropRect.bottomRight,
    ]) {
      canvas.drawCircle(corner, 9, handleFill);
      canvas.drawCircle(corner, 9, handleRing);
    }

    // Edge handles (small pills at edge midpoints).
    for (final (center, horizontal) in [
      (cropRect.topCenter, true),
      (cropRect.bottomCenter, true),
      (cropRect.centerLeft, false),
      (cropRect.centerRight, false),
    ]) {
      final rect = Rect.fromCenter(
        center: center,
        width: horizontal ? 26 : 7,
        height: horizontal ? 7 : 26,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      canvas.drawRRect(rrect, handleFill);
      canvas.drawRRect(rrect, handleRing);
    }
  }

  @override
  bool shouldRepaint(_CropOverlayPainter old) =>
      old.crop != crop ||
      old.imageSize != imageSize ||
      old.shape != shape ||
      old.accent != accent ||
      old.scrimColor != scrimColor;
}
