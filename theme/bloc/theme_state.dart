part of 'theme_bloc.dart';

enum ThemeStatus { initial, loading, loaded, error }

class ThemeState extends Equatable {
  final ThemeStatus status;
  final ThemeMode themeMode;
  final AppTypographyFont typographyFont;
  final double fontSizeScaleFactor;
  final String? errorMessage;
  final ThemeData? lightThemeData;
  final ThemeData? darkThemeData;

  const ThemeState({
    this.status = ThemeStatus.initial,
    this.themeMode = ThemeMode.system,
    this.typographyFont = AppTypographyFont.appDefault,
    this.fontSizeScaleFactor = 1.0,
    this.errorMessage,
    this.lightThemeData,
    this.darkThemeData,
  });

  // Create a copy of this state with optional new values
  ThemeState copyWith({
    ThemeStatus? status,
    ThemeMode? themeMode,
    AppTypographyFont? typographyFont,
    double? fontSizeScaleFactor,
    String? errorMessage,
    bool clearError = false,
    ThemeData? lightThemeData,
    ThemeData? darkThemeData,
  }) {
    return ThemeState(
      status: status ?? this.status,
      themeMode: themeMode ?? this.themeMode,
      typographyFont: typographyFont ?? this.typographyFont,
      fontSizeScaleFactor: fontSizeScaleFactor ?? this.fontSizeScaleFactor,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      lightThemeData: lightThemeData ?? this.lightThemeData,
      darkThemeData: darkThemeData ?? this.darkThemeData,
    );
  }

  // Create theme data for a specific brightness from the current settings.
  ThemeData createThemeData({required Brightness brightness}) =>
      AppTheme.create(
        brightness: brightness,
        typography: typographyFont,
        fontSizeScaleFactor: fontSizeScaleFactor,
      ).build();

  @override
  List<Object?> get props => [
    status,
    themeMode,
    typographyFont,
    fontSizeScaleFactor,
    lightThemeData,
    darkThemeData,
    errorMessage,
  ];
}
