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
