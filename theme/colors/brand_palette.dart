import 'package:flutter/material.dart';

/// Raw brand ramps for iDara Tracking.
///
/// These are *values*, not roles. Never reference them from a widget — only
/// [LightColors] and [DarkColors] read them, and they map them onto semantic
/// roles that widgets consume through `Theme.of(context).colorScheme`.
///
/// Taken from the iDara.NET logo and website: red locator pin, black wordmark,
/// white ground. So the system is **red + graphite + white**, with teal kept
/// only as a functional map-overlay colour (see [teal500]).
abstract final class BrandPalette {
  // ---------------------------------------------------------------------------
  // Red — the brand ramp
  //
  // [red500] and [red700] are the two values supplied by the business:
  // the bright pin red and the deeper wordmark rule red.
  // ---------------------------------------------------------------------------

  static const Color red50 = Color(0xFFFFF0F2);
  static const Color red100 = Color(0xFFFFD9DE);
  static const Color red200 = Color(0xFFFCB3BD);
  static const Color red300 = Color(0xFFF77D8E);
  static const Color red400 = Color(0xFFF0455F);

  /// Brand core — the locator pin red. **Dark-mode primary.**
  ///
  /// Carries white text at 4.81:1 (AA) and sits 4.0:1 against the dark
  /// surface, so it works as a filled button on a dark screen.
  static const Color red500 = Color(0xFFE50127);

  static const Color red600 = Color(0xFFC90121);

  /// The deeper logo red. **Light-mode primary.**
  ///
  /// Carries white text at 7.38:1 (AAA). [red500] would only reach 4.81:1 on
  /// white, so the deeper tone is used wherever the ground is light.
  static const Color red700 = Color(0xFFAF011E);

  static const Color red800 = Color(0xFF8A0117);
  static const Color red900 = Color(0xFF5E0110);

  // ---------------------------------------------------------------------------
  // Teal — functional only, not brand
  //
  // Reserved for map overlays (geofences) where a distinct hue is needed that
  // collides with neither the brand red nor any device-status colour. Never
  // use it for chrome.
  // ---------------------------------------------------------------------------

  static const Color teal400 = Color(0xFF2BE0D0);
  static const Color teal500 = Color(0xFF14D3C4);
  static const Color teal600 = Color(0xFF0FB3A6);
  static const Color teal700 = Color(0xFF0A8C82);

  // ---------------------------------------------------------------------------
  // Neutrals — graphite, from the logo's black wordmark
  //
  // Previously navy-tinted to sit with a cyan brand. With a red brand a blue
  // cast turns muddy, so these are near-neutral with a trace of warmth.
  // ---------------------------------------------------------------------------

  static const Color n0 = Color(0xFFFFFFFF);
  static const Color n50 = Color(0xFFF7F7F8);
  static const Color n100 = Color(0xFFEEEEF0);
  static const Color n200 = Color(0xFFDEDEE2);
  static const Color n300 = Color(0xFFC4C4CA);
  static const Color n400 = Color(0xFF9A9AA3);
  static const Color n500 = Color(0xFF6E6E78);
  static const Color n600 = Color(0xFF4C4C55);
  static const Color n700 = Color(0xFF33333A);
  static const Color n800 = Color(0xFF212127);
  static const Color n850 = Color(0xFF18181D);
  static const Color n900 = Color(0xFF0E0E12);
  static const Color n950 = Color(0xFF08080A);

  // ---------------------------------------------------------------------------
  // Ink
  // ---------------------------------------------------------------------------

  /// Primary text on dark surfaces. 16.1:1 on [n900].
  static const Color inkOnDark = Color(0xFFEAEAEE);

  /// Primary text on light surfaces. 18.4:1 on white.
  static const Color inkOnLight = Color(0xFF141418);

  /// Text/icons on brand red, in both modes.
  ///
  /// Unlike the previous cyan brand — which needed near-black in dark mode —
  /// both red tones take white, so there is no per-mode exception to remember.
  static const Color inkOnRed = Color(0xFFFFFFFF);

  /// Text/icons on the teal overlay colour.
  static const Color inkOnTeal = Color(0xFF04231F);

  /// Border on dark surfaces, lifted just enough from [n800] that cards
  /// separate from the sheet behind them.
  static const Color outlineDark = Color(0xFF2C2C34);

  // ---------------------------------------------------------------------------
  // Map surfaces
  //
  // The map is rendered by Google, not by us, so it has its own palette.
  // Keep these in sync with assets/map/map_style_dark.json.
  // ---------------------------------------------------------------------------

  /// Water in the dark map style.
  static const Color mapWaterDark = Color(0xFF0A0A0D);

  /// Roads in the dark map style.
  static const Color mapRoadDark = Color(0xFF2A2A31);

  /// The user's own location dot. Blue in both modes — it must read as "you",
  /// distinct from every vehicle marker and from the brand red.
  static const Color userLocation = Color(0xFF2E8BFF);
}
