import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:idara_esign/core/services/device_info/device_info_service.dart';
import 'package:idara_esign/core/services/ip/ip_info_service.dart';
import 'package:idara_esign/core/services/location/location_service.dart';
import 'package:idara_esign/core/services/logger_service.dart';
import 'package:idara_esign/core/services/network/network_info_service.dart';
import 'package:idara_esign/core/services/package_info/package_info_service.dart';
import 'package:idara_esign/core/services/timezone/timezone_service.dart';
import 'package:idara_esign/core/utils/extensions.dart';

@immutable
class DeviceInfoModel {
  final String? deviceId;
  final String? macAddress;
  final String? deviceOSType;
  final String? deviceType;
  final String? deviceModel;
  final String? deviceName;
  final String? company;
  final String? appVersion;
  final String? osVersion;
  final String? browserVersion;
  final String? timezone;
  final String? latitude;
  final String? longitude;
  final String? locationSource;
  final String? locationAccuracy;
  final String? locale;
  final String? screenResolution;
  final String? networkType;
  final String? referer;
  final String? ipAddress;

  const DeviceInfoModel({
    this.deviceId,
    this.macAddress,
    this.deviceType,
    this.deviceOSType,
    this.deviceModel,
    this.deviceName,
    this.company,
    this.appVersion,
    this.osVersion,
    this.browserVersion,
    this.timezone,
    this.latitude,
    this.longitude,
    this.locationSource,
    this.locationAccuracy,
    this.locale,
    this.screenResolution,
    this.networkType,
    this.referer,
    this.ipAddress,
  });

  /// Headers that match the backend's expected names (see
  /// `Request::header(...)` lookups in the API). Empty/null values are
  /// skipped. `locale` is omitted because `Accept-Language` already carries
  /// it; `ip_address` is omitted because the backend reads it server-side
  /// from the request connection.
  Map<String, String> toHeaders() {
    return {
      if (deviceId != null && deviceId!.isNotEmpty) 'X-Device-Id': deviceId!,
      if (macAddress != null && macAddress!.isNotEmpty)
        'X-MAC-Address': macAddress!,
      if (deviceType != null && deviceType!.isNotEmpty)
        'X-Device-Type': deviceType!,
      if (deviceModel != null && deviceModel!.isNotEmpty)
        'X-Device-Model': deviceModel!,
      if (deviceName != null && deviceName!.isNotEmpty)
        'X-Device-Name': deviceName!,
      if (company != null && company!.isNotEmpty) 'X-Device-Company': company!,
      if (appVersion != null && appVersion!.isNotEmpty)
        'X-App-Version': appVersion!,
      if (osVersion != null && osVersion!.isNotEmpty)
        'X-OS-Version': osVersion!,
      if (browserVersion != null && browserVersion!.isNotEmpty)
        'X-Browser-Version': browserVersion!,
      if (timezone != null && timezone!.isNotEmpty) 'X-Timezone': timezone!,
      if (latitude != null && latitude!.isNotEmpty) 'X-Latitude': latitude!,
      if (longitude != null && longitude!.isNotEmpty) 'X-Longitude': longitude!,
      if (locationSource != null && locationSource!.isNotEmpty)
        'X-Location-Source': locationSource!,
      if (locationAccuracy != null && locationAccuracy!.isNotEmpty)
        'X-Location-Accuracy': locationAccuracy!,
      if (screenResolution != null && screenResolution!.isNotEmpty)
        'X-Screen-Resolution': screenResolution!,
      if (networkType != null && networkType!.isNotEmpty)
        'X-Network-Type': networkType!,
      // if (locale != null && locale!.isNotEmpty) 'Accept-Language': locale!,
      if (ipAddress != null && ipAddress!.isNotEmpty)
        'X-IP-Address': ipAddress!,
      if (referer != null && referer!.isNotEmpty) 'referer': referer!,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'mac_address': macAddress,
      'device_type': deviceType,
      'device_model': deviceModel,
      'device_name': deviceName,
      'company': company,
      'app_version': appVersion,
      'os_version': osVersion,
      'browser_version': browserVersion,
      'timezone': timezone,
      'latitude': latitude,
      'longitude': longitude,
      'location_source': locationSource,
      'location_accuracy': locationAccuracy,
      'locale': locale,
      'screen_resolution': screenResolution,
      'network_type': networkType,
      'referer': referer,
      'ip_address': ipAddress,
    };
  }

  String toPrettyString() => toJson().toPrettyJson();

  @override
  String toString() => toPrettyString();
}

class DeviceData {
  final IDeviceInfoService _deviceInfoService;
  final IPackageInfoService _packageInfoService;
  final LocationService _locationService;
  final IIpInfoService _ipInfoService;
  final ITimezoneService _timezoneService;
  final INetworkInfoService _networkInfoService;

  DeviceData({
    IDeviceInfoService? deviceInfoService,
    IPackageInfoService? packageInfoService,
    LocationService? locationService,
    IIpInfoService? ipInfoService,
    ITimezoneService? timezoneService,
    INetworkInfoService? networkInfoService,
  }) : _deviceInfoService = deviceInfoService ?? DeviceInfoService(),
       _packageInfoService = packageInfoService ?? const PackageInfoService(),
       _locationService = locationService ?? LocationService(),
       _ipInfoService = ipInfoService ?? IpInfoService(),
       _timezoneService = timezoneService ?? const TimezoneService(),
       _networkInfoService = networkInfoService ?? NetworkInfoService();

  DeviceInfoModel? _cachedInfo;

  DeviceInfoModel? get cachedInfo => _cachedInfo;

  /// Whether location permission was granted when [_cachedInfo] was built, so
  /// a later grant/revoke (made in Settings, outside the app) can be spotted.
  bool? _cachedWithLocation;
  AppLifecycleListener? _permissionWatcher;
  bool _isRefreshingForPermission = false;

  /// Re-collects on every resume where the location permission differs from
  /// the one the cache was built with. Without it the headers keep the IP
  /// estimate until the next login even after the user grants access.
  /// The check is cheap (no GPS, no network); collection only runs on change.
  void watchLocationPermission() {
    _permissionWatcher ??= AppLifecycleListener(
      onResume: _refreshIfPermissionChanged,
    );
  }

  Future<void> _refreshIfPermissionChanged() async {
    if (_cachedInfo == null || _isRefreshingForPermission) return;
    _isRefreshingForPermission = true;
    try {
      final granted = await _locationService.checkPermissions();
      if (granted == _cachedWithLocation) return;
      await collectDeviceInfo(forceRefresh: true);
    } catch (e) {
      AppLog.e('Failed to refresh device info after permission change: $e');
    } finally {
      _isRefreshingForPermission = false;
    }
  }

  Future<DeviceInfoModel> collectDeviceInfo({
    bool forceRefresh = false,
    bool requestLocationPermission = false,
  }) async {
    if (_cachedInfo != null && !forceRefresh) {
      return _cachedInfo!;
    }

    try {
      final deviceInfo = await _deviceInfoService.getDeviceInfo();
      final String osType = _resolveDeviceType();

      String? deviceId;
      try {
        deviceId = await _deviceInfoService.getDeviceSerial();
      } catch (e) {
        AppLog.e('Failed to get device serial: $e');
      }

      final String macAddress = 'unknown'; // Defaults to unknown
      String? deviceType;
      String? deviceModel;
      String? deviceName;
      String? company;
      String? osVersion;
      String? browserVersion;

      if (deviceInfo.isWeb && deviceInfo.web != null) {
        deviceType = 'web';
        final webInfo = deviceInfo.web!;
        browserVersion = webInfo.appVersion ?? webInfo.userAgent;
        deviceName = webInfo.browserName.name;
        company = webInfo.vendor;
        osVersion = webInfo.platform;
      } else if (deviceInfo.isAndroid && deviceInfo.android != null) {
        deviceType = 'mobile';
        final androidInfo = deviceInfo.android!;
        deviceModel = androidInfo.model;
        deviceName = androidInfo.device;
        company = androidInfo.manufacturer;
        osVersion =
            'Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})';
      } else if (deviceInfo.isIos && deviceInfo.ios != null) {
        deviceType = 'mobile';
        final iosInfo = deviceInfo.ios!;
        deviceModel = iosInfo.model;
        deviceName = iosInfo.modelName;
        company = 'Apple';
        osVersion = 'iOS ${iosInfo.systemVersion}';
      } else {
        deviceType = deviceInfo.platform.name;
      }

      String? appVersion;
      try {
        final packageInfo = await _packageInfoService.getPackageInfo();
        appVersion = packageInfo.version;
      } catch (e) {
        AppLog.e('Failed to get package info via service: $e');
      }

      String? timezone;
      try {
        timezone = await _timezoneService.getTimezone();
      } catch (e) {
        AppLog.e('Failed to get timezone via service: $e');
      }

      String? ipAddress;
      try {
        ipAddress = await _ipInfoService.getIpAddress();
      } catch (e) {
        AppLog.e('Failed to get IP address via service: $e');
      }

      String? networkType;
      try {
        networkType = await _networkInfoService.getNetworkType();
      } catch (e) {
        AppLog.e('Failed to get network type via service: $e');
      }

      String? latitude = '0.0';
      String? longitude = '0.0';
      String locationSource = 'none';
      String? locationAccuracy;
      bool withLocation = false;
      try {
        // LocationService internally timeouts hardware GPS hangs to execute IP Fallback.
        final located = await _locationService.getCurrentLocation(
          requestIfNeeded: requestLocationPermission,
        );

        if (located != null) {
          latitude = located.position.latitude.toString();
          longitude = located.position.longitude.toString();
          locationSource = located.source.name;
          if (located.source == LocationSource.gps) {
            locationAccuracy = located.position.accuracy.round().toString();
          }
        }
        withLocation = await _locationService.checkPermissions();
      } catch (e) {
        AppLog.e('Failed to get location via service: $e');
      }

      String? locale;
      String? screenResolution;
      try {
        locale = ui.PlatformDispatcher.instance.locale.toString();
        final size = ui.PlatformDispatcher.instance.views.first.physicalSize;
        screenResolution = '${size.width.toInt()}x${size.height.toInt()}';
      } catch (e) {
        AppLog.e('Failed to get locale/screen resolution: $e');
      }

      _cachedInfo = DeviceInfoModel(
        deviceId: deviceId,
        macAddress: macAddress,
        deviceType: deviceType,
        deviceOSType: osType,
        deviceModel: deviceModel,
        deviceName: deviceName,
        company: company,
        appVersion: appVersion,
        osVersion: osVersion,
        browserVersion: browserVersion,
        timezone: timezone,
        latitude: latitude,
        longitude: longitude,
        locationSource: locationSource,
        locationAccuracy: locationAccuracy,
        locale: locale,
        screenResolution: screenResolution,
        networkType: networkType,
        referer: kIsWeb ? Uri.base.host : 'app',
        ipAddress: ipAddress,
      );
      _cachedWithLocation = withLocation;

      return _cachedInfo!;
    } catch (e) {
      AppLog.e(
        'Critical error collecting device info via modular services: $e',
      );
      return const DeviceInfoModel();
    }
  }

  String _resolveDeviceType() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
