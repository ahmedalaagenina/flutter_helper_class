import 'package:flutter/material.dart';

/// The classic "transparency" checkerboard, used behind result previews so
/// users can see which parts of their image are see-through.
class CheckerboardBackground extends StatelessWidget {
  const CheckerboardBackground({
    super.key,
    required this.child,
    this.cellSize = 10,
    this.borderRadius,
  });

  final Widget child;
  final double cellSize;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CustomPaint(
        painter: _CheckerboardPainter(
          cellSize: cellSize,
          light: dark ? const Color(0xFF3A3A3A) : const Color(0xFFF2F2F2),
          darkCell: dark ? const Color(0xFF2A2A2A) : const Color(0xFFD9D9D9),
        ),
        child: child,
      ),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter({
    required this.cellSize,
    required this.light,
    required this.darkCell,
  });

  final double cellSize;
  final Color light;
  final Color darkCell;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = light;
    canvas.drawRect(Offset.zero & size, paint);
    paint.color = darkCell;
    final cols = (size.width / cellSize).ceil();
    final rows = (size.height / cellSize).ceil();
    for (var r = 0; r < rows; r++) {
      for (var c = r.isEven ? 1 : 0; c < cols; c += 2) {
        canvas.drawRect(
          Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerboardPainter old) =>
      old.cellSize != cellSize || old.light != light || old.darkCell != darkCell;
}
