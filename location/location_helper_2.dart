
/// OLD ONE



import 'package:location/location.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:flutter/material.dart';
import 'package:app_settings/app_settings.dart';

// const GOOGLE_API_KEY = 'AIzaSyCvrYkbhs9PAMtEAaTwnXrFtQaBz-GS60Q';
const GOOGLE_API_KEY = 'AIzaSyBT30Wp2jPm5sw9DrP9qTge8SZgBsAO_wI';

// handle foreground and background
class LocationService {
  LocationService._();

  static final Location _location = Location();

  static const double _distanceFilter = 1.0; // in meters
  static const int _updateInterval = 10000; // in milliseconds

  /// Checks if location services are enabled and requests permissions if needed.
  static Future<bool> ensureLocationPermission() async {
    if (!await _isLocationServiceEnabled()) {
      if (!await _requestLocationService()) {
        return false;
      }
    }

    PermissionStatus permissionStatus = await _checkLocationPermission();
    if (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await _requestLocationPermission();
      if (permissionStatus == PermissionStatus.deniedForever) {
        _showPermissionDialog();
        return false;
      }
    }

    return permissionStatus == PermissionStatus.granted;
  }

  /// Retrieves the current device location.
  static Future<LocationData?> getCurrentLocation() async {
    if (!await ensureLocationPermission()) return null;
    return await _location.getLocation();
  }

  /// Starts listening for location updates.
  static Future<void> startLocationUpdates(
      ValueChanged<LocationData> onLocationChanged) async {
    if (!await ensureLocationPermission()) return;

    await _location.enableBackgroundMode(enable: true);
    _location.changeSettings(
      interval: _updateInterval,
      distanceFilter: _distanceFilter,
    );
    _location.onLocationChanged.listen(onLocationChanged);
  }

  /// Stops listening for location updates.
  static Future<void> stopLocationUpdates() async {
    await _location.enableBackgroundMode(enable: false);
  }

  /// Retrieves address information from coordinates.
  static Future<List<geocoding.Placemark>> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    return await geocoding.placemarkFromCoordinates(latitude, longitude);
  }

  /// Retrieves coordinates from an address string.
  static Future<List<geocoding.Location>> getCoordinatesFromAddress({
    required String address,
  }) async {
    return await geocoding.locationFromAddress(address);
  }

  /// Formats a full address string from coordinates.
  static Future<String> getFormattedAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    List<geocoding.Placemark> placemarks = await getAddressFromCoordinates(
      latitude: latitude,
      longitude: longitude,
    );

    if (placemarks.isNotEmpty) {
      geocoding.Placemark place = placemarks.first;
      return [
        place.name,
        place.locality,
        place.administrativeArea,
        place.country,
      ].where((element) => element != null && element.isNotEmpty).join(', ');
    }

    return 'Address not available';
  }

  // Private methods

  static Future<bool> _isLocationServiceEnabled() async {
    return await _location.serviceEnabled();
  }

  static Future<bool> _requestLocationService() async {
    return await _location.requestService();
  }

  static Future<PermissionStatus> _checkLocationPermission() async {
    return await _location.hasPermission();
  }

  static Future<PermissionStatus> _requestLocationPermission() async {
    return await _location.requestPermission();
  }

  static void _showPermissionDialog() {
    final BuildContext context =
        RouteConfigurations.parentNavigatorKey.currentState!.context;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'This app requires location permission to function properly. '
            'Please grant the permission in your device settings.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                AppSettings.openAppSettings(type: AppSettingsType.location);
              },
            ),
          ],
        );
      },
    );
  }
}
