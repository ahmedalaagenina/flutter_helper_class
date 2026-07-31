import 'package:flutter/material.dart';

import '../theme.dart';

class DarkColors extends BaseColors {
  const DarkColors();

  // ---------------------------------------------------------------------------
  // Brand core
  // ---------------------------------------------------------------------------

  /// Main primary color in dark mode.
  /// Usually lighter than the light-mode primary so it is more visible on dark UI.
  @override
  Color get primary => BrandPalette.red500;

  /// Darker original brand tone used for containers and deeper emphasis.
  @override
  Color get primaryDark => BrandPalette.red700;

  /// Lighter variation of the dark theme primary.
  @override
  Color get primaryLight => BrandPalette.red300;

  /// Text/icons shown on primary surfaces.
  @override
  Color get onPrimary => BrandPalette.inkOnRed;

  /// Secondary accent color in dark mode.
  @override
  Color get secondary => BrandPalette.n200;

  /// Darker variation of the secondary color.
  @override
  Color get secondaryDark => BrandPalette.n400;

  /// Lighter variation of the secondary color.
  @override
  Color get secondaryLight => BrandPalette.n100;

  /// Text/icons shown on top of secondary surfaces.
  @override
  Color get onSecondary => BrandPalette.inkOnLight;

  // ---------------------------------------------------------------------------
  // Surface hierarchy
  // ---------------------------------------------------------------------------

  /// Main app background in dark mode.
  @override
  Color get surface => BrandPalette.n900;

  /// Main text color on dark surfaces.
  @override
  Color get onSurface => BrandPalette.inkOnDark;

  /// Standard container surface in dark mode.
  @override
  Color get surfaceContainer => BrandPalette.n850;

  /// More prominent container surface in dark mode.
  @override
  Color get surfaceVariant => BrandPalette.n800;

  /// Secondary text/icon color used on dark surfaces.
  @override
  Color get onSurfaceVariant => BrandPalette.n400;

  // ---------------------------------------------------------------------------
  // Semantic colors
  // ---------------------------------------------------------------------------

  /// Error / destructive color in dark mode.
  @override
  Color get error => const Color(0xFFFF8A80);

  /// Success color in dark mode.
  @override
  Color get success => const Color(0xFF22C55E);

  /// Warning color in dark mode.
  @override
  Color get warning => const Color(0xFFF59E0B);

  /// Informational color in dark mode.
  @override
  Color get info => const Color(0xFF38BDF8);

  /// Text/icon color shown on top of the error color.
  @override
  Color get onError => BrandPalette.inkOnLight;

  /// Text/icon color shown on top of the success color.
  @override
  Color get onSuccess => Colors.black;

  /// Text/icon color shown on top of the warning color.
  @override
  Color get onWarning => Colors.black;

  /// Text/icon color shown on top of the info color.
  @override
  Color get onInfo => Colors.black;

  // ---------------------------------------------------------------------------
  // Extended colors
  // ---------------------------------------------------------------------------

  /// Strong border color in dark mode.
  @override
  Color get outline => BrandPalette.outlineDark;

  /// Softer border/divider color in dark mode.
  @override
  Color get outlineVariant => BrandPalette.n600;

  /// Brand-aware primary used on inverse surfaces.
  @override
  Color get inversePrimary => BrandPalette.red700;

  /// Inverse surface used when a light surface is needed inside dark UI.
  @override
  Color get inverseSurface => BrandPalette.n50;

  /// Text/icon color displayed on inverseSurface.
  @override
  Color get onInverseSurface => BrandPalette.inkOnLight;

  /// Overlay color used behind dialogs, sheets, and drawers in dark mode.
  @override
  Color get scrim => Colors.black.withValues(alpha: 0.60);
  @override
  ColorScheme toColorScheme() {
    // -------------------------------------------------------------------------
    // STEP 1:
    // Build the base Material 3 palette using the darker original brand tone.
    //
    // Why use primaryDark as the seed here?
    // - It keeps the palette rooted in the original brand color
    // - While still allowing the visible primary color to be lighter in dark mode
    // -------------------------------------------------------------------------
    final base = ColorScheme.fromSeed(
      seedColor: primaryDark,
      brightness: Brightness.dark,
    );

    // -------------------------------------------------------------------------
    // STEP 2:
    // Override only the colors we intentionally want to lock.
    // -------------------------------------------------------------------------
    return base.copyWith(
      // -----------------------------------------------------------------------
      // Core brand colors
      // -----------------------------------------------------------------------

      // Main primary color for dark mode.
      primary: primary,

      // Text/icon color shown on top of primary.
      onPrimary: onPrimary,

      // Darker/tinted primary container for dark mode highlighted sections.
      primaryContainer: primaryDark.withValues(alpha: 0.35),
      // Text/icon color displayed on primaryContainer.
      onPrimaryContainer: Colors.white,

      // Secondary accent color.
      //
      // Scenario 1 (primary only):
      // - you may remove this line and let Material generate secondary.
      secondary: secondary,

      // Text/icon color shown on top of secondary.
      onSecondary: onSecondary,

      // Darker/tinted secondary container for dark mode.
      secondaryContainer: secondaryDark.withValues(alpha: 0.30),
      // Text/icon color shown on top of secondaryContainer.
      onSecondaryContainer: Colors.white,

      // -----------------------------------------------------------------------
      // Tertiary / informational mapping
      // -----------------------------------------------------------------------

      // Third accent role mapped to the info color.
      tertiary: info,

      // Text/icon color displayed on tertiary color.
      onTertiary: onInfo,

      // Informational container for dark mode.
      tertiaryContainer: info.withValues(alpha: 0.20),
      // Text/icon color shown on top of tertiaryContainer.
      onTertiaryContainer: Colors.white,

      // -----------------------------------------------------------------------
      // Error colors
      // -----------------------------------------------------------------------

      // Error color for invalid/destructive states.
      error: error,

      // Text/icon color displayed on top of error.
      onError: onError,

      // Soft tinted error container for dark mode.
      errorContainer: error.withValues(alpha: 0.20),
      // Text/icon color displayed on top of errorContainer.
      onErrorContainer: Colors.white,

      // -----------------------------------------------------------------------
      // Surface hierarchy
      // -----------------------------------------------------------------------

      // Main application surface/background.
      surface: surface,

      // Main text/icon color on surface.
      onSurface: onSurface,

      // Standard container surface in dark mode.
      surfaceContainer: surfaceContainer,

      // Stronger/prominent container surface in dark mode.
      surfaceContainerHighest: surfaceVariant,

      // Secondary text/icon color on surfaces.
      onSurfaceVariant: onSurfaceVariant,

      // -----------------------------------------------------------------------
      // Borders and inverse roles
      // -----------------------------------------------------------------------

      // Strong border color.
      outline: outline,

      // Soft border/divider color.
      outlineVariant: outlineVariant,

      // Inverse surface used where the UI needs strong contrast.
      inverseSurface: inverseSurface,

      // Text/icon color displayed on inverseSurface.
      onInverseSurface: onInverseSurface,

      // Brand-aware primary shown on inverse surfaces.
      inversePrimary: inversePrimary,

      // -----------------------------------------------------------------------
      // Shadow / overlays
      // -----------------------------------------------------------------------

      // Shadow color used for elevated components.
      shadow: scrim,

      // Overlay color used behind dialogs, sheets, drawers, and modals.
      scrim: scrim,
    );
  }
}
