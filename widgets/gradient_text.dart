import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  const GradientText(this.text, {super.key, this.style, this.textAlign});

  @override
  Widget build(BuildContext context) {
    final gradient = context.tokens.accentGradient;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: style, textAlign: textAlign),
    );
  }
}
