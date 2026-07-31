import 'package:flutter/material.dart';

import '../theme.dart';

class LightColors extends BaseColors {
  const LightColors();

  // ---------------------------------------------------------------------------
  // Brand core
  // ---------------------------------------------------------------------------

  /// Main light theme brand color.
  /// Change this first when the app brand changes.
  @override
  Color get primary => BrandPalette.red700;

  /// Darker manual variation of the brand color.
  @override
  Color get primaryDark => BrandPalette.red800;

  /// Lighter manual variation of the brand color.
  @override
  Color get primaryLight => BrandPalette.red100;

  /// Text/icons shown on primary surfaces.
  @override
  Color get onPrimary => BrandPalette.n0;

  /// Secondary accent color.
  ///
  /// Scenario 2 (primary + secondary):
  /// - keep this and set the real secondary brand color.
  ///
  /// Scenario 1 (primary only):
  /// - you can ignore overriding it in toColorScheme()
  /// - and let fromSeed generate it automatically.
  @override
  Color get secondary => BrandPalette.n800;

  /// Darker variation of secondary.
  @override
  Color get secondaryDark => BrandPalette.n900;

  /// Lighter variation of secondary.
  @override
  Color get secondaryLight => BrandPalette.n200;

  /// Text/icons shown on secondary surfaces.
  @override
  Color get onSecondary => BrandPalette.n0;

  // ---------------------------------------------------------------------------
  // Surface hierarchy
  // ---------------------------------------------------------------------------

  /// Main app background in light mode.
  @override
  Color get surface => BrandPalette.n0;

  /// Main text color on light surfaces.
  @override
  Color get onSurface => BrandPalette.inkOnLight;

  /// Standard container color for cards and inputs.
  @override
  Color get surfaceContainer => BrandPalette.n50;

  /// Stronger surface layer for more prominent containers.
  @override
  Color get surfaceVariant => BrandPalette.n100;

  /// Secondary text/icon color used on surface layers.
  @override
  Color get onSurfaceVariant => BrandPalette.n600;

  // ---------------------------------------------------------------------------
  // Semantic colors
  // ---------------------------------------------------------------------------

  /// Error / destructive color.
  @override
  Color get error => const Color(0xFF9F1239);

  /// Success / positive state color.
  @override
  Color get success => const Color(0xFF16A34A);

  /// Warning / caution color.
  @override
  Color get warning => const Color(0xFFD97706);

  /// Informational state color.
  @override
  Color get info => const Color(0xFF0284C7);

  /// Text/icon color shown on top of error color.
  @override
  Color get onError => Colors.white;

  /// Text/icon color shown on top of success color.
  @override
  Color get onSuccess => Colors.white;

  /// Text/icon color shown on top of warning color.
  @override
  Color get onWarning => Colors.black;

  /// Text/icon color shown on top of info color.
  @override
  Color get onInfo => Colors.white;

  // ---------------------------------------------------------------------------
  // Extended colors
  // ---------------------------------------------------------------------------

  /// Strong border color.
  @override
  Color get outline => BrandPalette.n200;

  /// Softer border/divider color.
  @override
  Color get outlineVariant => BrandPalette.n300;

  /// Primary-like color displayed on inverse surfaces.
  @override
  Color get inversePrimary => BrandPalette.red400;

  /// Strong inverse surface, useful for snackbars or dark overlays in light mode.
  @override
  Color get inverseSurface => BrandPalette.n900;

  /// Text/icon color shown on inverse surfaces.
  @override
  Color get onInverseSurface => BrandPalette.inkOnDark;

  /// Overlay color used behind dialogs, sheets, and drawers.
  @override
  Color get scrim => Colors.black.withValues(alpha: 0.20);
  @override
  ColorScheme toColorScheme() {
    // -------------------------------------------------------------------------
    // STEP 1:
    // Let Material 3 build a complete tonal palette from the primary color.
    //
    // Why?
    // - Better harmony between generated roles
    // - Better future compatibility with Material widgets
    // - Better automatic contrast defaults
    // -------------------------------------------------------------------------
    final base = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    );

    // -------------------------------------------------------------------------
    // STEP 2:
    // Override only the colors we intentionally want to lock.
    //
    // Why lock primary and onPrimary?
    // - fromSeed may slightly shift the color
    // - we want exact brand consistency
    //
    // Why keep generated roles?
    // - Material can generate many roles better than manual hardcoding
    // -------------------------------------------------------------------------
    return base.copyWith(
      // -----------------------------------------------------------------------
      // Core brand colors
      // -----------------------------------------------------------------------

      // Main brand color used for major interactive elements.
      primary: primary,

      // Text/icon color placed on top of the primary color.
      onPrimary: onPrimary,

      // A lighter tonal version of primary for larger highlighted containers.
      // In light mode, this is often used for subtle brand-tinted backgrounds.
      primaryContainer: primaryLight,

      // Text/icon color used on top of primaryContainer.
      // Should remain darker in light mode for readability.
      onPrimaryContainer: primaryDark,

      // Secondary brand color used for supporting actions and accents.
      //
      // Scenario 1 (primary only):
      // - you may remove this line and let Material generate secondary.
      secondary: secondary,

      // Text/icon color placed on top of the secondary color.
      onSecondary: onSecondary,

      // Lighter tonal variation of secondary for soft accent containers.
      secondaryContainer: secondaryLight,

      // Text/icon color used on top of secondaryContainer.
      onSecondaryContainer: secondaryDark,

      // -----------------------------------------------------------------------
      // Tertiary / informational mapping
      // -----------------------------------------------------------------------

      // Third accent role. Here we map it to the info color.
      tertiary: info,

      // Text/icon color displayed on tertiary color.
      onTertiary: onInfo,

      // Soft background for informational sections.
      tertiaryContainer: info.withValues(alpha: 0.10),
      // Text/icon color on tertiaryContainer.
      onTertiaryContainer: info.darker(0.20),

      // -----------------------------------------------------------------------
      // Error colors
      // -----------------------------------------------------------------------

      // Error color for invalid/destructive states.
      error: error,

      // Text/icon color displayed on the error color.
      onError: onError,

      // Soft background for error states.
      errorContainer: error.withValues(alpha: 0.10),
      // Text/icon color displayed on the errorContainer.
      onErrorContainer: error.darker(0.18),

      // -----------------------------------------------------------------------
      // Surface hierarchy
      // -----------------------------------------------------------------------

      // Main application surface/background.
      surface: surface,

      // Main text/icon color on the surface.
      onSurface: onSurface,

      // Standard container surface for cards, sheets, inputs, etc.
      surfaceContainer: surfaceContainer,

      // More prominent container surface.
      // Often useful for stronger cards, highlighted blocks, or bottom sheets.
      surfaceContainerHighest: surfaceVariant,

      // Secondary text/icon color used on surfaces.
      onSurfaceVariant: onSurfaceVariant,

      // -----------------------------------------------------------------------
      // Borders and inverse roles
      // -----------------------------------------------------------------------

      // Strong border color for outlined components and active edges.
      outline: outline,

      // Softer outline color for subtle dividers and inactive borders.
      outlineVariant: outlineVariant,

      // Inverse surface used where strong contrast against the normal surface is needed.
      inverseSurface: inverseSurface,

      // Text/icon color displayed on inverseSurface.
      onInverseSurface: onInverseSurface,

      // Brand-aware primary color used on inverseSurface.
      inversePrimary: inversePrimary,

      // -----------------------------------------------------------------------
      // Shadow / overlays
      // -----------------------------------------------------------------------

      // Shadow color used for elevation effects.
      shadow: scrim,

      // Overlay color used behind dialogs, sheets, drawers, and modals.
      scrim: scrim,
    );
  }
}
