import 'package:flutter/material.dart';
import 'package:idara_esign/config/theme/theme.dart';

class IconIllustration extends StatelessWidget {
  const IconIllustration({
    super.key,
    required this.icon,
    this.size,
    this.iconColor,
  });
  final IconData icon;
  final double? size;
  final Color? iconColor;
  @override
  Widget build(BuildContext context) {
    // Centred so a stretching parent (a Column with
    // CrossAxisAlignment.stretch) can't pull the circle into a pill.
    return Center(
      child: Container(
        width: size ?? 120,
        height: size ?? 120,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradientOf(context),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.brandBorderOf(context), width: 2),
        ),
        child: Icon(icon, size: 50, color: iconColor),
      ),
    );
  }
}
