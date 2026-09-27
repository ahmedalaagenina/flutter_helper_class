import 'dart:ui' show TextDirection;

import 'package:intl/intl.dart' as intl;

extension CapExtension on String {
  String get capitalizeFirst => '${this[0].toUpperCase()}${substring(1)}';

  String get allInCapitalize => toUpperCase();

  String get capitalizeFirstOfEach =>
      split(' ').map((str) => str.capitalizeFirst).join(' ');
}

extension ValidatedString on String? {
  bool get isNotNull {
    return this != null;
  }
}

extension StringExtensions on String {
  TextDirection get textDirection => intl.Bidi.detectRtlDirectionality(this)
      ? TextDirection.rtl
      : TextDirection.ltr;

  String removeWhitespace() {
    return replaceAll(' ', '');
  }

  bool isPasswordEasy() {
    return length < 8 || length > 20;
  }

  bool isFullNameEn() {
    return RegExp(r'^[A-Za-z]+(?:\s[A-Za-z]+)+$').hasMatch(this);
  }

  bool isEmail() {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(this);
  }
}
