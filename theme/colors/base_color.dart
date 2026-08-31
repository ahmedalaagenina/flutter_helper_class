import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Base contract for all color implementations in the app.
abstract class BaseColors extends Equatable {
  const BaseColors();

  // ---------------------------------------------------------------------------
  // Primary colors
  // ---------------------------------------------------------------------------

  /// Main brand color used for primary actions, active states, and key highlights.
  Color get primary;

  /// Darker variation of the main brand color.
  /// Useful for stronger emphasis or custom manual usage.
  Color get primaryDark;

  /// Lighter variation of the main brand color.
  /// Useful for soft backgrounds or containers.
  Color get primaryLight;

  /// Text/icon color displayed on top of the primary color.
  Color get onPrimary;

  // ---------------------------------------------------------------------------
  // Secondary colors
  // ---------------------------------------------------------------------------

  /// Secondary brand color used for supporting accents and secondary actions.
  Color get secondary;

  /// Darker variation of the secondary color.
  Color get secondaryDark;

  /// Lighter variation of the secondary color.
  Color get secondaryLight;

  /// Text/icon color displayed on top of the secondary color.
  Color get onSecondary;

  // ---------------------------------------------------------------------------
  // Surface colors
  // ---------------------------------------------------------------------------

  /// App base background color.
  Color get surface;

  /// Main text/icon color placed on surface.
  Color get onSurface;

  /// Background color for cards, sheets, and low-emphasis surfaces.
  Color get surfaceContainer;

  /// Stronger surface layer for elevated or more prominent sections.
  Color get surfaceVariant;

  /// Secondary text/icon color used on surfaces.
  Color get onSurfaceVariant;

  // ---------------------------------------------------------------------------
  // Semantic colors
  // ---------------------------------------------------------------------------

  /// Error / destructive color.
  Color get error;

  /// Success color.
  Color get success;

  /// Warning color.
  Color get warning;

  /// Informational color.
  Color get info;

  /// Text/icon color displayed on top of error color.
  Color get onError;

  /// Text/icon color displayed on top of success color.
  Color get onSuccess;

  /// Text/icon color displayed on top of warning color.
  Color get onWarning;

  /// Text/icon color displayed on top of info color.
  Color get onInfo;

  // ---------------------------------------------------------------------------
  // Extended colors
  // ---------------------------------------------------------------------------

  /// Strong outline/border color.
  Color get outline;

  /// Softer outline/divider color.
  Color get outlineVariant;

  /// Primary color variant shown on top of inverse surfaces.
  Color get inversePrimary;

  /// Surface color that contrasts with the main surface.
  Color get inverseSurface;

  /// Text/icon color placed on inverse surface.
  Color get onInverseSurface;

  /// Overlay / modal dim background color.
  Color get scrim;

  /// Convert current color set into a Material 3 ColorScheme.
  ColorScheme toColorScheme();

  @override
  List<Object?> get props => [
    primary,
    primaryDark,
    primaryLight,
    onPrimary,
    secondary,
    secondaryDark,
    secondaryLight,
    onSecondary,
    surface,
    onSurface,
    surfaceContainer,
    surfaceVariant,
    onSurfaceVariant,
    error,
    success,
    warning,
    info,
    onError,
    onSuccess,
    onWarning,
    onInfo,
    outline,
    outlineVariant,
    inversePrimary,
    inverseSurface,
    onInverseSurface,
    scrim,
  ];
}

/// Small utility helpers to derive lighter/darker tonal variations.
extension ColorExtension on Color {
  Color darker([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  Color lighter([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}
/// Small color helpers to derive shades/tints consistently.
extension ColorX on Color {
  Color darken([double amount = .1]) {
    final hsl = HSLColor.fromColor(this);
    final l = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }

  Color lighten([double amount = .1]) {
    final hsl = HSLColor.fromColor(this);
    final l = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }

  Color saturate([double amount = .1]) {
    final hsl = HSLColor.fromColor(this);
    final s = (hsl.saturation + amount).clamp(0.0, 1.0);
    return hsl.withSaturation(s).toColor();
  }

  Color blend(Color other, double t) {
    final tt = t.clamp(0.0, 1.0);
    final a = (alpha + (other.alpha - alpha) * tt).round();
    final r = (red + (other.red - red) * tt).round();
    final g = (green + (other.green - green) * tt).round();
    final b = (blue + (other.blue - blue) * tt).round();
    return Color.fromARGB(a, r, g, b);
  }

  Color onColor() => computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

@immutable
class Tone {
  final Color bg;
  final Color fg;
  const Tone({required this.bg, required this.fg});

  factory Tone.light(Color base) {
    var bg = base.blend(Colors.white, 0.84).saturate(0.06);
    final fg = base.darken(0.12).saturate();

    if (bg.computeLuminance() > 0.96) {
      bg = base.blend(Colors.white, 0.78).saturate(0.08);
    }

    return Tone(bg: bg, fg: fg);
  }

  factory Tone.dark(Color base) {
    final bg = base.darken(0.45).saturate(0.06);
    final fg = base.lighten(0.35).saturate(0.06);
    return Tone(bg: bg, fg: fg);
  }
}
