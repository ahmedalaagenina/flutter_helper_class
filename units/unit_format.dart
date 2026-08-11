import 'package:flutter/widgets.dart';
import 'package:idara_tracking_app/generated/l10n.dart';

abstract final class UnitFormat {
  static String distance(BuildContext context, double value, String? unit) {
    final text = switch (value.abs()) {
      < 1 => value.toStringAsFixed(2),
      < 100 => value.toStringAsFixed(1),
      _ => value.round().toString(),
    };

    return _label(context, text, unit) ?? S.of(context).distanceKm(text);
  }

  static String speed(BuildContext context, double value, String? unit) {
    final text = value.round().toString();

    return _label(context, text, unit) ?? S.of(context).speedKph(text);
  }

  static String altitude(BuildContext context, double value, String? unit) {
    final text = value.round().toString();

    return _label(context, text, unit) ?? S.of(context).altitudeMetres(text);
  }

  static String volume(BuildContext context, double value, String? unit) {
    final text = value.abs() < 10
        ? value.toStringAsFixed(2)
        : value.toStringAsFixed(1);

    return _label(context, text, unit) ?? S.of(context).volumeLitres(text);
  }

  static String? _label(BuildContext context, String value, String? unit) =>
      unit == null ? null : S.of(context).measurement(value, unit);
}
