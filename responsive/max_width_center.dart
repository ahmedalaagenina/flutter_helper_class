import 'package:flutter/material.dart';
import 'package:idara_esign/core/responsive/responsive.dart';

/// this class use to make item center in screen
/// with his original width
class MaxWidthCenter extends StatelessWidget {
  const MaxWidthCenter({
    super.key,
    required this.child,
    required this.maxWidth,
    this.maxHeight,
    this.alignment,
  });

  final Widget child;
  final double maxWidth;
  final double? maxHeight;

  final Alignment? alignment;

  @override
  Widget build(BuildContext context) {
    final constrained = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: !context.isMobileLayout ? maxWidth : double.infinity,
        maxHeight: maxHeight ?? double.infinity,
      ),
      child: child,
    );

    if (alignment == null) {
      return Center(child: constrained);
    }
    return Align(alignment: alignment!, child: constrained);
  }
}
