import 'package:flutter/material.dart';
import 'package:typo_color_them/theme/typography/typography.dart';

/// we can create a typography class that extends the base typography class
/// and implements the required methods for different text styles.

/// It allows you to create a typography instance with a specific font family
/// and provides methods to get text styles for different text types.

/// also we can create different typography classes for different font families
class DefaultTypography extends BaseTypography {
  const DefaultTypography({
    String? fontFamily,
    double fontSizeScaleFactor = 1.0,
  }) : super(fontFamily, fontSizeScaleFactor: fontSizeScaleFactor);

  // Create base style with the specified font family
  @override
  TextStyle createBaseStyle() {
    return TextStyle(
      fontFamily: fontFamily,
      letterSpacing: 0.15,
      fontWeight: FontWeight.normal,
      height: 1.25, // Improved line height
    );
  }

  // Use the base style for all typography elements
  TextStyle get _baseStyle => createBaseStyle();

  // Display styles (h1-h3)
  @override
  TextStyle get displayLarge => _baseStyle.copyWith(
    fontSize: 96 * fontSizeScaleFactor,
    fontWeight: FontWeight.w300,
    letterSpacing: -1.5,
    height: 1.2,
  );

  @override
  TextStyle get displayMedium => _baseStyle.copyWith(
    fontSize: 60 * fontSizeScaleFactor,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.5,
    height: 1.2,
  );

  @override
  TextStyle get displaySmall => _baseStyle.copyWith(
    fontSize: 48 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0,
    height: 1.2,
  );

  // Headline styles (h4-h6)
  @override
  TextStyle get headlineLarge => _baseStyle.copyWith(
    fontSize: 34 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.25,
  );

  @override
  TextStyle get headlineMedium => _baseStyle.copyWith(
    fontSize: 24 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0,
  );

  @override
  TextStyle get headlineSmall => _baseStyle.copyWith(
    fontSize: 20 * fontSizeScaleFactor,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
  );

  // Title styles
  @override
  TextStyle get titleLarge => _baseStyle.copyWith(
    fontSize: 16 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.15,
  );

  @override
  TextStyle get titleMedium => _baseStyle.copyWith(
    fontSize: 14 * fontSizeScaleFactor,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  @override
  TextStyle get titleSmall => _baseStyle.copyWith(
    fontSize: 12 * fontSizeScaleFactor,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  // Body styles
  @override
  TextStyle get bodyLarge => _baseStyle.copyWith(
    fontSize: 16 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.5,
  );

  @override
  TextStyle get bodyMedium => _baseStyle.copyWith(
    fontSize: 14 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.25,
  );

  @override
  TextStyle get bodySmall => _baseStyle.copyWith(
    fontSize: 12 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.4,
  );

  // Label styles
  @override
  TextStyle get labelLarge => _baseStyle.copyWith(
    fontSize: 14 * fontSizeScaleFactor,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.25,
  );

  @override
  TextStyle get labelMedium => _baseStyle.copyWith(
    fontSize: 12 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.4,
  );

  @override
  TextStyle get labelSmall => _baseStyle.copyWith(
    fontSize: 10 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 1.5,
  );

  @override
  BaseTypography withFontSizeScaleFactor(double scaleFactor) {
    return DefaultTypography(
      fontFamily: fontFamily,
      fontSizeScaleFactor: scaleFactor,
    );
  }
}

class AppTypography extends BaseTypography {
  const AppTypography({
    String fontFamily = 'Roboto',
    double fontSizeScaleFactor = 1.0,
  }) : super(fontFamily, fontSizeScaleFactor: fontSizeScaleFactor);

  // Create base style with the specified font family
  @override
  TextStyle createBaseStyle() {
    return TextStyle(
      fontFamily: fontFamily,
      letterSpacing: 0.15,
      fontWeight: FontWeight.normal,
      height: 1.25, // Improved line height
    );
  }

  // Use the base style for all typography elements
  TextStyle get _baseStyle => createBaseStyle();

  // Display styles (h1-h3)
  @override
  TextStyle get displayLarge => _baseStyle.copyWith(
    fontSize: 96 * fontSizeScaleFactor,
    fontWeight: FontWeight.w300,
    letterSpacing: -1.5,
    height: 1.2,
  );

  @override
  TextStyle get displayMedium => _baseStyle.copyWith(
    fontSize: 60 * fontSizeScaleFactor,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.5,
    height: 1.2,
  );

  @override
  TextStyle get displaySmall => _baseStyle.copyWith(
    fontSize: 48 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0,
    height: 1.2,
  );

  // Headline styles (h4-h6)
  @override
  TextStyle get headlineLarge => _baseStyle.copyWith(
    fontSize: 34 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.25,
  );

  @override
  TextStyle get headlineMedium => _baseStyle.copyWith(
    fontSize: 24 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0,
  );

  @override
  TextStyle get headlineSmall => _baseStyle.copyWith(
    fontSize: 20 * fontSizeScaleFactor,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
  );

  // Title styles
  @override
  TextStyle get titleLarge => _baseStyle.copyWith(
    fontSize: 16 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.15,
  );

  @override
  TextStyle get titleMedium => _baseStyle.copyWith(
    fontSize: 14 * fontSizeScaleFactor,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  @override
  TextStyle get titleSmall => _baseStyle.copyWith(
    fontSize: 12 * fontSizeScaleFactor,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  // Body styles
  @override
  TextStyle get bodyLarge => _baseStyle.copyWith(
    fontSize: 16 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.5,
  );

  @override
  TextStyle get bodyMedium => _baseStyle.copyWith(
    fontSize: 14 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.25,
  );

  @override
  TextStyle get bodySmall => _baseStyle.copyWith(
    fontSize: 12 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.4,
  );

  // Label styles
  @override
  TextStyle get labelLarge => _baseStyle.copyWith(
    fontSize: 14 * fontSizeScaleFactor,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.25,
  );

  @override
  TextStyle get labelMedium => _baseStyle.copyWith(
    fontSize: 12 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.4,
  );

  @override
  TextStyle get labelSmall => _baseStyle.copyWith(
    fontSize: 10 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 1.5,
  );

  @override
  BaseTypography withFontSizeScaleFactor(double scaleFactor) {
    return AppTypography(
      fontFamily: fontFamily,
      fontSizeScaleFactor: scaleFactor,
    );
  }
}

class ArabicTypography extends BaseTypography {
  const ArabicTypography({double fontSizeScaleFactor = 1.0})
    : super('Cairo', fontSizeScaleFactor: fontSizeScaleFactor);

  // Create base style with Cairo font and RTL text direction
  @override
  TextStyle createBaseStyle() {
    return TextStyle(
      fontFamily: fontFamily,
      letterSpacing: 0.15,
      fontWeight: FontWeight.normal,
      height: 1.4, // Adjusted height for Arabic script
      textBaseline: TextBaseline.alphabetic,
    );
  }

  // Use the base style for all typography elements
  TextStyle get _baseStyle => createBaseStyle();

  // Display styles with adjustments for Arabic script
  @override
  TextStyle get displayLarge => _baseStyle.copyWith(
    fontSize: 96 * fontSizeScaleFactor,
    fontWeight: FontWeight.w300,
    letterSpacing: -1.0, // Less letter spacing for Arabic
    height: 1.3,
  );

  @override
  TextStyle get displayMedium => _baseStyle.copyWith(
    fontSize: 60 * fontSizeScaleFactor,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.25,
    height: 1.3,
  );

  @override
  TextStyle get displaySmall => _baseStyle.copyWith(
    fontSize: 48 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0,
    height: 1.3,
  );

  // Headline styles
  @override
  TextStyle get headlineLarge => _baseStyle.copyWith(
    fontSize: 34 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.1, // Reduced for Arabic
  );

  @override
  TextStyle get headlineMedium => _baseStyle.copyWith(
    fontSize: 24 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0,
  );

  @override
  TextStyle get headlineSmall => _baseStyle.copyWith(
    fontSize: 20 * fontSizeScaleFactor,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1, // Reduced for Arabic
  );

  // Title styles
  @override
  TextStyle get titleLarge => _baseStyle.copyWith(
    fontSize: 16 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.1, // Reduced for Arabic
  );

  @override
  TextStyle get titleMedium => _baseStyle.copyWith(
    fontSize: 14 * fontSizeScaleFactor,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.05, // Reduced for Arabic
  );

  @override
  TextStyle get titleSmall => _baseStyle.copyWith(
    fontSize: 12 * fontSizeScaleFactor,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.05, // Reduced for Arabic
  );

  // Body styles
  @override
  TextStyle get bodyLarge => _baseStyle.copyWith(
    fontSize: 16 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.25, // Reduced for Arabic
  );

  @override
  TextStyle get bodyMedium => _baseStyle.copyWith(
    fontSize: 14 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.15, // Reduced for Arabic
  );

  @override
  TextStyle get bodySmall => _baseStyle.copyWith(
    fontSize: 12 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.2, // Reduced for Arabic
  );

  // Label styles
  @override
  TextStyle get labelLarge => _baseStyle.copyWith(
    fontSize: 14 * fontSizeScaleFactor,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.7, // Reduced for Arabic
  );

  @override
  TextStyle get labelMedium => _baseStyle.copyWith(
    fontSize: 12 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.2, // Reduced for Arabic
  );

  @override
  TextStyle get labelSmall => _baseStyle.copyWith(
    fontSize: 10 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.8, // Reduced for Arabic
  );

  @override
  BaseTypography withFontSizeScaleFactor(double scaleFactor) {
    return ArabicTypography(fontSizeScaleFactor: scaleFactor);
  }
}

class EnglishTypography extends BaseTypography {
  const EnglishTypography({double fontSizeScaleFactor = 1.0})
    : super('Roboto', fontSizeScaleFactor: fontSizeScaleFactor);

  // Create base style with Roboto font
  @override
  TextStyle createBaseStyle() {
    return TextStyle(
      fontFamily: fontFamily,
      letterSpacing: 0.15,
      fontWeight: FontWeight.normal,
      height: 1.25,
      textBaseline: TextBaseline.alphabetic,
    );
  }

  // Use the base style for all typography elements
  TextStyle get _baseStyle => createBaseStyle();

  // Display styles
  @override
  TextStyle get displayLarge => _baseStyle.copyWith(
    fontSize: 96 * fontSizeScaleFactor,
    fontWeight: FontWeight.w300,
    letterSpacing: -1.5,
    height: 1.2,
  );

  @override
  TextStyle get displayMedium => _baseStyle.copyWith(
    fontSize: 60 * fontSizeScaleFactor,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.5,
    height: 1.2,
  );

  @override
  TextStyle get displaySmall => _baseStyle.copyWith(
    fontSize: 48 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0,
    height: 1.2,
  );

  // Headline styles
  @override
  TextStyle get headlineLarge => _baseStyle.copyWith(
    fontSize: 34 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.25,
  );

  @override
  TextStyle get headlineMedium => _baseStyle.copyWith(
    fontSize: 24 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0,
  );

  @override
  TextStyle get headlineSmall => _baseStyle.copyWith(
    fontSize: 20 * fontSizeScaleFactor,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
  );

  // Title styles
  @override
  TextStyle get titleLarge => _baseStyle.copyWith(
    fontSize: 16 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.15,
  );

  @override
  TextStyle get titleMedium => _baseStyle.copyWith(
    fontSize: 14 * fontSizeScaleFactor,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  @override
  TextStyle get titleSmall => _baseStyle.copyWith(
    fontSize: 12 * fontSizeScaleFactor,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  // Body styles
  @override
  TextStyle get bodyLarge => _baseStyle.copyWith(
    fontSize: 16 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.5,
  );

  @override
  TextStyle get bodyMedium => _baseStyle.copyWith(
    fontSize: 14 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.25,
  );

  @override
  TextStyle get bodySmall => _baseStyle.copyWith(
    fontSize: 12 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.4,
  );

  // Label styles
  @override
  TextStyle get labelLarge => _baseStyle.copyWith(
    fontSize: 14 * fontSizeScaleFactor,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.25,
  );

  @override
  TextStyle get labelMedium => _baseStyle.copyWith(
    fontSize: 12 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.4,
  );

  @override
  TextStyle get labelSmall => _baseStyle.copyWith(
    fontSize: 10 * fontSizeScaleFactor,
    fontWeight: FontWeight.normal,
    letterSpacing: 1.5,
  );

  @override
  BaseTypography withFontSizeScaleFactor(double scaleFactor) {
    return EnglishTypography(fontSizeScaleFactor: scaleFactor);
  }
}
