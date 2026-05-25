import 'package:flutter/material.dart';
import 'breakpoints.dart';

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobileBody,
    this.tabletBody,
    required this.desktopBody,
    this.animationDuration = const Duration(milliseconds: 250),
  });

  final Widget mobileBody;
  final Widget? tabletBody;
  final Widget desktopBody;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget current;

        if (constraints.maxWidth < kMobileBreakPoint) {
          current = mobileBody;
        } else if (constraints.maxWidth < kTabletBreakpoint) {
          current = tabletBody ?? mobileBody;
        } else {
          current = desktopBody;
        }

        return AnimatedSwitcher(
          duration: animationDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(
              constraints.maxWidth < kMobileBreakPoint
                  ? 'mobile'
                  : constraints.maxWidth < kTabletBreakpoint
                  ? 'tablet'
                  : 'desktop',
            ),
            child: current,
          ),
        );
      },
    );
  }
}

/// without animation
// return LayoutBuilder(
// builder: (BuildContext context, BoxConstraints constraints) {
//     if (constraints.maxWidth < kTabletBreakpoint) {
//       return mobileBody;
//     } else if (constraints.maxWidth >= kTabletBreakpoint &&
//         constraints.maxWidth < kDesktopBreakPoint) {
//       return tabletBody ?? mobileBody;
//     } else {
//       return desktopBody ?? mobileBody;
//     }
//   },
// );
