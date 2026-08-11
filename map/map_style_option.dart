import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:idara_tracking_app/core/util/app_log.dart';

enum MapStyleOption {
  auto(MapType.normal, null),

  normal(MapType.normal, null),
  satellite(MapType.satellite, null),
  terrain(MapType.terrain, null),
  hybrid(MapType.hybrid, null),

  grayscale(MapType.normal, 'assets/map/subtle_grayscale.json'),
  ultraLight(MapType.normal, 'assets/map/ultra_light_with_labels.json'),
  midnight(MapType.normal, 'assets/map/assassins_creed_IV.json');

  const MapStyleOption(this.mapType, this.assetPath);
  final MapType mapType;
  final String? assetPath;

  static const String _darkAsset = 'assets/map/map_style_dark.json';
  static const String _lightAsset = 'assets/map/map_style_light.json';
  String? resolveAsset(Brightness brightness) => this == MapStyleOption.auto
      ? (brightness == Brightness.dark ? _darkAsset : _lightAsset)
      : assetPath;

  /// Whether a style can affect this option at all.
  bool get supportsStyling => mapType == MapType.normal;
}

/// Entries appended to whatever stylesheet an option already declares, so that
/// "show all map info" means the same thing on all eight of them.
///
/// A Google stylesheet is a list applied in order and the later entry wins, so
/// one overlay can flip places, transit and pin icons on or off across every
/// base style without any of them being edited — and without a second copy of
/// each JSON file being shipped.
abstract final class MapDetailOverlay {
  /// Everything Google knows about: places, transit and their labels.
  static const List<Map<String, Object>> shown = [
    {
      'featureType': 'poi',
      'stylers': [
        {'visibility': 'on'},
      ],
    },
    {
      'featureType': 'transit',
      'stylers': [
        {'visibility': 'on'},
      ],
    },
    {
      'elementType': 'labels',
      'stylers': [
        {'visibility': 'on'},
      ],
    },
    {
      'elementType': 'labels.text',
      'stylers': [
        {'visibility': 'on'},
      ],
    },
    // Named explicitly because a style may have hidden the fill rather than the
    // label, which a broader `labels` rule does not necessarily undo.
    {
      'elementType': 'labels.text.fill',
      'stylers': [
        {'visibility': 'on'},
      ],
    },
    {
      'elementType': 'labels.icon',
      'stylers': [
        {'visibility': 'on'},
      ],
    },
  ];

  /// The uncluttered map: no shops, no transit, no pins.
  ///
  /// Road and place *names* deliberately stay — an operator reading a live map
  /// still needs to know which street a vehicle is on. Park geometry stays too,
  /// so the map does not lose its green when the POI layer goes.
  static const List<Map<String, Object>> hidden = [
    {
      'featureType': 'poi',
      'stylers': [
        {'visibility': 'off'},
      ],
    },
    {
      'featureType': 'poi.park',
      'elementType': 'geometry',
      'stylers': [
        {'visibility': 'on'},
      ],
    },
    {
      'featureType': 'transit',
      'stylers': [
        {'visibility': 'off'},
      ],
    },
    {
      'elementType': 'labels.icon',
      'stylers': [
        {'visibility': 'off'},
      ],
    },
  ];
}

abstract final class MapStyleLoader {
  /// Composed stylesheets, keyed by asset and detail setting. At most two
  /// entries per style, and each is built once.
  static final Map<String, String> _cache = {};

  /// The cache key for the plain Google map, which has no asset of its own but
  /// still carries the detail overlay.
  static const String _plainKey = 'plain';

  /// The stylesheet for [option], with the detail overlay applied.
  ///
  /// Returns null for satellite, hybrid and terrain: those are Google's own
  /// imagery products, and a stylesheet has no effect on them at all.
  static Future<String?> load(
    MapStyleOption option,
    Brightness brightness, {
    required bool showAllInfo,
  }) async {
    if (!option.supportsStyling) return null;

    final asset = option.resolveAsset(brightness);
    final key = '${asset ?? _plainKey}|$showAllInfo';

    final cached = _cache[key];
    if (cached != null) return cached;

    final base = asset == null ? const <dynamic>[] : await _read(asset);
    final composed = jsonEncode([
      ...base,
      ...showAllInfo ? MapDetailOverlay.shown : MapDetailOverlay.hidden,
    ]);

    _cache[key] = composed;
    return composed;
  }

  static Future<List<dynamic>> _read(String asset) async {
    try {
      return jsonDecode(await rootBundle.loadString(asset)) as List<dynamic>;
    } on Object catch (error) {
      AppLog.w('[MapStyleLoader] Could not load $asset: $error');
      return const [];
    }
  }
}
