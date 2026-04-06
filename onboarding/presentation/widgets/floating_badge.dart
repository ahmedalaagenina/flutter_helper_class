import 'package:flutter/material.dart';

// Floating badge with animation
class FloatingBadge extends StatefulWidget {
  final IconData icon;
  final Color color;
  final int delay;

  const FloatingBadge({
    super.key,
    required this.icon,
    required this.color,
    required this.delay,
  });

  @override
  FloatingBadgeState createState() => FloatingBadgeState();
}

class FloatingBadgeState extends State<FloatingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    // Add delay
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * _controller.value),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.color.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(widget.icon, size: 24, color: widget.color),
      ),
    );
  }
}
