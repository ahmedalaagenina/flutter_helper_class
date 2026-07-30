import 'package:flutter/material.dart';

import 'package:idara_tracking_app/config/theme/colors/brand_palette.dart';

/// Colours that encode **device state**, not chrome.
///
/// These live in a [ThemeExtension] rather than in `BaseColors` because they
/// are domain data: they describe a vehicle, not a surface. Keeping them out
/// of the [ColorScheme] also stops them being reached for by accident — green,
/// amber and red are reserved and must never appear on a button, a heading or
/// a container.
///
/// Colour is never the only signal. Every status pairs with a distinct marker
/// shape and adjacent text, so the list stays readable for the ~1 in 12 men
/// with a colour vision deficiency — red/green being the exact axis that fails.
/// See [DeviceStatusStyle] for the shape pairing.
///
/// Usage: `context.statusColors.moving`
@immutable
class DeviceStatusColors extends ThemeExtension<DeviceStatusColors> {
  const DeviceStatusColors({
    required this.moving,
    required this.idling,
    required this.stopped,
    required this.offline,
    required this.ignitionOn,
    required this.ignitionOff,
    required this.tail,
    required this.geofenceFill,
    required this.geofenceStroke,
    required this.clusterFill,
    required this.clusterLabel,
    required this.markerChipBackground,
    required this.markerChipLabel,
  });

  /// Engine on, speed > 0.
  final Color moving;

  /// Engine on, speed 0 — idling.
  final Color idling;

  /// Engine off, still reporting.
  final Color stopped;

  /// Not reporting.
  final Color offline;

  /// The engine glyph when ignition is on.
  ///
  /// Ignition is a **separate** indicator from status: the legacy app shows a
  /// green engine next to a blue status dot (idling). Do not merge them.
  final Color ignitionOn;

  /// The engine glyph when ignition is off.
  final Color ignitionOff;

  /// Recent-track polyline drawn behind a marker ("Show tails").
  final Color tail;

  final Color geofenceFill;
  final Color geofenceStroke;

  /// Marker cluster bubble.
  final Color clusterFill;
  final Color clusterLabel;

  /// The rounded name chip above each map marker.
  final Color markerChipBackground;
  final Color markerChipLabel;

  static const DeviceStatusColors dark = DeviceStatusColors(
    moving: Color(0xFF34D77F),
    idling: Color(0xFF5B9BFF),
    stopped: Color(0xFFFBBF24),
    offline: Color(0xFFF87171),
    ignitionOn: Color(0xFF34D77F),
    ignitionOff: Color(0xFFF87171),
    tail: Color(0xB322C3E6), // cyan400 @ 70%
    geofenceFill: Color(0x2E14D3C4), // teal500 @ 18%
    geofenceStroke: BrandPalette.teal400,
    clusterFill: BrandPalette.cyan400,
    clusterLabel: BrandPalette.inkOnCyan,
    markerChipBackground: Color(0xD90B1017), // n900 @ 85%
    markerChipLabel: BrandPalette.inkOnDark,
  );

  static const DeviceStatusColors light = DeviceStatusColors(
    moving: Color(0xFF15803D),
    idling: Color(0xFF1D4ED8),
    stopped: Color(0xFFB45309),
    offline: Color(0xFFB91C1C),
    ignitionOn: Color(0xFF15803D),
    ignitionOff: Color(0xFFB91C1C),
    tail: Color(0xB3007A96), // cyan700 @ 70%
    geofenceFill: Color(0x260FB3A6), // teal600 @ 15%
    geofenceStroke: BrandPalette.teal700,
    clusterFill: BrandPalette.cyan700,
    clusterLabel: BrandPalette.n0,
    markerChipBackground: Color(0xEBFFFFFF), // white @ 92%
    markerChipLabel: BrandPalette.inkOnLight,
  );

  @override
  DeviceStatusColors copyWith({
    Color? moving,
    Color? idling,
    Color? stopped,
    Color? offline,
    Color? ignitionOn,
    Color? ignitionOff,
    Color? tail,
    Color? geofenceFill,
    Color? geofenceStroke,
    Color? clusterFill,
    Color? clusterLabel,
    Color? markerChipBackground,
    Color? markerChipLabel,
  }) {
    return DeviceStatusColors(
      moving: moving ?? this.moving,
      idling: idling ?? this.idling,
      stopped: stopped ?? this.stopped,
      offline: offline ?? this.offline,
      ignitionOn: ignitionOn ?? this.ignitionOn,
      ignitionOff: ignitionOff ?? this.ignitionOff,
      tail: tail ?? this.tail,
      geofenceFill: geofenceFill ?? this.geofenceFill,
      geofenceStroke: geofenceStroke ?? this.geofenceStroke,
      clusterFill: clusterFill ?? this.clusterFill,
      clusterLabel: clusterLabel ?? this.clusterLabel,
      markerChipBackground: markerChipBackground ?? this.markerChipBackground,
      markerChipLabel: markerChipLabel ?? this.markerChipLabel,
    );
  }

  @override
  DeviceStatusColors lerp(DeviceStatusColors? other, double t) {
    if (other == null) return this;
    return DeviceStatusColors(
      moving: Color.lerp(moving, other.moving, t)!,
      idling: Color.lerp(idling, other.idling, t)!,
      stopped: Color.lerp(stopped, other.stopped, t)!,
      offline: Color.lerp(offline, other.offline, t)!,
      ignitionOn: Color.lerp(ignitionOn, other.ignitionOn, t)!,
      ignitionOff: Color.lerp(ignitionOff, other.ignitionOff, t)!,
      tail: Color.lerp(tail, other.tail, t)!,
      geofenceFill: Color.lerp(geofenceFill, other.geofenceFill, t)!,
      geofenceStroke: Color.lerp(geofenceStroke, other.geofenceStroke, t)!,
      clusterFill: Color.lerp(clusterFill, other.clusterFill, t)!,
      clusterLabel: Color.lerp(clusterLabel, other.clusterLabel, t)!,
      markerChipBackground: Color.lerp(
        markerChipBackground,
        other.markerChipBackground,
        t,
      )!,
      markerChipLabel: Color.lerp(markerChipLabel, other.markerChipLabel, t)!,
    );
  }
}

/// Convenience accessor: `context.statusColors.moving`.
extension DeviceStatusColorsX on BuildContext {
  DeviceStatusColors get statusColors =>
      Theme.of(this).extension<DeviceStatusColors>()!;
}
