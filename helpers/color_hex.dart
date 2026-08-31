import 'dart:ui';

/// Conversions between a [Color] and the hex strings the API speaks
/// (e.g. a label color arrives as `"#3B82F6"`).
///
/// Both directions are total: parsing never throws, it falls back, because a
/// malformed color from the server must never take a screen down.
extension HexColorString on String {
  /// Fallback used when the string is not a usable hex color (slate-500).
  static const Color fallbackColor = Color(0xFF64748B);

  /// Parses `RGB`, `RRGGBB` or `AARRGGBB`, with or without a leading `#`.
  /// Returns `null` when the string is not a valid hex color.
  Color? tryToHexColor() {
    var hex = trim().replaceAll('#', '').replaceAll(' ', '');
    if (hex.length == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;

    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(value);
  }

  /// Same as [tryToHexColor] but always yields a color.
  Color toHexColor({Color fallback = fallbackColor}) =>
      tryToHexColor() ?? fallback;
}

extension ColorToHex on Color {
  /// `#RRGGBB` — the shape the API expects back. Alpha is dropped on purpose:
  /// the API stores opaque brand colors only.
  String toHex() {
    final rgb = toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
