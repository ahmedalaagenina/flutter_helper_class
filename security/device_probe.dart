import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:safe_device/safe_device.dart';
import 'package:safe_device/safe_device_config.dart';

/// Everything `DeviceIntegrity` needs to know about the machine it is running
/// on, behind one injectable interface.
///
/// The engine never touches a plugin or `dart:io` directly. That buys two
/// things: the detection tables become unit-testable against synthetic devices
/// (see `test/device_integrity_test.dart`), and swapping in a stricter probe —
/// Play Integrity, a native attestation channel — does not touch the scoring
/// logic.
///
/// Implementations must **not** throw for a merely-unavailable answer; the
/// engine still guards every call, but an implementation that knows the answer
/// is unknown should say so with the safe value.
abstract interface class DeviceProbe {
  bool get isAndroid;

  bool get isIOS;

  /// `Platform.operatingSystem`, used only to name an unsupported desktop.
  String get operatingSystem;

  /// Process environment. On the iOS Simulator this carries `SIMULATOR_*`.
  Map<String, String> get environment;

  Future<AndroidProbeInfo> androidInfo();

  Future<IosProbeInfo> iosInfo();

  Future<InstallProbeInfo> installInfo();

  /// `false` means "emulator". Native check from `safe_device`.
  Future<bool> isRealDevice();

  Future<bool> isJailBroken();

  Future<bool> isDeveloperModeEnabled();

  Future<bool> isUsbDebuggingEnabled();

  /// Whether [path] resolves to anything. Must never throw — an unreadable
  /// path is reported as absent.
  Future<bool> pathExists(String path);
}

/// The `android.os.Build` fields the detection tables are matched against.
///
/// A plain value object rather than `AndroidDeviceInfo` so a test can describe
/// a device in four lines and so the engine does not break when
/// `device_info_plus` reshapes its models.
@immutable
class AndroidProbeInfo {
  const AndroidProbeInfo({
    this.brand = '',
    this.device = '',
    this.model = '',
    this.product = '',
    this.manufacturer = '',
    this.hardware = '',
    this.board = '',
    this.bootloader = '',
    this.fingerprint = '',
    this.tags = '',
    this.type = '',
    this.supportedAbis = const [],
    this.systemFeatures = const [],
    this.isPhysicalDevice = true,
  });

  factory AndroidProbeInfo.from(AndroidDeviceInfo info) => AndroidProbeInfo(
        brand: info.brand,
        device: info.device,
        model: info.model,
        product: info.product,
        manufacturer: info.manufacturer,
        hardware: info.hardware,
        board: info.board,
        bootloader: info.bootloader,
        fingerprint: info.fingerprint,
        tags: info.tags,
        type: info.type,
        supportedAbis: info.supportedAbis,
        systemFeatures: info.systemFeatures,
        isPhysicalDevice: info.isPhysicalDevice,
      );

  final String brand;
  final String device;
  final String model;
  final String product;
  final String manufacturer;
  final String hardware;
  final String board;
  final String bootloader;
  final String fingerprint;
  final String tags;
  final String type;
  final List<String> supportedAbis;
  final List<String> systemFeatures;
  final bool isPhysicalDevice;
}

/// The iOS facts worth checking. [machine] is the `utsname` value: a real
/// device reports a model identifier such as `iPhone14,5`, the Simulator
/// reports the host architecture (`x86_64`, `arm64`).
@immutable
class IosProbeInfo {
  const IosProbeInfo({
    this.model = '',
    this.machine = '',
    this.systemName = '',
    this.isPhysicalDevice = true,
    this.isAppOnMac = false,
  });

  factory IosProbeInfo.from(IosDeviceInfo info) => IosProbeInfo(
        model: info.model,
        machine: info.utsname.machine,
        systemName: info.systemName,
        isPhysicalDevice: info.isPhysicalDevice,
        isAppOnMac: info.isiOSAppOnMac,
      );

  final String model;
  final String machine;
  final String systemName;
  final bool isPhysicalDevice;

  /// An iPhone/iPad build running on Apple Silicon macOS.
  final bool isAppOnMac;
}

/// Where this copy of the app came from.
///
/// Answers a different question from the rest of the module: not "is the
/// device genuine" but "is the *app* genuine". A cracked build is normally
/// re-signed and sideloaded, so both fields move.
@immutable
class InstallProbeInfo {
  const InstallProbeInfo({this.installerStore, this.buildSignature = ''});

  /// Package name of the installing store, e.g. `com.android.vending`.
  /// `null`/empty means sideloaded — or simply unknown, which is why the
  /// tamper check is opt-in.
  final String? installerStore;

  /// SHA of the Android signing certificate. Always empty on iOS.
  final String buildSignature;
}

/// The real implementation: `device_info_plus`, `safe_device`,
/// `package_info_plus` and `dart:io`.
///
/// This is the only file in the module that imports `dart:io`, which is also
/// why the module cannot be compiled for web at all — see `README.md`.
class PlatformDeviceProbe implements DeviceProbe {
  const PlatformDeviceProbe();

  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static bool _safeDeviceReady = false;

  /// `safe_device` keeps its own `isInitiated` flag and logs a warning when
  /// re-initialised, so gate it here rather than calling it per evaluation.
  static void _ensureSafeDevice() {
    if (_safeDeviceReady) return;
    _safeDeviceReady = true;
    SafeDevice.init(const SafeDeviceConfig(mockLocationCheckEnabled: false));
  }

  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  bool get isIOS => Platform.isIOS;

  @override
  String get operatingSystem => Platform.operatingSystem;

  @override
  Map<String, String> get environment => Platform.environment;

  @override
  Future<AndroidProbeInfo> androidInfo() async =>
      AndroidProbeInfo.from(await _deviceInfo.androidInfo);

  @override
  Future<IosProbeInfo> iosInfo() async =>
      IosProbeInfo.from(await _deviceInfo.iosInfo);

  @override
  Future<InstallProbeInfo> installInfo() async {
    final info = await PackageInfo.fromPlatform();
    return InstallProbeInfo(
      installerStore: info.installerStore,
      buildSignature: info.buildSignature,
    );
  }

  @override
  Future<bool> isRealDevice() {
    _ensureSafeDevice();
    return SafeDevice.isRealDevice;
  }

  @override
  Future<bool> isJailBroken() {
    _ensureSafeDevice();
    return SafeDevice.isJailBroken;
  }

  @override
  Future<bool> isDeveloperModeEnabled() {
    _ensureSafeDevice();
    return SafeDevice.isDevelopmentModeEnable;
  }

  @override
  Future<bool> isUsbDebuggingEnabled() {
    _ensureSafeDevice();
    return SafeDevice.isUsbDebuggingEnabled;
  }

  @override
  Future<bool> pathExists(String path) async {
    try {
      return await FileSystemEntity.type(path) != FileSystemEntityType.notFound;
    } catch (_) {
      // Unreadable path (SELinux, sandbox) — indistinguishable from absent.
      return false;
    }
  }
}
