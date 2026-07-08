// new one 
// handle foreground and current location 


import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:shorebird_location/main.dart';

// handle foreground
class LocationHelper {
  LocationHelper._();
  static const int _distanceFilter = 1; // in meters
  static const Duration _updateInterval = Duration(seconds: 60);
  // Stream controller for location updates
  static Stream<Position>? _positionStream;
  static Stream<Position>? get positionStream => _positionStream;

  static Future<bool> _requestLocationService() async {
    var status = await Permission.locationWhenInUse.request();
    return status == PermissionStatus.granted;
  }

  /// Checks and requests location permissions if needed.
  static Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _requestLocationService();
      if (!serviceEnabled) return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showPermissionDialog();
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showPermissionDialog();
      return false;
    }

    return true;
  }

  // Method to get current location
  static Future<Position?> getCurrentLocation() async {
    bool havePermission = await checkPermissions();
    if (!havePermission) return null;
    return await Geolocator.getCurrentPosition();
  }

  // Method to start listening to location updates in foreground
  static Future<void> startListeningLocationChanged(
    ValueChanged<Position> onLocationUpdate,
  ) async {
    bool havePermission = await checkPermissions();
    if (!havePermission) return;
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _distanceFilter, 
      timeLimit: _updateInterval,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings);
    _positionStream?.listen(onLocationUpdate);
  }

  // Method to stop listening to location updates
  static void stopListeningLocation() {
    _positionStream = null;
  }

  // Method to calculate distance between two geocoordinates
  static double calculateDistance({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  // Method to calculate bearing between two geocoordinates
  static double calculateBearing({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    startLatitude = _degreesToRadians(startLatitude);
    startLongitude = _degreesToRadians(startLongitude);
    endLatitude = _degreesToRadians(endLatitude);
    endLongitude = _degreesToRadians(endLongitude);

    double dLong = endLongitude - startLongitude;

    double y = sin(dLong) * cos(endLatitude);
    double x = cos(startLatitude) * sin(endLatitude) -
        sin(startLatitude) * cos(endLatitude) * cos(dLong);

    double bearing = atan2(y, x);
    bearing = _radiansToDegrees(bearing);
    bearing = (bearing + 360) % 360;

    return bearing;
  }

  // Helper method to convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  // Helper method to convert radians to degrees
  static double _radiansToDegrees(double radians) {
    return radians * 180.0 / pi;
  }

  /// Retrieves address information from coordinates.
  static Future<List<geo.Placemark>> getFullPlaceAddress({
    required double latitude,
    required double longitude,
  }) async {
    return await geo.placemarkFromCoordinates(latitude, longitude);
  }

  /// Retrieves coordinates from an address string.
  static Future<List<geo.Location>> getLocationAddress({
    required String address,
  }) async {
    return await geo.locationFromAddress(address);
  }

  // Reverse geocoding: get address from coordinates
  static Future<String> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    List<geo.Placemark> placemarks =
        await geo.placemarkFromCoordinates(latitude, longitude);
    if (placemarks.isNotEmpty) {
      geo.Placemark place = placemarks[0];
      return '${place.name}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
    }
    return 'No address available';
  }

  // Show permission dialog
  static void _showPermissionDialog() {
    showDialog(
      context: navigatorKey.currentState!.context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Needed'),
          content: const Text(
            'This app requires location permissions to function properly. Please grant the permission.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }
}
