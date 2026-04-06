import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:idara_esign/core/utils/app_images.dart';
import 'package:idara_esign/features/onboarding/presentation/widgets/welcome_heading.dart';
import 'package:idara_esign/generated/l10n.dart';

class Onboarding3 extends StatelessWidget {
  const Onboarding3({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Spacer(),
        SvgPicture.asset(AppImages.onboarding3, width: 350, height: 350),

        const SizedBox(height: 32),
        WelcomeHeading(
          title1: S.of(context).onboarding3Title1,
          title2: S.of(context).onboarding3Title2,
          subtitle: S.of(context).onboarding3Subtitle,
        ),

        Spacer(),
      ],
    );
  }
}
