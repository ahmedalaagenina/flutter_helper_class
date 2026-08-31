import 'dart:developer';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';
import 'package:safe_device/safe_device_config.dart';

/// Why the app refused to run.
enum DeviceBlockReason {
  none,
  /// Web, Windows, Linux, macOS, or Windows Subsystem for Android.
  unsupportedPlatform,
  /// Emulator, VM, or a Windows Android app player.
  emulator,
  /// Rooted or jailbroken.
  compromised,
  developerMode,
  usbDebugging,
}

/// Raw evidence about the current device. Observes only — applies no policy and
/// reaches no verdict, so it can be logged as-is.
@immutable
class DeviceSignals {
  const DeviceSignals(this._byReason, {this.native = true});

  final Map<DeviceBlockReason, List<String>> _byReason;

  /// Whether the native detection actually ran.
  ///
  /// `safe_device` catches its own platform-channel errors and returns `false`
  /// from every getter. For `isJailBroken` that reads as "clean", but for
  /// `isRealDevice` it reads as "emulator" — so a plugin that failed to register
  /// would block every genuine phone. When this is `false` the native answers
  /// were discarded and only `device_info_plus` was trusted.
  final bool native;

  List<String> operator [](DeviceBlockReason reason) =>
      _byReason[reason] ?? const [];

  @override
  String toString() {
    final fired = _byReason.entries.where((e) => e.value.isNotEmpty);
    return 'DeviceSignals(native: $native, '
        '${fired.map((e) => '${e.key.name}: ${e.value}').join(', ')})';
  }
}

/// Reads [DeviceSignals] from `safe_device` and `device_info_plus`.
abstract final class DeviceSignalReader {
  static bool _initialized = false;

  static Future<DeviceSignals> read() async {
    // A web build is reachable from any desktop browser.
    if (kIsWeb) {
      return const DeviceSignals({
        DeviceBlockReason.unsupportedPlatform: ['platform:web'],
      });
    }
    // Windows, Linux, macOS. `dart:io` is enough to know, so this verdict never
    // depends on a plugin.
    if (!Platform.isAndroid && !Platform.isIOS) {
      return DeviceSignals({
        DeviceBlockReason.unsupportedPlatform: [
          'platform:${Platform.operatingSystem}',
        ],
      });
    }

    // Must run before any getter: the default config starts real location
    // updates to power the mock-location check, which costs battery, needs a
    // runtime permission, and says nothing about root or emulators.
    if (!_initialized) {
      SafeDevice.init(const SafeDeviceConfig(mockLocationCheckEnabled: false));
      _initialized = true;
    }

    final native = await _nativeChecksWork();
    return Platform.isAndroid ? _readAndroid(native) : _readIOS(native);
  }

  /// Probes whether the `safe_device` channel is alive.
  ///
  /// `rootDetectionDetails` / `jailbreakDetails` are the only two members that
  /// do *not* swallow their errors, which makes them usable as a health check:
  /// if one throws, every other getter is returning a meaningless `false`.
  static Future<bool> _nativeChecksWork() async {
    try {
      if (Platform.isAndroid) {
        await SafeDevice.rootDetectionDetails;
      } else {
        await SafeDevice.jailbreakDetails;
      }
      return true;
    } catch (e) {
      log('DeviceSignalReader: native checks unavailable, ignoring them -> $e');
      return false;
    }
  }

  static Future<DeviceSignals> _readAndroid(bool native) async {
    final info = await DeviceInfoPlugin().androidInfo;
    return DeviceSignals(
      {
        // WSA is Windows, so it is reported as a platform, not an emulator.
        DeviceBlockReason.unsupportedPlatform: _windowsSubsystemSignals(info),
        DeviceBlockReason.emulator: [
          if (!info.isPhysicalDevice) 'build:not-physical',
          // Covers Genymotion, qemu/goldfish/ranchu, BlueStacks, LDPlayer, Nox,
          // MEmu, MuMu and x86-only images natively.
          if (native && !await SafeDevice.isRealDevice) 'native:emulator',
        ],
        DeviceBlockReason.compromised: [
          // Already covers the `test-keys` build tag, su binaries, Magisk paths
          // and dangerous system properties — no need to repeat any in Dart.
          if (native && (await SafeDevice.isJailBroken)) 'native:rooted',
        ],
        DeviceBlockReason.developerMode: [
          if (native && await SafeDevice.isDevelopmentModeEnable)
            'developer-options',
        ],
        DeviceBlockReason.usbDebugging: [
          if (native && await SafeDevice.isUsbDebuggingEnabled) 'usb-debugging',
        ],
      },
      native: native,
    );
  }

  /// Windows Subsystem for Android, which `safe_device` does not detect.
  ///
  /// WSA identifies itself honestly, so exact matches are enough — and any one
  /// of these blocks on its own, so each has to be near-zero false positive.
  /// The manufacturer is compared in full for that reason: the Surface Duo is a
  /// genuine Android phone reporting `Microsoft`, while WSA reports
  /// `Microsoft Corporation`. `wsa:feature` is the strongest of the five — the
  /// other four are strings anyone can edit in `build.prop`, while a system
  /// feature is declared by the runtime itself.
  static List<String> _windowsSubsystemSignals(AndroidDeviceInfo info) {
    final brand = info.brand.toLowerCase().trim();
    final board = info.board.toLowerCase().trim();
    final manufacturer = info.manufacturer.toLowerCase().trim();
    final model = info.model.toLowerCase().trim();

    return [
      if (brand == 'windows') 'wsa:brand',
      if (board == 'windows') 'wsa:board',
      if (manufacturer == 'microsoft corporation') 'wsa:manufacturer',
      if (model.contains('subsystem for android')) 'wsa:model',
      if (info.systemFeatures.any(
        (f) => f.toLowerCase().startsWith('com.microsoft.windows'),
      ))
        'wsa:feature',
    ];
  }

  static Future<DeviceSignals> _readIOS(bool native) async {
    final info = await DeviceInfoPlugin().iosInfo;
    return DeviceSignals(
      {
        DeviceBlockReason.emulator: [
          if (!info.isPhysicalDevice) 'ios:simulator',
          // Set by Xcode inside a simulator process, absent on hardware.
          if (Platform.environment.containsKey('SIMULATOR_DEVICE_NAME'))
            'ios:simulator-env',
          if (native && !await SafeDevice.isRealDevice) 'native:emulator',
        ],
        DeviceBlockReason.compromised: [
          if (native && await SafeDevice.isJailBroken) 'native:jailbroken',
        ],
      },
      native: native,
    );
  }
}
