import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:idara_esign/core/utils/extensions.dart';

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
  Map<String, dynamic> toJson() {
    if (isAndroid) {
      return android!.data;
    } else if (isIos) {
      return ios!.data;
    } else if (isWeb) {
      return web!.data;
    }
    return {};
  }

  String toPrettyString() => toJson().toPrettyJson();

  void printPretty() {
    debugPrint(toPrettyString());
  }

  @override
  String toString() => toPrettyString();
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
    if (kIsWeb && baseInfo is WebBrowserInfo) {
      final raw =
          '${baseInfo.vendor}-${baseInfo.userAgent}-${baseInfo.hardwareConcurrency}-${baseInfo.maxTouchPoints}';
      return sha256.convert(utf8.encode(raw)).toString();
    } else if (Platform.isIOS && baseInfo is IosDeviceInfo) {
      return baseInfo.identifierForVendor;
    } else if (Platform.isAndroid && baseInfo is AndroidDeviceInfo) {
      const androidIdPlugin = AndroidId();
      final androidId = await androidIdPlugin.getId();
      if (androidId != null) return androidId;
      final info = await _plugin.androidInfo;
      final raw = '${info.fingerprint}-${info.id}';
      return sha256.convert(utf8.encode(raw)).toString();
    }
    return null;
  }

  @override
  Future<AppDeviceInfo> getDeviceInfo() async {
    final baseInfo = await _plugin.deviceInfo;

    if (kIsWeb && baseInfo is WebBrowserInfo) {
      AppDeviceInfo deviceInfo = AppDeviceInfo(
        platform: AppDevicePlatform.web,
        web: baseInfo,
      );

      return deviceInfo;
    } else if (Platform.isAndroid && baseInfo is AndroidDeviceInfo) {
      AppDeviceInfo deviceInfo = AppDeviceInfo(
        platform: AppDevicePlatform.android,
        android: baseInfo,
      );
      log('======= deviceInfo android =======>');
      log(deviceInfo.toString());
      log('======= deviceInfo android =======>');
      return deviceInfo;
    } else if (Platform.isIOS && baseInfo is IosDeviceInfo) {
      AppDeviceInfo deviceInfo = AppDeviceInfo(
        platform: AppDevicePlatform.ios,
        ios: baseInfo,
      );
      return deviceInfo;
    }

    return const AppDeviceInfo(platform: AppDevicePlatform.unknown);
  }
}
