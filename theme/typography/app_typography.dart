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
  /// Primary font family for Latin text.
  static const String primaryFontFamily = 'DINPro';

  /// Arabic glyphs fallback when the primary family does not contain them.
  static const List<String> defaultFontFamilyFallback = ['DINNextArabic'];

  const AppTypography({
    String fontFamily = primaryFontFamily,
    List<String> fontFamilyFallback = defaultFontFamilyFallback,
    double fontSizeScaleFactor = 1.0,
  }) : super(
         fontFamily,
         fontFamilyFallback: fontFamilyFallback,
         fontSizeScaleFactor: fontSizeScaleFactor,
       );

  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  /// Splits line leading evenly above and below the glyphs.
  ///
  /// **Required for this font.** DIN Next Arabic reserves room above the
  /// baseline for Arabic diacritics, giving it very lopsided metrics:
  ///
  /// ```
  /// ascent 1.200 em   descent 0.270 em   →  ascent is 81.6% of the box
  /// (a Latin-only face is nearer 50–60%)
  /// ```
  ///
  /// Flutter's default, [TextLeadingDistribution.proportional], hands out the
  /// extra line height in that same 82/18 ratio. Latin text carries nothing in
  /// the diacritic zone, so almost all the slack lands *above* the letters and
  /// they sit low in their box — visibly off-centre inside a button, while an
  /// [Icon] beside them looks fine because its glyph box is symmetric.
  ///
  /// `even` ignores the font's ratio and halves the leading, which centres the
  /// glyphs. Applied on the base style so every widget inherits it.
  /// use in materialApp
  ///             builder: (context, child) {
  //   // Backstop for the same problem AppTypography solves: DIN Next
  //   // Arabic reserves 82% of its line box above the baseline for
  //   // diacritics, so proportional leading pushes Latin text low.
  //   // The typography covers anything styled from our theme; this
  //   // catches text that builds its own TextStyle.
  //   return DefaultTextHeightBehavior(
  //     textHeightBehavior: const TextHeightBehavior(
  //       leadingDistribution: AppTypography.leadingDistribution,
  //     ),
  //     child: child ?? const SizedBox.shrink(),
  //   );
  // },
  static const TextLeadingDistribution leadingDistribution =
      TextLeadingDistribution.even;

  /// How far glyphs sit below the optical centre of their line box, as a
  /// fraction of the font size.
  ///
  /// [leadingDistribution] fixes how *leading* is shared out, but not the
  /// asymmetry of the font's own content box, which is what actually
  /// mispositions the glyphs:
  ///
  /// ```
  /// hhea  ascent 1.200 em   descent 0.270 em
  /// box centre = (ascent − descent) / 2 = 0.465 em above the baseline
  /// ```
  ///
  /// Centring that box puts the baseline 0.465 em below the container's
  /// middle. But Latin glyphs occupy roughly cap-height 0.70 em down to
  /// descender −0.20 em, so their optical centre is only ~0.25 em above the
  /// baseline — which is exactly what the designer declared in OS/2
  /// (`typoAscender 0.75`, `typoDescender −0.25` → centre 0.25 em).
  ///
  /// The gap, `0.465 − 0.25`, is how far the text drops. Arabic UI text is in
  /// the same position: the 1.2 em ascent is reserved for stacked diacritics
  /// that ordinary labels do not carry, so the correction suits both scripts
  /// and is applied unconditionally.
  ///
  /// Only matters where text is centred in a fixed-height box — buttons,
  /// chips, badges. In flowing text the box sits wherever it lands.
  static const double opticalCentreOffsetEm = 0.215;

  // Create base style with the specified font family
  @override
  TextStyle createBaseStyle() {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      letterSpacing: 0.15,
      fontWeight: FontWeight.normal,
      height: 1.25,
      leadingDistribution: leadingDistribution,
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
      fontFamilyFallback: fontFamilyFallback,
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
