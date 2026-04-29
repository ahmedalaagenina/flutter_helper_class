import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Contract for typography implementations
abstract class BaseTypography extends Equatable {
  final String? _fontFamily;
  final double fontSizeScaleFactor; // Changed to public

  const BaseTypography(this._fontFamily, {this.fontSizeScaleFactor = 1.0});

  String? get fontFamily => _fontFamily;

  // Base method to create base style - each subclass implements this
  TextStyle createBaseStyle();

  // Text styles for Material 3
  TextStyle get displayLarge; // h1
  TextStyle get displayMedium; // h2
  TextStyle get displaySmall; // h3
  TextStyle get headlineLarge; // h4
  TextStyle get headlineMedium; // h5
  TextStyle get headlineSmall; // h6

  TextStyle get titleLarge; // subtitle1
  TextStyle get titleMedium; // subtitle2
  TextStyle get titleSmall; // overline

  TextStyle get bodyLarge; // body1
  TextStyle get bodyMedium; // body2
  TextStyle get bodySmall; // body3

  TextStyle get labelLarge; // button
  TextStyle get labelMedium; // caption
  TextStyle get labelSmall; // overline small

  // Create a copy with different font size scale factor
  BaseTypography withFontSizeScaleFactor(double scaleFactor);

  @override
  List<Object?> get props => [fontFamily, fontSizeScaleFactor];
}
