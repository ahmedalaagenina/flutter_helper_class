import 'package:flutter/material.dart';
import 'package:idara_esign/config/theme/theme.dart';
import 'package:idara_esign/core/responsive/responsive.dart';
import 'package:idara_esign/core/widgets/modern_feature_tag.dart';
import 'package:idara_esign/features/onboarding/presentation/widgets/welcome_heading.dart';
import 'package:idara_esign/features/onboarding/presentation/widgets/welcome_page_icon_animation.dart';
import 'package:idara_esign/generated/l10n.dart';

class Onboarding1 extends StatelessWidget {
  const Onboarding1({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Spacer(),
        WelcomePageIconAnimation(isSmallScreen: context.isMobileLayout),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            ModernFeatureTag(
              icon: Icons.enhanced_encryption,
              text: S.of(context).encrypted,
              color: AppColors.success,
            ),
            ModernFeatureTag(
              icon: Icons.gavel,
              text: S.of(context).legal,
              color: AppColors.info,
            ),
            ModernFeatureTag(
              icon: Icons.bolt,
              text: S.of(context).fast,
              color: AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: 50),
        WelcomeHeading(
          title1: S.of(context).onboarding1Title1,
          title2: S.of(context).onboarding1Title2,
          subtitle: S.of(context).onboarding1Subtitle,
        ),

        Spacer(),
      ],
    );
  }
}
