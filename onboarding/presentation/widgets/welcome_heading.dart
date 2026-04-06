import 'package:flutter/material.dart';
import 'package:idara_esign/config/theme/theme.dart';
import 'package:idara_esign/core/responsive/responsive.dart';

class WelcomeHeading extends StatelessWidget {
  const WelcomeHeading({
    super.key,
    required this.title1,
    required this.title2,
    required this.subtitle,
  });
  final String title1;
  final String title2;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: '$title1\n',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).textTheme.headlineMedium?.color,
                  height: 1.1,
                ),
              ),
              WidgetSpan(
                child: ShaderMask(
                  shaderCallback: (bounds) => AppColors.brandTextGradientOf(
                    context,
                  ).createShader(bounds),
                  child: Text(
                    title2,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.width * 0.15),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
