import 'package:flutter/material.dart';

/// Rebuilds the widget subtree under a fresh key, resetting all widget state.
///
/// Useful for things like a language switch. It does **not** apply a Shorebird
/// patch: patches are loaded by the engine when the OS process starts, and this
/// only re-runs `build` inside the running isolate.
///
/// Wrap your app with it once:
///
/// ```dart
/// runApp(RestartWidget(child: MyApp()));
/// ```
class RestartWidget extends StatefulWidget {
  const RestartWidget({super.key, required this.child});

  final Widget child;

  /// Resets the subtree. No-op if no [RestartWidget] is above [context].
  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restartApp();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: key, child: widget.child);
  }
}
