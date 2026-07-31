import 'package:flutter/material.dart';

class ScrollOrFitBottom extends StatelessWidget {
  final Widget scrollableContent;
  final Widget bottomContent;

  const ScrollOrFitBottom({
    Key? key,
    required this.scrollableContent,
    required this.bottomContent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: <Widget>[
              Expanded(child: scrollableContent),
              bottomContent,
            ],
          ),
        ),
      ],
    );
  }
}
