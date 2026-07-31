import 'package:flutter/material.dart';

class ScrollWithFixedBottom extends StatelessWidget {
  final Widget scrollableContent;
  final Widget bottomContent;

  const ScrollWithFixedBottom({
    Key? key,
    required this.scrollableContent,
    required this.bottomContent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: scrollableContent,
              )
            ],
          ),
        ),
        bottomContent,
      ],
    );
  }
}
