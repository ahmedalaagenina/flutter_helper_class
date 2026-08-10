import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../device_security.dart';

/// A [DeviceProbe] that answers from canned data, so the detection tables can
/// be exercised against synthetic devices without a phone in the room.
///
/// [failing] names probes that throw; [hanging] names probes that never answer.
/// Both exist to pin down the failure policy: one broken probe must never
/// discard the evidence its siblings already found.
class FakeDeviceProbe implements DeviceProbe {
  FakeDeviceProbe({
    this.isAndroid = true,
    this.isIOS = false,
    this.operatingSystem = 'android',
    this.environment = const {},
    this.android = const AndroidProbeInfo(),
    this.ios = const IosProbeInfo(),
    this.install =
        const InstallProbeInfo(installerStore: 'com.android.vending'),
    this.realDevice = true,
    this.jailBroken = false,
    this.developerMode = false,
    this.usbDebugging = false,
    this.existingPaths = const {},
    this.failing = const {},
    this.hanging = const {},
  });

  @override
  final bool isAndroid;
  @override
  final bool isIOS;
  @override
  final String operatingSystem;
  @override
  final Map<String, String> environment;

  final AndroidProbeInfo android;
  final IosProbeInfo ios;
  final InstallProbeInfo install;
  final bool realDevice;
  final bool jailBroken;
  final bool developerMode;
  final bool usbDebugging;
  final Set<String> existingPaths;
  final Set<String> failing;
  final Set<String> hanging;

  Future<T> _answer<T>(String name, T value) {
    if (hanging.contains(name)) return Completer<T>().future;
    if (failing.contains(name)) {
      return Future.error(StateError('probe $name is unavailable'));
    }
    return Future.value(value);
  }

  @override
  Future<AndroidProbeInfo> androidInfo() => _answer('androidInfo', android);

  @override
  Future<IosProbeInfo> iosInfo() => _answer('iosInfo', ios);

  @override
  Future<InstallProbeInfo> installInfo() => _answer('installInfo', install);

  @override
  Future<bool> isRealDevice() => _answer('isRealDevice', realDevice);

  @override
  Future<bool> isJailBroken() => _answer('isJailBroken', jailBroken);

  @override
  Future<bool> isDeveloperModeEnabled() =>
      _answer('developerMode', developerMode);

  @override
  Future<bool> isUsbDebuggingEnabled() => _answer('usbDebugging', usbDebugging);

  @override
  Future<bool> pathExists(String path) async => existingPaths.contains(path);
}

/// Samsung Galaxy S23. Note `bootloader: unknown` — that is what a great many
/// modern retail phones report, and blocking on it alone was the module's
/// worst false positive.
const galaxyS23 = AndroidProbeInfo(
  brand: 'samsung',
  device: 'dm1q',
  model: 'SM-S911B',
  product: 'dm1qxeea',
  manufacturer: 'samsung',
  hardware: 'qcom',
  board: 'kalama',
  bootloader: 'unknown',
  fingerprint: 'samsung/dm1qxeea/dm1q:14/UP1A.231005.007/'
      'S911BXXU4CWL5:user/release-keys',
  tags: 'release-keys',
  type: 'user',
  supportedAbis: ['arm64-v8a', 'armeabi-v7a', 'armeabi'],
);

/// BlueStacks 5 with ARM translation: every `Build` field spoofed to a Pixel,
/// an ARM ABI advertised, `isPhysicalDevice` faked. Only the disk gives it up.
const spoofedBlueStacks = AndroidProbeInfo(
  brand: 'google',
  device: 'coral',
  model: 'Pixel 4 XL',
  product: 'coral',
  manufacturer: 'Google',
  hardware: 'qcom',
  board: 'coral',
  bootloader: 'unknown',
  fingerprint: 'google/coral/coral:11/RQ3A.211001.001/'
      '7641976:user/release-keys',
  tags: 'release-keys',
  type: 'user',
  supportedAbis: ['arm64-v8a', 'armeabi-v7a'],
);

/// Stock Android Studio emulator image.
const aospEmulator = AndroidProbeInfo(
  brand: 'google',
  device: 'emu64a',
  model: 'sdk_gphone64_arm64',
  product: 'sdk_gphone64_arm64',
  manufacturer: 'Google',
  hardware: 'ranchu',
  board: 'goldfish_arm64',
  bootloader: 'unknown',
  fingerprint: 'google/sdk_gphone64_arm64/emu64a:14/UE1A.230829.036/'
      '11228894:user/release-keys',
  tags: 'release-keys',
  type: 'user',
  supportedAbis: ['arm64-v8a'],
  isPhysicalDevice: false,
);

/// Asus Zenfone 2: a genuine retail phone with an Intel Atom, x86 only.
const intelZenfone = AndroidProbeInfo(
  brand: 'asus',
  device: 'Z00A',
  model: 'ASUS_Z00AD',
  product: 'WW_Z00A',
  manufacturer: 'asus',
  hardware: 'intel',
  board: 'moorefield',
  bootloader: 'unknown',
  fingerprint: 'asus/WW_Z00A/Z00A:6.0.1/MMB29P/'
      'WW_user_4.21.40.184:user/release-keys',
  tags: 'release-keys',
  type: 'user',
  supportedAbis: ['x86'],
);

/// Test config helper. `allowDebugBuilds` must be off: `flutter test` runs in
/// debug mode, so the default would bypass every check.
DeviceIntegrityConfig configFor(
  DeviceProbe probe, {
  bool blockDeveloperMode = false,
  bool blockUsbDebugging = false,
  bool blockTamperedInstalls = false,
  int blockThreshold = 100,
  Set<String> ignoredSignals = const {},
  Map<String, SignalWeight> signalWeights = const {},
  Set<String> expectedSignatures = const {},
  Duration probeTimeout = const Duration(seconds: 5),
  bool Function()? bypass,
  void Function(DeviceIntegrityResult)? onBlocked,
  ProbeErrorReporter? onProbeError,
}) =>
    DeviceIntegrityConfig(
      probe: probe,
      allowDebugBuilds: false,
      bypass: bypass,
      blockDeveloperMode: blockDeveloperMode,
      blockUsbDebugging: blockUsbDebugging,
      blockTamperedInstalls: blockTamperedInstalls,
      blockThreshold: blockThreshold,
      ignoredSignals: ignoredSignals,
      signalWeights: signalWeights,
      expectedSignatures: expectedSignatures,
      probeTimeout: probeTimeout,
      onBlocked: onBlocked,
      onProbeError: onProbeError,
    );

Future<DeviceIntegrityResult> evaluateWith(DeviceIntegrityConfig config) {
  DeviceIntegrity.configure(config);
  return DeviceIntegrity.evaluate();
}

void main() {
  tearDown(() {
    DeviceIntegrity.configure(const DeviceIntegrityConfig());
  });

  group('genuine devices are not blocked', () {
    test('a Galaxy S23 reporting bootloader:unknown is allowed', () async {
      final result = await evaluateWith(
        configFor(FakeDeviceProbe(android: galaxyS23)),
      );

      expect(result.isAllowed, isTrue);
      // The signal still fires — it is just not enough on its own.
      expect(result.signals, contains('bootloader:unknown'));
    });

    test('an Intel x86-only retail phone is allowed', () async {
      final result = await evaluateWith(
        configFor(FakeDeviceProbe(android: intelZenfone)),
      );

      expect(result.isAllowed, isTrue,
          reason: 'hardware:intel + bootloader:unknown + abi:x86 = 90 < 100');
      expect(result.signals, containsAll(['hardware:intel', 'abi:x86']));
    });

    test('safe_device alone reporting "not real" does not block', () async {
      // safe_device swallows its own channel errors and answers `false`, so a
      // plugin that failed to register looks exactly like an emulator. If that
      // blocked on its own, one bad build would lock out every user.
      final result = await evaluateWith(
        configFor(FakeDeviceProbe(android: galaxyS23, realDevice: false)),
      );

      expect(result.isAllowed, isTrue);
      expect(result.signals, contains('safe_device:emulator'));
    });

    test('three weak signals stay under the threshold', () async {
      final result = await evaluateWith(
        configFor(FakeDeviceProbe(
          android: const AndroidProbeInfo(
            brand: 'blu',
            manufacturer: 'unknown',
            hardware: 'intel',
            bootloader: 'unknown',
            supportedAbis: ['arm64-v8a'],
          ),
        )),
      );

      expect(result.isAllowed, isTrue);
      expect(result.evidence.length, 3);
    });
  });

  group('emulators are blocked', () {
    test('BlueStacks is caught by its disk fingerprint alone', () async {
      final result = await evaluateWith(
        configFor(FakeDeviceProbe(
          android: spoofedBlueStacks,
          existingPaths: const {'/data/bluestacks.prop'},
        )),
      );

      expect(result.reason, DeviceBlockReason.emulator);
      expect(result.signals, contains('file:bluestacks'));
    });

    test('the AOSP emulator is caught by its build name', () async {
      final result = await evaluateWith(
        configFor(FakeDeviceProbe(android: aospEmulator, realDevice: false)),
      );

      expect(result.reason, DeviceBlockReason.emulator);
      expect(result.signals, contains('build:ranchu'));
    });

    test('two strong signals block where one would not', () async {
      final result = await evaluateWith(
        configFor(FakeDeviceProbe(
          android: const AndroidProbeInfo(
            brand: 'samsung',
            manufacturer: 'samsung',
            hardware: 'qcom',
            bootloader: 'G991BXXU5CVK1',
            supportedAbis: ['arm64-v8a'],
            isPhysicalDevice: false,
          ),
          realDevice: false,
        )),
      );

      expect(result.reason, DeviceBlockReason.emulator);
      expect(result.score, 120);
    });

    test('Windows Subsystem for Android is an unsupported platform', () async {
      final result = await evaluateWith(
        configFor(FakeDeviceProbe(
          android: const AndroidProbeInfo(
            brand: 'Windows',
            manufacturer: 'Microsoft Corporation',
            model: 'Subsystem for Android(TM)',
            supportedAbis: ['arm64-v8a'],
          ),
        )),
      );

      expect(result.reason, DeviceBlockReason.unsupportedPlatform);
      expect(result.signals, contains('wsa:brand'));
    });
  });

  group('a failing probe does not open the gate', () {
    test('evidence already collected still blocks', () async {
      // The regression this guards: wrapping the whole evaluation in one
      // `try` meant a single throwing channel discarded `file:bluestacks`
      // and allowed the device.
      final errors = <String>[];
      final result = await evaluateWith(
        configFor(
          FakeDeviceProbe(
            android: spoofedBlueStacks,
            existingPaths: const {'/data/bluestacks.prop'},
            failing: const {'isRealDevice'},
          ),
          onProbeError: (probe, _, __) => errors.add(probe),
        ),
      );

      expect(result.reason, DeviceBlockReason.emulator);
      expect(errors, contains('isRealDevice'));
    });

    test('a hanging probe times out without stalling or allowing', () async {
      final result = await evaluateWith(
        configFor(
          FakeDeviceProbe(
            android: spoofedBlueStacks,
            existingPaths: const {'/data/bluestacks.prop'},
            hanging: const {'androidInfo', 'isRealDevice'},
          ),
          probeTimeout: const Duration(milliseconds: 50),
        ),
      );

      expect(result.reason, DeviceBlockReason.emulator);
      expect(result.signals, contains('file:bluestacks'));
    });

    test('every probe failing on a clean device allows', () async {
      final result = await evaluateWith(
        configFor(FakeDeviceProbe(
          android: galaxyS23,
          failing: const {
            'androidInfo',
            'isRealDevice',
            'isJailBroken',
            'developerMode',
          },
        )),
      );

      expect(result.isAllowed, isTrue);
    });
  });

  group('compromised devices', () {
    test('the native root verdict blocks on its own', () async {
      final result = await evaluateWith(
        configFor(FakeDeviceProbe(android: galaxyS23, jailBroken: true)),
      );

      expect(result.reason, DeviceBlockReason.compromised);
      expect(result.signals, contains('safe_device:rooted'));
    });

    test('test-keys alone is not enough', () async {
      final result = await evaluateWith(
        configFor(FakeDeviceProbe(
          android: const AndroidProbeInfo(
            brand: 'itel',
            manufacturer: 'itel',
            hardware: 'mt6580',
            bootloader: 'unknown',
            tags: 'test-keys',
            type: 'user',
            supportedAbis: ['armeabi-v7a'],
          ),
        )),
      );

      expect(result.isAllowed, isTrue);
      expect(result.signals, contains('build:test-keys'));
    });

    test('test-keys plus a userdebug build blocks', () async {
      final result = await evaluateWith(
        configFor(FakeDeviceProbe(
          android: const AndroidProbeInfo(
            brand: 'itel',
            manufacturer: 'itel',
            hardware: 'mt6580',
            tags: 'test-keys',
            type: 'userdebug',
            supportedAbis: ['armeabi-v7a'],
          ),
        )),
      );

      expect(result.reason, DeviceBlockReason.compromised);
    });
  });

  group('developer options', () {
    test('are allowed by default', () async {
      final result = await evaluateWith(
        configFor(FakeDeviceProbe(android: galaxyS23, developerMode: true)),
      );

      expect(result.isAllowed, isTrue);
    });

    test('block once the host opts in', () async {
      final result = await evaluateWith(
        configFor(
          FakeDeviceProbe(android: galaxyS23, developerMode: true),
          blockDeveloperMode: true,
        ),
      );

      expect(result.reason, DeviceBlockReason.developerMode);
      expect(result.signals, contains('developer-options'));
    });
  });

  group('tuning', () {
    test('a trailing colon retires a whole signal category', () async {
      final result = await evaluateWith(
        configFor(
          FakeDeviceProbe(
            android: spoofedBlueStacks,
            existingPaths: const {'/data/bluestacks.prop'},
          ),
          ignoredSignals: const {'file:'},
        ),
      );

      expect(result.isAllowed, isTrue);
      expect(result.signals, isNot(contains('file:bluestacks')));
    });

    test('lowering the threshold makes one strong signal enough', () async {
      final result = await evaluateWith(
        configFor(
          FakeDeviceProbe(android: galaxyS23, realDevice: false),
          blockThreshold: 60,
        ),
      );

      expect(result.reason, DeviceBlockReason.emulator);
    });

    test('a weight override promotes a weak signal', () async {
      final result = await evaluateWith(
        configFor(
          FakeDeviceProbe(android: galaxyS23),
          signalWeights: const {'bootloader:unknown': SignalWeight.conclusive},
        ),
      );

      expect(result.reason, DeviceBlockReason.emulator);
    });
  });

  group('app tampering', () {
    test('a signature mismatch blocks', () async {
      final result = await evaluateWith(
        configFor(
          FakeDeviceProbe(
            android: galaxyS23,
            install: const InstallProbeInfo(
              installerStore: 'com.android.vending',
              buildSignature: 'deadbeef',
            ),
          ),
          blockTamperedInstalls: true,
          expectedSignatures: const {'CAFEBABE'},
        ),
      );

      expect(result.reason, DeviceBlockReason.tampered);
      expect(result.signals, contains('signature:mismatch'));
    });

    test('a matching signature from Play is allowed', () async {
      final result = await evaluateWith(
        configFor(
          FakeDeviceProbe(
            android: galaxyS23,
            install: const InstallProbeInfo(
              installerStore: 'com.android.vending',
              buildSignature: 'CAFEBABE',
            ),
          ),
          blockTamperedInstalls: true,
          expectedSignatures: const {'cafebabe'},
        ),
      );

      expect(result.isAllowed, isTrue);
    });

    test('sideloading alone corroborates but does not convict', () async {
      final result = await evaluateWith(
        configFor(
          FakeDeviceProbe(
            android: galaxyS23,
            install: const InstallProbeInfo(),
          ),
          blockTamperedInstalls: true,
        ),
      );

      expect(result.isAllowed, isTrue);
      expect(result.signals, contains('installer:none'));
    });

    test('sideloading plus a bad signature blocks', () async {
      final result = await evaluateWith(
        configFor(
          FakeDeviceProbe(
            android: galaxyS23,
            install: const InstallProbeInfo(buildSignature: 'deadbeef'),
          ),
          blockTamperedInstalls: true,
          expectedSignatures: const {'cafebabe'},
        ),
      );

      expect(result.reason, DeviceBlockReason.tampered);
      expect(result.score, 160);
    });

    test('the check is off unless the host asks for it', () async {
      final result = await evaluateWith(
        configFor(FakeDeviceProbe(
          android: galaxyS23,
          install: const InstallProbeInfo(installerStore: 'com.shady.market'),
        )),
      );

      expect(result.isAllowed, isTrue);
      expect(
        result.signals.where((s) => s.startsWith('installer:')),
        isEmpty,
        reason: 'the installer is not even probed while the check is off',
      );
    });
  });

  group('iOS', () {
    FakeDeviceProbe iosProbe({
      IosProbeInfo ios = const IosProbeInfo(
        model: 'iPhone',
        machine: 'iPhone15,3',
      ),
      bool jailBroken = false,
      Set<String> existingPaths = const {},
      Map<String, String> environment = const {},
    }) =>
        FakeDeviceProbe(
          isAndroid: false,
          isIOS: true,
          operatingSystem: 'ios',
          ios: ios,
          jailBroken: jailBroken,
          existingPaths: existingPaths,
          environment: environment,
        );

    test('a real iPhone is allowed', () async {
      final result = await evaluateWith(configFor(iosProbe()));

      expect(result.isAllowed, isTrue);
      expect(result.signals, isEmpty);
    });

    test('the Simulator is blocked', () async {
      final result = await evaluateWith(
        configFor(iosProbe(
          ios: const IosProbeInfo(
            model: 'iPhone',
            machine: 'arm64',
            isPhysicalDevice: false,
          ),
        )),
      );

      expect(result.reason, DeviceBlockReason.emulator);
      expect(result.signals, contains('ios:machine-arm64'));
    });

    test('SIMULATOR_DEVICE_NAME blocks on its own', () async {
      final result = await evaluateWith(
        configFor(iosProbe(
          environment: const {'SIMULATOR_DEVICE_NAME': 'iPhone 15'},
        )),
      );

      expect(result.reason, DeviceBlockReason.emulator);
    });

    test('a jailbreak artifact blocks', () async {
      final result = await evaluateWith(
        configFor(iosProbe(existingPaths: const {'/Applications/Cydia.app'})),
      );

      expect(result.reason, DeviceBlockReason.compromised);
      expect(result.signals, contains('file:cydia'));
    });

    test('an iPad app on Apple Silicon macOS is an unsupported platform',
        () async {
      final result = await evaluateWith(
        configFor(iosProbe(
          ios: const IosProbeInfo(
            model: 'iPad',
            machine: 'arm64',
            isAppOnMac: true,
          ),
        )),
      );

      expect(result.reason, DeviceBlockReason.unsupportedPlatform);
      expect(result.signals, contains('ios:app-on-mac'));
    });
  });

  group('platforms outside scope', () {
    test('a desktop build is refused by name', () async {
      final result = await evaluateWith(
        configFor(FakeDeviceProbe(
          isAndroid: false,
          isIOS: false,
          operatingSystem: 'windows',
        )),
      );

      expect(result.reason, DeviceBlockReason.unsupportedPlatform);
      expect(result.signals, contains('platform:windows'));
    });
  });

  group('caching and reporting', () {
    test('a repeated block is reported once, not once per resume', () async {
      final blocks = <DeviceIntegrityResult>[];
      DeviceIntegrity.configure(configFor(
        FakeDeviceProbe(
          android: spoofedBlueStacks,
          existingPaths: const {'/data/bluestacks.prop'},
        ),
        onBlocked: blocks.add,
      ));

      await DeviceIntegrity.evaluate();
      await DeviceIntegrity.evaluate(force: true);
      await DeviceIntegrity.evaluate(force: true, deep: true);

      expect(blocks.length, 1);
    });

    test('concurrent callers share one evaluation', () async {
      var probeCalls = 0;
      final probe = _CountingProbe(() => probeCalls++);
      DeviceIntegrity.configure(configFor(probe));

      await Future.wait([
        DeviceIntegrity.evaluate(),
        DeviceIntegrity.evaluate(),
        DeviceIntegrity.evaluate(),
      ]);

      expect(probeCalls, 1, reason: 'main() and the gate must not both probe');
    });

    test('a bypassed user still gets the device evaluated', () async {
      // The cache must describe the hardware, not the person holding it.
      // Short-circuiting on the bypass meant a reviewer's `allowed` verdict
      // survived their sign-out and left the gate open on an emulator.
      final blocks = <DeviceIntegrityResult>[];
      final result = await evaluateWith(configFor(
        FakeDeviceProbe(
          android: spoofedBlueStacks,
          existingPaths: const {'/data/bluestacks.prop'},
        ),
        bypass: () => true,
        onBlocked: blocks.add,
      ));

      expect(result.reason, DeviceBlockReason.emulator);
      expect(DeviceIntegrity.lastResult?.isAllowed, isFalse);
      expect(DeviceIntegrity.verdict?.isAllowed, isTrue,
          reason: 'the exempt user still passes');
      expect(blocks, isEmpty,
          reason: 'an exempt build must not fill the dashboard');
    });

    test('verdict follows the bypass without re-probing', () async {
      var reviewer = true;
      await evaluateWith(configFor(
        FakeDeviceProbe(
          android: spoofedBlueStacks,
          existingPaths: const {'/data/bluestacks.prop'},
        ),
        bypass: () => reviewer,
      ));

      expect(DeviceIntegrity.verdict?.isAllowed, isTrue);

      reviewer = false;
      expect(DeviceIntegrity.verdict?.reason, DeviceBlockReason.emulator);
    });

    test('configure drops the cached verdict', () async {
      await evaluateWith(configFor(FakeDeviceProbe(android: galaxyS23)));
      expect(DeviceIntegrity.lastResult, isNotNull);

      DeviceIntegrity.configure(const DeviceIntegrityConfig());
      expect(DeviceIntegrity.lastResult, isNull);
    });
  });

  group('reference string', () {
    test('carries the reason, the score and every signal', () async {
      final result = await evaluateWith(
        configFor(FakeDeviceProbe(android: aospEmulator, realDevice: false)),
      );

      expect(result.reference, startsWith('emulator['));
      expect(result.reference, contains('build:ranchu'));
    });

    test('a clean pass reads as its reason name', () {
      expect(const DeviceIntegrityResult.allowed().reference, 'none');
    });
  });
}

/// Counts how many times the engine actually reaches the platform.
class _CountingProbe extends FakeDeviceProbe {
  _CountingProbe(this.onProbe) : super(android: galaxyS23);

  final void Function() onProbe;

  @override
  Future<AndroidProbeInfo> androidInfo() {
    onProbe();
    return Future.delayed(
      const Duration(milliseconds: 20),
      () => android,
    );
  }
}
