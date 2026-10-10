import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status bar (and Android nav bar) icon style that stays readable on the app
/// background: dark icons on the light theme, light icons on the dark one.
///
/// Used in two places because Flutter has no single theme switch for it:
/// `appBarTheme.systemOverlayStyle` covers screens with an AppBar (a
/// transparent AppBar would otherwise derive white icons from
/// Colors.transparent), and [AppSystemUiRegion] covers the rest.
SystemUiOverlayStyle appSystemUiStyle({required bool isDark}) =>
    isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

/// Applies [appSystemUiStyle] for the current theme to screens without an
/// AppBar (e.g. the dashboard). Follows theme changes because it reads
/// [Theme.of]; an AppBar still sets its own style over its area.
class AppSystemUiRegion extends StatelessWidget {
  const AppSystemUiRegion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: appSystemUiStyle(isDark: isDark),
      child: child,
    );
  }
}

// in app.dart
// it return to ui
//  return AppSystemUiRegion(
//    child:OurApp(),
//  );
