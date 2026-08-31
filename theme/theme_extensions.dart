import 'package:flutter/material.dart';
import 'package:idara_esign/config/theme/app_colors.dart';

extension ThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);

  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get textTheme => Theme.of(this).textTheme;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get primaryColor => Theme.of(this).colorScheme.primary;
  Color get secondaryColor => Theme.of(this).colorScheme.secondary;
  Color get backgroundColor => Theme.of(this).scaffoldBackgroundColor;
  Color get surfaceColor => Theme.of(this).colorScheme.surface;
  Color get onSurfaceColor => Theme.of(this).colorScheme.onSurface;
  Color get errorColor => Theme.of(this).colorScheme.error;

  Color get textPrimaryColor => Theme.of(this).colorScheme.onSurface;
  Color get textSecondaryColor => Theme.of(this).colorScheme.onSurfaceVariant;

  Color get borderColor => Theme.of(this).colorScheme.outline;

  Tone toneForStatusBase(Color base) =>
      isDarkMode ? Tone.dark(base) : Tone.light(base);

  Tone get successTone =>
      isDarkMode ? AppColors.successToneDark : AppColors.successToneLight;
  Tone get warningTone =>
      isDarkMode ? AppColors.warningToneDark : AppColors.warningToneLight;
  Tone get errorTone =>
      isDarkMode ? AppColors.errorToneDark : AppColors.errorToneLight;
  Tone get infoTone =>
      isDarkMode ? AppColors.infoToneDark : AppColors.infoToneLight;
  Tone get neutralTone => isDarkMode
      ? Tone.dark(Colors.blueGrey)
      : Tone.light(Colors.blueGrey); // or choose your own neutral base
  Tone get primaryTone =>
      isDarkMode ? AppColors.primaryToneDark : AppColors.primaryToneLight;
}
