import 'package:flutter/material.dart';

import 'theme.dart';

/// Theme data generator
class AppTheme {
  final BaseTypography typography;
  final BaseColors colors;
  final double elevation;
  final bool useMaterial3;

  const AppTheme({
    required this.typography,
    required this.colors,
    this.elevation = 0, // in material 3 elevation is best to be 0
    this.useMaterial3 = true,
  });

  /// Create theme based on system brightness
  static AppTheme create({
    required Brightness brightness,
    AppTypographyFont typography = AppTypographyFont.appDefault,
    double? fontSizeScaleFactor,
  }) {
    return AppTheme(
      typography: TypographyFactory.create(
        typography,
        fontSizeScaleFactor: fontSizeScaleFactor ?? 1.0,
      ),
      colors: brightness == Brightness.dark
          ? const DarkColors()
          : const LightColors(),
    );
  }

  /// Create theme based on provided typography and colors
  static AppTheme createWithCustomColors({
    required AppTypographyFont typography,
    required BaseColors colors,
    double fontSizeScaleFactor = 1.0,
    double elevation = 2.0,
    bool useMaterial3 = true,
  }) {
    return AppTheme(
      typography: TypographyFactory.create(
        typography,
        fontSizeScaleFactor: fontSizeScaleFactor,
      ),
      colors: colors,
      elevation: elevation,
      useMaterial3: useMaterial3,
    );
  }

  /// Create ThemeData based on provided typography and colors
  ThemeData build() {
    final colorScheme = colors.toColorScheme();

    return ThemeData(
      useMaterial3: useMaterial3,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,

      fontFamily: typography.fontFamily,
      fontFamilyFallback: typography.fontFamilyFallback,
      // Apply color scheme to various components
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: elevation,
        scrolledUnderElevation: 0, // to prevent changing color when scrolling
      ),

      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.outline.withValues(alpha: 0.5)),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: elevation,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      // Extensions
      extensions: [AppThemeExtension(typography: typography, colors: colors)],
    );
  }

  static AppThemeExtension of(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    assert(ext != null, 'AppThemeExtension is not found in ThemeData');
    return ext!;
  }
}
