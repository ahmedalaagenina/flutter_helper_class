import 'package:geocoding/geocoding.dart';
import 'package:idara_tracking_app/core/util/app_log.dart';
import 'package:injectable/injectable.dart';

/// Turns coordinates into a street address.
@lazySingleton
class ReverseGeocoder {
  ReverseGeocoder();

  Geocoding? _geocoding;

  bool _isUnavailable = false;

  Geocoding? get _service {
    if (_isUnavailable) return null;

    try {
      return _geocoding ??= Geocoding();
    } on Object catch (error) {
      _isUnavailable = true;
      AppLog.w('[ReverseGeocoder] platform unavailable — $error');
      return null;
    }
  }

  final Map<String, String?> _cache = {};
  static const int _keyPrecision = 4;
  static const Duration _timeout = Duration(seconds: 8);

  Future<String?> lookup(double latitude, double longitude) async {
    final key =
        '${latitude.toStringAsFixed(_keyPrecision)},'
        '${longitude.toStringAsFixed(_keyPrecision)}';

    if (_cache.containsKey(key)) return _cache[key];

    final service = _service;
    if (service == null) return null;

    try {
      final places = await service
          .placemarkFromCoordinates(latitude, longitude)
          .timeout(_timeout);

      final address = places.isEmpty ? null : _format(places.first);

      _cache[key] = address;
      return address;
    } on Object catch (error) {
      AppLog.w('[ReverseGeocoder] $key failed: $error');
      return null;
    }
  }

  static bool isHumanReadable(String? value) {
    final text = value?.trim();
    if (text == null || text.length < 2 || text == '-') return false;
    return _letter.hasMatch(text);
  }

  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);

  static String? _format(Placemark place) {
    final parts = <String>[
      ?_clean(place.name),
      ?_clean(place.thoroughfare),
      ?_clean(place.subLocality),
      ?_clean(place.locality),
      ?_clean(place.administrativeArea),
      ?_clean(place.country),
    ];

    final unique = <String>[];
    for (final part in parts) {
      if (!unique.contains(part)) unique.add(part);
    }

    if (unique.isEmpty) return null;

    return unique.take(4).join(', ');
  }

  static String? _clean(String? value) =>
      isHumanReadable(value) ? value!.trim() : null;
}
