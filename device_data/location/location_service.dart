import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:idara_esign/config/routes/app_router.dart';

class LocationService {
  Future<bool> checkPermissions({bool requestIfNeeded = false}) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are off on the device (GPS toggle off).
      if (requestIfNeeded && !kIsWeb) {
        _showEnableLocationServiceDialog();
      }
      return false;
    }

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      if (requestIfNeeded) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      } else {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (requestIfNeeded && !kIsWeb) {
        // App settings can only be seamlessly opened on mobile platforms.
        _showPermissionDialog();
      }
      return false;
    }

    return true;
  }

  // Method to gracefully get current location
  Future<Position?> getCurrentLocation({bool requestIfNeeded = false}) async {
    try {
      bool havePermission = await checkPermissions(requestIfNeeded: requestIfNeeded);

      if (!havePermission) return await _getIpFallbackLocation();

      // Attempt generic accuracy to prevent timeout timeouts commonly thrown on Web/Simulators.
      // Forcefully limit to 4 seconds to catch infinite Android Emulator location hangs.
      final position = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 4),
      );
      return position;
    } catch (e) {
      // Hardware fails to triangulate location (Web/Simulators). Fall back to IP Tracking.
      return await _getIpFallbackLocation();
    }
  }

  // Fetch approximate GPS coordinates via Public IP Triangulation as a fallback
  Future<Position?> _getIpFallbackLocation() async {
    final dio = Dio();
    
    // Attempt 1: GeoJS (highly reliable, HTTPS-only, full CORS support for Web)
    try {
      final response = await dio.get('https://get.geojs.io/v1/ip/geo.json');
      final data = response.data;
      if (data != null) {
        final double? lat = double.tryParse(data['latitude']?.toString() ?? '');
        final double? lon = double.tryParse(data['longitude']?.toString() ?? '');
        if (lat != null && lon != null) {
          final position = Position(
            latitude: lat,
            longitude: lon,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
          log('IP Fallback Location (GeoJS): $position');
          return position;
        }
      }
    } catch (e) {
      log('GeoJS IP Fallback failed: $e. Trying FreeIPAPI...');
    }

    // Attempt 2: FreeIPAPI (CORS-enabled on some origins, free, HTTPS support)
    try {
      final response = await dio.get('https://freeipapi.com/api/json');
      final data = response.data;
      if (data != null) {
        final double? lat = double.tryParse(data['latitude']?.toString() ?? '') ?? (data['latitude'] ?? data['lat'])?.toDouble();
        final double? lon = double.tryParse(data['longitude']?.toString() ?? '') ?? (data['longitude'] ?? data['lon'])?.toDouble();
        if (lat != null && lon != null) {
          final position = Position(
            latitude: lat,
            longitude: lon,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
          log('IP Fallback Location (FreeIPAPI): $position');
          return position;
        }
      }
    } catch (e) {
      log('FreeIPAPI IP Fallback failed: $e');
    }

    return null;
  }

  // Show permission dialog for Mobile
  void _showPermissionDialog() {
    if (rootNavigatorKey.currentContext == null) return;

    showDialog(
      context: rootNavigatorKey.currentContext!,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Needed'),
          content: const Text(
            'This app requires location permissions to function. Please grant the setting in your device settings.',
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

  // Show dialog to enable location service (GPS toggle)
  void _showEnableLocationServiceDialog() {
    if (rootNavigatorKey.currentContext == null) return;

    showDialog(
      context: rootNavigatorKey.currentContext!,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Services Disabled'),
          content: const Text(
            'Location services are currently disabled. Please enable them in your device settings to continue.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Enable Location'),
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
              },
            ),
          ],
        );
      },
    );
  }
}
