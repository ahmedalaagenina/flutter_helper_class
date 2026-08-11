import 'package:equatable/equatable.dart';

class MeasurementUnits extends Equatable {
  const MeasurementUnits({
    this.distance,
    this.speed,
    this.volume,
    this.altitude,
  });

  const MeasurementUnits.unknown() : this();

  /// `Km`, `Mi`, `Nm`.
  final String? distance;

  /// `kph`, `mph`.
  final String? speed;

  /// `L`, `gl`.
  final String? volume;

  /// `m`, `ft`.
  final String? altitude;

  bool get isEmpty =>
      distance == null && speed == null && volume == null && altitude == null;

  @override
  List<Object?> get props => [distance, speed, volume, altitude];
}
