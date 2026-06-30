import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A reusable ticket-shaped card with a stub section, perforation line, and main body.
class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.title,
    required this.stubValue,
    required this.stubLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.footerText,
    required this.selected,
    required this.onTap,
    this.textToCopy,
    this.stubIcon = Icons.toll_outlined,
    this.footerIcon = Icons.schedule_outlined,
    this.cardRadius = 16.0,
    this.chipRadius = 100.0,
  });

  final String title;
  final String stubValue;
  final String stubLabel;
  final String statusLabel;
  final Color statusColor;
  final String footerText;
  final bool selected;
  final VoidCallback onTap;
  final String? textToCopy;
  final IconData stubIcon;
  final IconData footerIcon;
  final double cardRadius;
  final double chipRadius;

  static const double _stubWidth = 96;
  static const double _notchRadius = 7;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final surfaceColor = cs.surface;
    final outlineColor = cs.outline;
    final outlineVariantColor = cs.outlineVariant;
    final primaryColor = cs.primary;
    final textSecondaryColor = cs.onSurfaceVariant;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          foregroundPainter: _TicketBorderPainter(
            color: selected ? primaryColor : outlineColor,
            strokeWidth: selected ? 1.5 : 1,
            stubWidth: _stubWidth,
            notchRadius: _notchRadius,
            radius: cardRadius,
          ),
          child: ClipPath(
            clipper: _TicketClipper(
              stubWidth: _stubWidth,
              notchRadius: _notchRadius,
              radius: cardRadius,
            ),
            child: ColoredBox(
              color: surfaceColor,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Value stub ──────────────────────────────
                  Container(
                    width: _stubWidth,
                    color: statusColor.withValues(alpha: 0.10),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(stubIcon, size: 18, color: statusColor),
                        const SizedBox(height: 6),
                        FittedBox(
                          child: Text(
                            stubValue,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stubLabel,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: textSecondaryColor),
                        ),
                      ],
                    ),
                  ),
                  // ── Perforation ─────────────────────────────
                  _DashedLine(color: outlineVariantColor),
                  // ── Body ────────────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                ),
                              ),
                              if (textToCopy != null)
                                InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: textToCopy!),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Copied to clipboard'),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.copy_rounded,
                                      size: 15,
                                      color: textSecondaryColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          _StatusPill(
                            label: statusLabel,
                            color: statusColor,
                            chipRadius: chipRadius,
                          ),
                          Row(
                            children: [
                              Icon(
                                footerIcon,
                                size: 13,
                                color: textSecondaryColor,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  footerText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: textSecondaryColor),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Path _ticketPath(Size size, double stubWidth, double notchRadius, double r) {
  final base = Path()
    ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r)));
  final notches = Path()
    ..addOval(
      Rect.fromCircle(center: Offset(stubWidth, 0), radius: notchRadius),
    )
    ..addOval(
      Rect.fromCircle(
        center: Offset(stubWidth, size.height),
        radius: notchRadius,
      ),
    );
  return Path.combine(PathOperation.difference, base, notches);
}

class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper({
    required this.stubWidth,
    required this.notchRadius,
    required this.radius,
  });

  final double stubWidth;
  final double notchRadius;
  final double radius;

  @override
  Path getClip(Size size) => _ticketPath(size, stubWidth, notchRadius, radius);

  @override
  bool shouldReclip(covariant _TicketClipper old) =>
      old.stubWidth != stubWidth ||
      old.notchRadius != notchRadius ||
      old.radius != radius;
}

class _TicketBorderPainter extends CustomPainter {
  _TicketBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.stubWidth,
    required this.notchRadius,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double stubWidth;
  final double notchRadius;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _ticketPath(size, stubWidth, notchRadius, radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TicketBorderPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.stubWidth != stubWidth ||
      old.notchRadius != notchRadius ||
      old.radius != radius;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.chipRadius,
  });

  final String label;
  final Color color;
  final double chipRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(chipRadius),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsetsDirectional.only(end: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      child: CustomPaint(painter: _DashedLinePainter(color)),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 4.0;
    const gap = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => old.color != color;
}
