import 'package:geocoding/geocoding.dart';
import 'package:idara_tracking_app/core/util/app_log.dart';
import 'package:injectable/injectable.dart';

/// Turns coordinates into a street address.
@lazySingleton
class ReverseGeocoder {
  ReverseGeocoder();

  final Map<String, String?> _cache = {};
  static const int _keyPrecision = 4;
  Future<String?> lookup(double latitude, double longitude) async {
    final key =
        '${latitude.toStringAsFixed(_keyPrecision)},'
        '${longitude.toStringAsFixed(_keyPrecision)}';

    if (_cache.containsKey(key)) return _cache[key];

    try {
      final places = await placemarkFromCoordinates(latitude, longitude);
      final address = places.isEmpty ? null : _format(places.first);
      _cache[key] = address;
      return address;
    } on Exception catch (error) {
      AppLog.w('[ReverseGeocoder] $key failed: $error');
      return null;
    }
  }

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

  static String? _clean(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    if (text.length < 2) return null;
    return text;
  }
}
