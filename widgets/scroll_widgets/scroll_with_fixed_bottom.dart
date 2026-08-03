import 'package:flutter/material.dart';

class ScrollWithFixedBottom extends StatelessWidget {
  const ScrollWithFixedBottom({
    super.key,
    required this.scrollableContent,
    required this.bottomContent,
    this.padding,
    this.bottomPadding,
    this.physics = const ClampingScrollPhysics(),
  });

  final Widget scrollableContent;
  final Widget bottomContent;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? bottomPadding;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            physics: physics,
            slivers: [
              SliverPadding(
                padding: padding ?? EdgeInsets.zero,
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: scrollableContent,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: bottomPadding ?? EdgeInsets.zero,
          child: bottomContent,
        ),
      ],
    );
  }
}
