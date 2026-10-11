import 'package:flutter/widgets.dart';

// Relative on purpose: the motion/ folder is copied into apps as one unit.
// ignore: always_use_package_imports
import 'reduced_motion_query_stub.dart'
    if (dart.library.js_interop) 'reduced_motion_query_web.dart';

/// Makes "reduce motion" work on the web too.
///
/// On iOS/Android Flutter already reports the OS setting through
/// `MediaQuery.disableAnimations`. On the web it doesn't read the browser's
/// `prefers-reduced-motion`, so wrap your app with this widget and every
/// `context.reduceMotion` check (and Flutter's own) sees one flag.
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => ReducedMotionScope(child: child!),
/// );
/// ```
///
/// * Follows the setting live if the user changes it while the app runs.
/// * Uses dart:js_interop behind a conditional import, so the same file
///   compiles (and does nothing extra) on mobile, desktop and in tests.
class ReducedMotionScope extends StatefulWidget {
  const ReducedMotionScope({super.key, required this.child});

  final Widget child;

  @override
  State<ReducedMotionScope> createState() => _ReducedMotionScopeState();
}

class _ReducedMotionScopeState extends State<ReducedMotionScope> {
  bool _reduce = prefersReducedMotion();
  late final void Function() _stopListening;

  @override
  void initState() {
    super.initState();
    _stopListening = listenReducedMotion((reduce) {
      if (mounted) setState(() => _reduce = reduce);
    });
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    if (!_reduce || data.disableAnimations) return widget.child;
    return MediaQuery(
      data: data.copyWith(disableAnimations: true),
      child: widget.child,
    );
  }
}
