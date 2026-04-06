import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:idara_esign/core/utils/app_images.dart';
import 'package:idara_esign/features/onboarding/presentation/widgets/welcome_heading.dart';
import 'package:idara_esign/generated/l10n.dart';

class Onboarding2 extends StatelessWidget {
  const Onboarding2({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Spacer(),
        SvgPicture.asset(AppImages.onboarding2, width: 400, height: 400),
        const SizedBox(height: 32),

        WelcomeHeading(
          title1: S.of(context).onboarding2Title1,
          title2: S.of(context).onboarding2Title2,
          subtitle: S.of(context).onboarding2Subtitle,
        ),
        Spacer(),
        Spacer(),
      ],
    );
  }
}
