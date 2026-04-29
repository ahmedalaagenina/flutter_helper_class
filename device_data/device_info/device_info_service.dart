import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

// getIt.registerLazySingleton<IDeviceInfoService>(() => DeviceInfoService());
// getIt.registerLazySingleton<DeviceInfoManager>(
//   () => DeviceInfoManager(getIt<IDeviceInfoService>()),
// );

enum AppDevicePlatform { android, ios, web, macos, windows, linux, unknown }

@immutable
class AppDeviceInfo {
  final AppDevicePlatform platform;
  final AndroidDeviceInfo? android;
  final IosDeviceInfo? ios;
  final WebBrowserInfo? web;

  const AppDeviceInfo({
    required this.platform,
    this.android,
    this.ios,
    this.web,
  });

  bool get isAndroid => platform == AppDevicePlatform.android;
  bool get isIos => platform == AppDevicePlatform.ios;
  bool get isWeb => platform == AppDevicePlatform.web;
}

class DeviceInfoManager {
  final IDeviceInfoService _service;

  AppDeviceInfo? _cached;
  Future<AppDeviceInfo>? _pending;

  DeviceInfoManager(this._service);

  Future<AppDeviceInfo> getDeviceInfo() {
    if (_cached != null) return Future.value(_cached!);
    if (_pending != null) return _pending!;

    _pending = _service.getDeviceInfo().then((value) {
      _cached = value;
      _pending = null;
      return value;
    });

    return _pending!;
  }

  void clearCache() {
    _cached = null;
    _pending = null;
  }
}

abstract class IDeviceInfoService {
  Future<AppDeviceInfo> getDeviceInfo();
  Future<String?> getDeviceSerial();
}

class DeviceInfoService implements IDeviceInfoService {
  DeviceInfoService({DeviceInfoPlugin? plugin})
    : _plugin = plugin ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _plugin;

  @override
  Future<String?> getDeviceSerial() async {
    final baseInfo = await _plugin.deviceInfo;
    if (Platform.isIOS && baseInfo is IosDeviceInfo) {
      return '${baseInfo.model}_${baseInfo.identifierForVendor!}';
    } else if (Platform.isAndroid && baseInfo is AndroidDeviceInfo) {
      return '${baseInfo.model}_${baseInfo.id}';
    }
    return null;
  }

  @override
  Future<AppDeviceInfo> getDeviceInfo() async {
    final baseInfo = await _plugin.deviceInfo;

    if (kIsWeb && baseInfo is WebBrowserInfo) {
      return AppDeviceInfo(platform: AppDevicePlatform.web, web: baseInfo);
    } else if (Platform.isAndroid && baseInfo is AndroidDeviceInfo) {
      return AppDeviceInfo(
        platform: AppDevicePlatform.android,
        android: baseInfo,
      );
    } else if (Platform.isIOS && baseInfo is IosDeviceInfo) {
      return AppDeviceInfo(platform: AppDevicePlatform.ios, ios: baseInfo);
    }

    return const AppDeviceInfo(platform: AppDevicePlatform.unknown);
  }
}
