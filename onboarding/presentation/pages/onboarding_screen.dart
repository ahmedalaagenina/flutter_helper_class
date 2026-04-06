import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:idara_esign/config/routes/route_names.dart';
import 'package:idara_esign/config/theme/theme.dart';
import 'package:idara_esign/core/responsive/max_width_center.dart';
import 'package:idara_esign/core/widgets/widgets.dart';
import 'package:idara_esign/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:idara_esign/features/onboarding/presentation/widgets/widgets.dart';
import 'package:idara_esign/generated/l10n.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  final List<Widget> _pages = const [
    Onboarding1(),
    Onboarding2(),
    Onboarding3(),
  ];

  bool get _isLast => _index == _pages.length - 1;
  bool get _isFirst => _index == 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await context.read<OnboardingCubit>().complete();
    if (!mounted) return;
    context.go(Routes.sharedWelcome);
  }

  void _next() {
    if (_isLast) {
      _completeOnboarding();
      return;
    }

    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: MaxWidthCenter(
          maxWidth: 650,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: .end,
                  children: [
                    _isFirst
                        ? LocaleIcon()
                        : AppButtonText(
                            title: S.of(context).skip,
                            onPressed: _completeOnboarding,
                            backgroundColor: Colors.transparent,
                            textColor: theme.colorScheme.primary,
                          ),
                  ],
                ),
              ),

              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _pages[i],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  children: [
                    _Dots(count: _pages.length, index: _index),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: .center,
                      children: [
                        if (!_isFirst) ...[
                          Expanded(
                            child: AppButtonText(
                              width: double.infinity,
                              title: S.of(context).back,
                              onPressed: _isFirst
                                  ? null
                                  : () => _controller.previousPage(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeOutCubic,
                                    ),
                              backgroundColor: Colors.transparent,
                              textColor: theme.colorScheme.primary,
                              radius: 100,
                              border: Border.all(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: AppButtonText(
                            title: _isLast
                                ? S.of(context).getStarted
                                : S.of(context).next,
                            onPressed: _next,
                            gradient: AppColors.brandGradientOf(context),
                            width: double.infinity,
                            textColor: theme.colorScheme.onPrimary,
                            radius: 100,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final selected = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),

          width: selected ? 32 : 10,
          height: 10,
          decoration: BoxDecoration(
            gradient: selected ? AppColors.brandTextGradientOf(context) : null,
            borderRadius: BorderRadius.circular(99),
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        );
      }),
    );
  }
}
