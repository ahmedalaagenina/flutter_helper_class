///
/// 
/// handle current location 
/// new normal one 



import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:idara_esign/config/routes/app_router.dart';

class LocationService {
  Future<bool> checkPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are off on the device (GPS toggle off).
      if (!kIsWeb) {
        _showEnableLocationServiceDialog();
      }
      return false;
    }

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!kIsWeb) {
        // App settings can only be seamlessly opened on mobile platforms.
        _showPermissionDialog();
      }
      return false;
    }

    return true;
  }

  // Method to gracefully get current location
  Future<Position?> getCurrentLocation() async {
    try {
      bool havePermission = await checkPermissions();

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
    try {
      final dio = Dio();
      // http://ip-api.com/json/ explicitly supports CORS and works flawlessly on http://localhost
      // final response = await dio.get('https://free.freeipapi.com/api/json');
      final response = await dio.get('http://ip-api.com/json/');
      final data = response.data;
      if (data['lat'] != null && data['lon'] != null) {
        final position = Position(
          latitude: (data['lat'] as num).toDouble(),
          longitude: (data['lon'] as num).toDouble(),
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );
        log('IP Fallback Location: $position');
        return position;
      }
    } catch (e) {
      log('IP Fallback Location failed: $e');
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
