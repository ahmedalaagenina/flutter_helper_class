/// from aramex with getx
import 'dart:async';
import 'dart:developer';

import 'package:aramex_courier/refactored_app/config/app_services/caching/caching_service.dart';
import 'package:aramex_courier/refactored_app/core/utils/print.dart';
import 'package:aramex_courier/refactored_app/global_widgets/dialogs.dart';
import 'package:aramex_courier/src/global_cache.dart';
import 'package:aramex_courier/src/model/get_courier_location/get_courier_location_request.dart';
import 'package:aramex_courier/src/provider/get_courier_location/get_courier_location_provider.dart';
import 'package:aramex_courier/src/repository.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;

class LocationController extends FullLifeCycleController
    with FullLifeCycleMixin {
  static const double _distanceFilter = 0; // in meters
  static int _updateInterval =
      GlobalCache.instance.heartbeatFrequency * 1000; // in milliseconds

  final Location _location = Location();
  final Rx<LatLng> currentPosition = LatLng(0, 0).obs;
  final RxBool isLocationDialogOpen = false.obs;
  // variables to track state of life cycle
  RxBool _isInitializing = false.obs;
  DateTime? _lastInitializationTime;
  static const Duration _minInitializationInterval = Duration(seconds: 5);
  // variables for tracking invalid location attempts
  int _consecutiveInvalidLocations = 0;
  static const int _maxInvalidAttempts = 3;
  Timer? _invalidLocationTimer;

  StreamSubscription<LocationData>? _locationSubscription;
  Timer? _locationUpdateRetryTimer;
  GetCourierLocationProvider courierLocationProvider =
      Repository().getCourierLocationProvider;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      iPrint('initializing location service');
      init();
    });
  }

  Future<void> init() async {
    await getCurrentLocation();
    _initializeLocationService();
  }

  /// Retrieves the current device location.
  Future<void> getCurrentLocation() async {
    if (GlobalCache.instance.refreshToken == null) return;
    if (!await _checkLocationPermission()) return;
    LocationData locationData = await _location.getLocation();
    _handleLocationUpdate(locationData);
  }

  Future<void> _initializeLocationService() async {
    try {
      if (GlobalCache.instance.refreshToken == null) return;
      _isInitializing.value = true;

      final isPermissionGranted = await _checkLocationPermission();
      if (!isPermissionGranted) return;
      await _enableLocationUpdates();
    } catch (e) {
      ePrint('Error initializing location service: $e');
      _scheduleLocationRetry();
    } finally {
      _isInitializing.value = false;
    }
  }

  Future<bool> _checkLocationPermission() async {
    bool isLocationEnabled = await _location.serviceEnabled();
    if (!isLocationEnabled) {
      isLocationEnabled = await _location.requestService();
      if (!isLocationEnabled) {
        await _showLocationDialog(isServiceDisabled: true);
        return false;
      }
    }

    PermissionStatus permissionStatus = await _location.hasPermission();
    bool isPermissionGranted = permissionStatus == PermissionStatus.granted;
    if (!isPermissionGranted) {
      permissionStatus = await _location.requestPermission();
      isPermissionGranted = permissionStatus == PermissionStatus.granted;
      if (!isPermissionGranted) {
        await _showLocationDialog();
        return false;
      }
    }
    return _enableBackgroundLocation();
  }

  /// Enable background location mode, with proper error handling
  Future<bool> _enableBackgroundLocation() async {
    try {
      await _location.enableBackgroundMode(enable: true);
      return true;
    } catch (e) {
      ePrint('Failed to enable background location: $e');
      await _showLocationDialog();
      return false;
    }
  }

  Future<void> _enableLocationUpdates() async {
    try {
      // Cancel existing subscription if any
      if (_locationSubscription != null) {
        await _locationSubscription?.cancel();
      }

      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: _updateInterval, // Update every 5 min
        distanceFilter:
            _distanceFilter, // Minimum distance (in meters) to trigger an update
      );

      _locationSubscription = _location.onLocationChanged.listen(
        _handleLocationUpdate,
        onError: (error) {
          iPrint('Location error: $error');
          _scheduleLocationRetry();
        },
      );
    } catch (e) {
      iPrint('Error enabling location updates: $e');
      _scheduleLocationRetry();
    }
  }

  /// Handle location updates by caching the position and sending it to the server
  void _handleLocationUpdate(LocationData locationData) {
    if (_isInvalidLocation(locationData)) {
      _handleInvalidLocation();
      return;
    }
    // Reset invalid location counter when we get a valid location
    _consecutiveInvalidLocations = 0;
    _invalidLocationTimer?.cancel();
    currentPosition.value =
        LatLng(locationData.latitude ?? 0, locationData.longitude ?? 0);
    if (!CachingService.instance.isCachInProgress) {
      _sendLocation(locationData);
    }
  }

  bool _isInvalidLocation(LocationData locationData) {
    return locationData.latitude == null ||
        locationData.longitude == null ||
        (locationData.latitude == 0 && locationData.longitude == 0);
  }

  void _handleInvalidLocation() {
    _consecutiveInvalidLocations++;
    iPrint(
        'Invalid location received. Attempt $_consecutiveInvalidLocations of $_maxInvalidAttempts');
    if (_consecutiveInvalidLocations >= _maxInvalidAttempts) {
      _invalidLocationTimer?.cancel();
      _invalidLocationTimer = Timer(const Duration(seconds: 1), () {
        _showInvalidLocationDialog();
      });
    }
  }

  Future<void> _sendLocation(LocationData locationData) async {
    try {
      if (GlobalCache.instance.openTripId.isEmpty ||
          GlobalCache.instance.openTripId == '' ||
          GlobalCache.instance.openTripId == 'null') return;

      final request = GetCourierLocationRequest(
        latitude: locationData.latitude ?? 0,
        longitude: locationData.longitude ?? 0,
        speed: locationData.speed ?? 0,
        heading: locationData.heading ?? 0,
        accuracy: locationData.accuracy ?? 0,
        gpsreadingts: DateTime.fromMillisecondsSinceEpoch(
          locationData.time?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
          isUtc: true,
        ).toIso8601String(),
        devicets: DateTime.now().toUtc().toIso8601String(),
        courierStatus: CourierStatus(
          lastStatus: "Driving",
          additionalData: null,
          nextTasks: NextTasks(externalId: null, taskType: null),
        ),
      );
      await courierLocationProvider.getLocation(
        [request],
        GlobalCache.instance.openTripId,
      );
      iPrint('Courier location updated');
    } catch (e) {
      ePrint('Error sending location: $e');
    }
  }

  void _scheduleLocationRetry() {
    _locationUpdateRetryTimer?.cancel();
    _locationUpdateRetryTimer =
        Timer(const Duration(minutes: 1), _initializeLocationService);
  }

  Future<void> _showInvalidLocationDialog() async {
    if (isLocationDialogOpen.value) return;
    isLocationDialogOpen.value = true;
    try {
      await customAlertDialog(
        context: Get.context!,
        animation: 'assets/json/custom_aleart_animation.json',
        yesNoConfirmation: true,
        okConfirmation: false,
        alertName: "locationError".tr,
        content: "unableToGetLocation".tr,
        onOk: () async {
          Get.back();
          await _initializeLocationService();
        },
      );
    } finally {
      isLocationDialogOpen.value = false;
      _consecutiveInvalidLocations = 0;
    }
  }

  Future<void> _showLocationDialog({bool isServiceDisabled = false}) async {
    if (isLocationDialogOpen.value) return;
    isLocationDialogOpen.value = true;
    try {
      await customAlertDialog(
        context: Get.context!,
        animation: 'assets/json/custom_aleart_animation.json',
        yesNoConfirmation: false,
        okConfirmation: true,
        alertName: "alert".tr,
        content: '${'locationServices'.tr} ${'backgroundLocation'.tr}',
        onOk: isServiceDisabled
            ? () async {
                await _location.requestService();
                Get.back();
              }
            : () async {
                await await permission_handler.openAppSettings();
                Get.back();
              },
      );
    } finally {
      isLocationDialogOpen.value = false;
    }
  }

  /// Stops all location-related functionality
  Future<void> stopLocationService() async {
    iPrint('Stopping location service');

    try {
      // Cancel location subscription
      await _locationSubscription?.cancel();
      _locationSubscription = null;

      // Cancel timers
      _locationUpdateRetryTimer?.cancel();
      _locationUpdateRetryTimer = null;
      _invalidLocationTimer?.cancel();
      _invalidLocationTimer = null;

      // Reset all state variables
      _isInitializing.value = false;
      _lastInitializationTime = null;
      _consecutiveInvalidLocations = 0;

      // Reset current position
      currentPosition.value = LatLng(0, 0);
      iPrint('Location service stopped successfully');
    } catch (e) {
      ePrint('Error stopping location service: $e');
    }
  }

  @override
  void onClose() {
    stopLocationService();
    super.onClose();
  }

  @override
  void onDetached() => _handleAppLifecycleState('Detached');
  @override
  void onInactive() => _handleAppLifecycleState('Inactive');
  @override
  void onPaused() => _handleAppLifecycleState('Paused');
  @override
  void onResumed() => _handleAppLifecycleState('Resumed');
  @override
  void onHidden() => _handleAppLifecycleState('Hidden');
  void _handleAppLifecycleState(String state) {
    log('App lifecycle state: $state');
    switch (state) {
      case 'Paused':
        // _ensureBackgroundUpdates();
        break;
      case 'Resumed':
        _handleResumed();
        break;
    }
  }

  Future<void> _handleResumed() async {
    ePrint(_isInitializing.value.toString());
    // Check if we're already initializing
    if (_isInitializing.value) {
      iPrint(
          'Initialization location service is already in progress, skipping');
      return;
    }
    _isInitializing.value = true;
    // Check if enough time has passed since last initialization
    if (_lastInitializationTime != null) {
      final timeSinceLastInit =
          DateTime.now().difference(_lastInitializationTime!);
      if (timeSinceLastInit < _minInitializationInterval) {
        iPrint(
            'Waiting for initialization location service: too soon since last attempt');
        await Future.delayed(const Duration(seconds: 5));
      }
    }

    try {
      _lastInitializationTime = DateTime.now();
      final isPermissionGranted = await _checkLocationPermission();

      if (isPermissionGranted &&
          currentPosition.value.latitude == 0 &&
          currentPosition.value.longitude == 0) {
        iPrint('Location service seems disconnected, reinitializing');
        await _initializeLocationService();
      } else {
        iPrint('Location service is working, no need to reinitialize');
      }
    } catch (e) {
      ePrint('Error in handleResumed: $e');
      await _initializeLocationService();
    }
    _isInitializing.value = false;
  }
}
