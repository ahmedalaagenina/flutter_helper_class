import 'dart:async';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:idara_esign/config/routes/app_router.dart';
import 'package:idara_esign/generated/l10n.dart';

/// Where a position came from. GPS is the device's own fix; IP is a
/// city-level guess from the public IP, and can be a whole country off
/// behind a VPN or a carrier gateway.
enum LocationSource { gps, ip }

typedef SourcedPosition = ({Position position, LocationSource source});

class LocationService {
  static const _quickOpTimeout = Duration(seconds: 10);
  static const _permissionRequestTimeout = Duration(seconds: 60);
  static const _settingsReturnTimeout = Duration(minutes: 2);

  Future<bool> checkPermissions({bool requestIfNeeded = false}) async {
    bool serviceEnabled;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        _quickOpTimeout,
      );
    } catch (_) {
      return false;
    }

    if (!serviceEnabled) {
      if (!requestIfNeeded || kIsWeb) return false;
      final wantsToEnable = await _showEnableLocationServiceDialog();
      if (wantsToEnable != true) return false;

      await _openLocationSettingsAndWait();

      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
          _quickOpTimeout,
        );
      } catch (_) {
        return false;
      }
      if (!serviceEnabled) return false;
    }

    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission().timeout(_quickOpTimeout);
    } catch (_) {
      return false;
    }

    if (permission == LocationPermission.denied) {
      if (!requestIfNeeded) return false;
      try {
        permission = await Geolocator.requestPermission().timeout(
          _permissionRequestTimeout,
        );
      } catch (_) {
        return false;
      }
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> _openLocationSettingsAndWait() async {
    final resumed = Completer<void>();
    final listener = AppLifecycleListener(
      onResume: () {
        if (!resumed.isCompleted) resumed.complete();
      },
    );
    try {
      final opened = await Geolocator.openLocationSettings();
      if (opened) {
        await resumed.future.timeout(_settingsReturnTimeout, onTimeout: () {});
      }
    } catch (_) {
      // Ignore — the caller re-checks the service state either way.
    } finally {
      listener.dispose();
    }
  }

  // Method to gracefully get current location
  Future<SourcedPosition?> getCurrentLocation({
    bool requestIfNeeded = false,
  }) async {
    try {
      bool havePermission = await checkPermissions(
        requestIfNeeded: requestIfNeeded,
      );

      if (!havePermission) return await _ipFallback();

      final position = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 5),
      );
      return (position: position, source: LocationSource.gps);
    } catch (e) {
      return await _ipFallback();
    }
  }

  Future<SourcedPosition?> _ipFallback() async {
    final position = await _getIpFallbackLocation();
    if (position == null) return null;
    return (position: position, source: LocationSource.ip);
  }

  // Fetch approximate GPS coordinates via Public IP Triangulation as a fallback
  Future<Position?> _getIpFallbackLocation() async {
    // Bounded so a stalled network can't hang the (awaited) login flow.
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );

    // Attempt 1: GeoJS (highly reliable, HTTPS-only, full CORS support for Web)
    try {
      final response = await dio.get('https://get.geojs.io/v1/ip/geo.json');
      final data = response.data;
      if (data != null) {
        final double? lat = double.tryParse(data['latitude']?.toString() ?? '');
        final double? lon = double.tryParse(
          data['longitude']?.toString() ?? '',
        );
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
        final double? lat =
            double.tryParse(data['latitude']?.toString() ?? '') ??
            (data['latitude'] ?? data['lat'])?.toDouble();
        final double? lon =
            double.tryParse(data['longitude']?.toString() ?? '') ??
            (data['longitude'] ?? data['lon'])?.toDouble();
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
  void showPermissionDialog() {
    if (rootNavigatorKey.currentContext == null) return;

    showDialog(
      context: rootNavigatorKey.currentContext!,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(S.of(context).locationPermissionNeeded),
          content: Text(S.of(context).locationPermissionNeededMessage),
          actions: [
            TextButton(
              child: Text(S.of(context).cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            if (!kIsWeb)
              TextButton(
                child: Text(S.of(context).openSettings),
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

  Future<bool?> _showEnableLocationServiceDialog() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return Future.value(false);

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(S.of(dialogContext).locationServicesDisabled),
          content: Text(S.of(dialogContext).locationServicesDisabledMessage),
          actions: [
            TextButton(
              child: Text(S.of(dialogContext).cancel),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: Text(S.of(dialogContext).enableLocation),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
  }
}
