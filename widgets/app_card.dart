import 'package:flutter/material.dart';

import '../../config/theme/app_theme_extension.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final cardTheme = Theme.of(context).cardTheme;
    final themedShape = cardTheme.shape;
    final themedSide = themedShape is RoundedRectangleBorder
        ? themedShape.side
        : BorderSide(color: appTheme.colors.outline.withValues(alpha: 0.35));
    final shape = borderRadius != null
        ? RoundedRectangleBorder(borderRadius: borderRadius!, side: themedSide)
        : themedShape;
    final themedBorderRadius =
        themedShape is RoundedRectangleBorder &&
            themedShape.borderRadius is BorderRadius
        ? themedShape.borderRadius as BorderRadius
        : null;
    final inkBorderRadius = borderRadius ?? themedBorderRadius;

    return Card(
      margin: margin ?? cardTheme.margin,
      elevation: cardTheme.elevation,
      shadowColor: cardTheme.shadowColor,
      color: cardTheme.color ?? appTheme.colors.surface,
      surfaceTintColor: cardTheme.surfaceTintColor,
      shape: shape,
      clipBehavior: cardTheme.clipBehavior ?? Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: inkBorderRadius,
        child: Padding(padding: padding!, child: child),
      ),
    );
  }
}
