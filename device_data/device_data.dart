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
  final String? locale;
  final String? screenResolution;
  final String? networkType;
  final String? referer;
  final String? ipAddress;

  const DeviceInfoModel({
    this.deviceId,
    this.macAddress,
    this.deviceType,
    this.deviceModel,
    this.deviceName,
    this.company,
    this.appVersion,
    this.osVersion,
    this.browserVersion,
    this.timezone,
    this.latitude,
    this.longitude,
    this.locale,
    this.screenResolution,
    this.networkType,
    this.referer,
    this.ipAddress,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'macAddress': macAddress,
      'deviceType': deviceType,
      'deviceModel': deviceModel,
      'deviceName': deviceName,
      'company': company,
      'appVersion': appVersion,
      'osVersion': osVersion,
      'browserVersion': browserVersion,
      'timezone': timezone,
      'latitude': latitude,
      'longitude': longitude,
      'locale': locale,
      'screenResolution': screenResolution,
      'networkType': networkType,
      'referer': referer,
      'ipAddress': ipAddress,
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

  Future<DeviceInfoModel> collectDeviceInfo({
    bool forceRefresh = false
  }) async {
    if (_cachedInfo != null && !forceRefresh) {
      return _cachedInfo!;
    }

    try {
      final deviceInfo = await _deviceInfoService.getDeviceInfo();

      String? deviceId;
      try {
        deviceId = await _deviceInfoService.getDeviceSerial();
      } catch (e) {
        AppLog.e('Failed to get device serial: $e');
      }

      String? macAddress = 'unknown'; // Defaults to unknown
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
      try {
        // LocationService internally timeouts hardware GPS hangs to execute IP Fallback.
        final position = await _locationService.getCurrentLocation();
        
        if (position != null) {
          latitude = position.latitude.toString();
          longitude = position.longitude.toString();
        }
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
        deviceModel: deviceModel,
        deviceName: deviceName,
        company: company,
        appVersion: appVersion,
        osVersion: osVersion,
        browserVersion: browserVersion,
        timezone: timezone,
        latitude: latitude,
        longitude: longitude,
        locale: locale,
        screenResolution: screenResolution,
        networkType: networkType,
        referer: kIsWeb ? Uri.base.host : 'app',
        ipAddress: ipAddress,
      );

      return _cachedInfo!;
    } catch (e) {
      AppLog.e(
        'Critical error collecting device info via modular services: $e',
      );
      return const DeviceInfoModel();
    }
  }
}
