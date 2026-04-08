part of 'theme_bloc.dart';

sealed class ThemeEvent extends Equatable {
  const ThemeEvent();

  @override
  List<Object?> get props => [];
}

// Event to initialize theme settings from storage
class ThemeInitialize extends ThemeEvent {
  const ThemeInitialize();
}

// Event to change theme mode (light, dark, system)
class ThemeModeChanged extends ThemeEvent {
  final ThemeMode themeMode;

  const ThemeModeChanged(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}

// Event to change typography font
class TypographyFontChanged extends ThemeEvent {
  final AppTypographyFont typography;

  const TypographyFontChanged(this.typography);

  @override
  List<Object?> get props => [typography];
}

// Event to change font size scale factor
class FontSizeScaleFactorChanged extends ThemeEvent {
  final double scaleFactor;

  const FontSizeScaleFactorChanged(this.scaleFactor);

  @override
  List<Object?> get props => [scaleFactor];
}

// Event to change Theme mode(light, dark, system) and typography font
class ThemeModeAndFontChanged extends ThemeEvent {
  final ThemeMode themeMode;
  final AppTypographyFont typography;

  const ThemeModeAndFontChanged(this.themeMode, this.typography);

  @override
  List<Object?> get props => [themeMode, typography];
}

// Reset all theme settings to defaults
class ThemeReset extends ThemeEvent {
  const ThemeReset();
}
