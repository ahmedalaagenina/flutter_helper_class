import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:typo_color_them/theme/theme.dart';

/// Extension for easy access to app theme
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final BaseTypography typography;
  final BaseColors colors;
  final EdgeInsetsGeometry screenPadding;
  final BorderRadius borderRadius;
  final Duration animationDuration;

  const AppThemeExtension({
    required this.typography,
    required this.colors,
    this.screenPadding = const EdgeInsets.all(16.0),
    this.borderRadius = const BorderRadius.all(Radius.circular(8.0)),
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  AppThemeExtension copyWith({
    BaseTypography? typography,
    BaseColors? colors,
    EdgeInsetsGeometry? screenPadding,
    BorderRadius? borderRadius,
    Duration? animationDuration,
  }) {
    return AppThemeExtension(
      typography: typography ?? this.typography,
      colors: colors ?? this.colors,
      screenPadding: screenPadding ?? this.screenPadding,
      borderRadius: borderRadius ?? this.borderRadius,
      animationDuration: animationDuration ?? this.animationDuration,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(
    covariant ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) {
      return this;
    }

    // Proper lerping implementation
    return AppThemeExtension(
      typography: t < 0.5 ? typography : other.typography,
      colors: colors, // Colors will be handled by ColorScheme lerp
      screenPadding: EdgeInsetsGeometry.lerp(
        screenPadding,
        other.screenPadding,
        t,
      )!,
      borderRadius: BorderRadius.lerp(borderRadius, other.borderRadius, t)!,
      animationDuration: lerpDuration(
        animationDuration,
        other.animationDuration,
        t,
      ),
    );
  }

  /// Helper method to lerp between durations
  Duration lerpDuration(Duration a, Duration b, double t) {
    return Duration(
      milliseconds:
          (a.inMilliseconds + (b.inMilliseconds - a.inMilliseconds) * t)
              .round(),
    );
  }
}

/// Extension for easy access to app theme from BuildContext
extension ThemeContextExtension on BuildContext {
  // Get the theme state
  ThemeState get themeState => read<ThemeBloc>().state;

  // Get the theme BLoC
  ThemeBloc get themeBloc => read<ThemeBloc>();
  ThemeData get theme => Theme.of(this);

  // Get the app theme extension from the current theme
  AppThemeExtension get appTheme {
    final ext = Theme.of(this).extension<AppThemeExtension>();
    assert(ext != null, 'AppThemeExtension is not found in ThemeData.');
    return ext!;
  }

  // Get the typography directly
  BaseTypography get typography => appTheme.typography;

  // Get colors directly
  BaseColors get colors => appTheme.colors;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  // Get common values from the theme extension
  EdgeInsetsGeometry get screenPadding => appTheme.screenPadding;
  BorderRadius get borderRadius => appTheme.borderRadius;
  Duration get animationDuration => appTheme.animationDuration;

  // Get current brightness
  Brightness get brightness => Theme.of(this).brightness;
  bool get isDarkMode => brightness == Brightness.dark;

  /// local
  // Get locale
  LocaleState get localeState => read<LocaleCubit>().state;
  // Get the locale BLoC
  LocaleCubit get localeBloc => read<LocaleCubit>();

  bool get isArabic => localeState.locale.languageCode == 'ar';
  bool get isEnglish => localeState.locale.languageCode == 'en';
  String get currentLanguageCode => localeState.locale.languageCode;
}
