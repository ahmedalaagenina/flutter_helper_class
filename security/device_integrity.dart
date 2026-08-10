import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import 'device_fingerprints.dart';
import 'device_integrity_config.dart';
import 'device_integrity_result.dart';
import 'device_probe.dart';
import 'device_signal.dart';

/// Decides whether the app is allowed to run on the current device.
///
/// The rule it enforces: **real Android phones and real iPhones/iPads only.**
/// Everything else — Windows (natively, through Windows Subsystem for Android,
/// or through an Android app player), other desktops, web, emulators, VMs,
/// rooted and jailbroken devices — is refused.
///
/// Detection is layered on purpose. `safe_device` does the native root and
/// emulator work; on top of that this reads the raw Android build properties,
/// the supported ABIs, the system feature list and a set of on-disk
/// fingerprints, because the Windows app players people actually use
/// (BlueStacks, LDPlayer, Nox, MEmu) spoof just enough of `Build` to slip past
/// any single check.
///
/// **Signals are weighted, not counted.** Each one carries a [SignalWeight] and
/// a category only blocks once its surviving signals reach
/// [DeviceIntegrityConfig.blockThreshold]. `Build.BOOTLOADER == "unknown"` is
/// true on a great many retail phones and must not lock them out on its own;
/// `/data/bluestacks.prop` on disk can be trusted alone.
///
/// **Failure policy:** a probe that throws or hangs contributes *nothing* and
/// is reported through [DeviceIntegrityConfig.onProbeError] — it does not
/// discard the signals its siblings already found. That distinction matters:
/// wrapping the whole evaluation in one `try` means anyone who can make a
/// single platform channel fail can open the gate completely.
///
/// This class is app-agnostic; policy comes from [DeviceIntegrityConfig].
/// See `README.md` in this folder for wiring instructions.
abstract final class DeviceIntegrity {
  static DeviceIntegrityConfig _config = const DeviceIntegrityConfig();
  static DeviceIntegrityResult? _cached;
  static Future<DeviceIntegrityResult>? _inFlight;
  static String? _lastReported;

  /// Path -> exists. An emulator image does not grow a `/dev/qemu_pipe` while
  /// the app is running, so ~50 stat calls per re-check would be pure jank.
  /// Cleared by [reset], [configure] and `evaluate(deep: true)`.
  static final Map<String, bool> _pathCache = {};

  /// Active policy. Replace with [configure] before the first [evaluate].
  static DeviceIntegrityConfig get config => _config;

  /// What the checks concluded about **the device**, or `null` if [evaluate]
  /// has not run yet. Unaffected by [isBypassed].
  static DeviceIntegrityResult? get lastResult => _cached;

  /// What should happen to **this user, right now** — [lastResult] unless the
  /// build or the signed-in user is exempt.
  ///
  /// Read this, not [lastResult], when deciding whether to show the app. It is
  /// re-derived on every read, so a bypass that turns on or off after sign-in
  /// takes effect immediately without re-probing the device.
  static DeviceIntegrityResult? get verdict =>
      isBypassed ? const DeviceIntegrityResult.allowed() : _cached;

  static DeviceProbe get _probe => _config.probe ?? const PlatformDeviceProbe();

  /// Installs the host app's policy. Call once, from `main()`, before
  /// [evaluate]. Changing the config drops every cached value.
  static void configure(DeviceIntegrityConfig config) {
    _config = config;
    reset();
  }

  /// True when the current build or user is exempt from being *blocked*.
  ///
  /// Note "blocked", not "checked": the device is still evaluated and the real
  /// verdict still cached. Exempting the check itself would make the cache a
  /// statement about the current user rather than about the hardware, and a
  /// reviewer who signs out would keep an `allowed` verdict that was only ever
  /// true because they were exempt.
  static bool get isBypassed =>
      (_config.allowDebugBuilds && kDebugMode) ||
      (_config.bypass?.call() ?? false);

  /// Runs the device check.
  ///
  /// The result is cached after the first run. Pass [force] to recompute the
  /// cheap checks — the gate does this on resume, so someone who turns
  /// developer options off can continue without reinstalling. Pass [deep] to
  /// additionally re-scan the filesystem fingerprints, which the block
  /// screen's "check again" button does.
  ///
  /// Concurrent calls share one evaluation: `main()` and the gate's own
  /// start-up check cannot run the platform probes twice.
  static Future<DeviceIntegrityResult> evaluate({
    bool force = false,
    bool deep = false,
  }) async {
    if (!force && !deep && _cached != null) return _cached!;

    final pending = _inFlight;
    if (pending != null) return pending;

    if (deep) _pathCache.clear();

    final future = _run();
    _inFlight = future;
    try {
      final result = await future;
      _cached = result;
      _report(result);
      return result;
    } finally {
      _inFlight = null;
    }
  }

  /// Clears every cached value. Call between tests.
  static void reset() {
    _cached = null;
    _lastReported = null;
    _pathCache.clear();
  }

  /// Fires the host callbacks, but only when the verdict actually changed.
  /// Without this, `recheckOnResume` reports the same block on every resume
  /// and the telemetry you would tune the rules from is just a session count.
  static void _report(DeviceIntegrityResult result) {
    // An exempt build or user is not a verdict about anybody: reporting it
    // would fill the dashboard with developers' own emulators. Deliberately
    // before the de-duplication, so the same verdict is still reported later
    // if the exemption goes away.
    if (isBypassed) return;
    if (result.reference == _lastReported) return;
    _lastReported = result.reference;
    _config.onEvaluated?.call(result);
    if (result.isAllowed) return;
    if (kDebugMode) log('DeviceIntegrity blocked -> ${result.reference}');
    _config.onBlocked?.call(result);
  }

  static Future<DeviceIntegrityResult> _run() async {
    try {
      return await _evaluate().timeout(_config.evaluationTimeout);
    } catch (error, stackTrace) {
      // Belt and braces: individual probes are already guarded, so reaching
      // here means the engine itself misbehaved. Never lock a real user out.
      _config.onProbeError?.call('evaluate', error, stackTrace);
      return const DeviceIntegrityResult.allowed();
    }
  }

  static Future<DeviceIntegrityResult> _evaluate() async {
    // No bypass short-circuit: see [isBypassed]. The cache always describes
    // the device; who is allowed to ignore that is decided at render time.

    // A web build would be reachable from any desktop browser. Unreachable
    // with the stock probe (the module does not compile for web at all), but
    // it keeps the rule honest for a custom DeviceProbe.
    if (kIsWeb) {
      return _blocked(DeviceBlockReason.unsupportedPlatform, [
        const DeviceSignal('platform:web', SignalWeight.conclusive),
      ]);
    }

    final probe = _probe;

    // Desktop builds: Windows, macOS, Linux.
    if (!probe.isAndroid && !probe.isIOS) {
      return _blocked(DeviceBlockReason.unsupportedPlatform, [
        DeviceSignal('platform:${probe.operatingSystem}',
            SignalWeight.conclusive),
      ]);
    }

    return probe.isAndroid ? _evaluateAndroid(probe) : _evaluateIOS(probe);
  }

  ///-------------------///
  ///----Probe guard----///
  ///-------------------///

  /// Runs one probe in isolation. A throw, or a channel that never answers,
  /// yields `null` — the caller substitutes the *safe* value and every other
  /// signal in the same category survives.
  static Future<T?> _ask<T>(String name, Future<T> Function() body) async {
    try {
      return await body().timeout(_config.probeTimeout);
    } catch (error, stackTrace) {
      _config.onProbeError?.call(name, error, stackTrace);
      return null;
    }
  }

  ///-------------------///
  ///----Scoring--------///
  ///-------------------///

  /// Filters ignored signals, applies weight overrides, records what survived
  /// in [observed] and returns a verdict only once the score reaches the
  /// threshold. `null` means "not enough evidence, carry on checking".
  static DeviceIntegrityResult? _decide(
    DeviceBlockReason reason,
    List<DeviceSignal> signals,
    List<DeviceSignal> observed,
  ) {
    if (!_config.blocks(reason)) return null;

    final seen = <String>{};
    final kept = <DeviceSignal>[];
    for (final signal in signals) {
      if (_config.isIgnored(signal.id) || !seen.add(signal.id)) continue;
      kept.add(_config.weigh(signal));
    }
    if (kept.isEmpty) return null;

    observed.addAll(kept);
    final score = scoreOf(kept);
    if (score < _config.blockThreshold) return null;
    return DeviceIntegrityResult(reason, List.unmodifiable(kept), score: score);
  }

  /// Verdict for a category with no ambiguity to weigh up.
  static DeviceIntegrityResult _blocked(
    DeviceBlockReason reason,
    List<DeviceSignal> signals,
  ) {
    final observed = <DeviceSignal>[];
    return _decide(reason, signals, observed) ??
        DeviceIntegrityResult.allowed(List.unmodifiable(observed));
  }

  ///---------------///
  ///----Android----///
  ///---------------///

  static Future<DeviceIntegrityResult> _evaluateAndroid(DeviceProbe probe) async {
    final info = await _ask('androidInfo', probe.androidInfo);
    final observed = <DeviceSignal>[];

    // Windows Subsystem for Android identifies itself honestly, so check it
    // first and report it as an unsupported *platform*, not an emulator.
    if (info != null) {
      final windows = _decide(
        DeviceBlockReason.unsupportedPlatform,
        _windowsSubsystemSignals(info),
        observed,
      );
      if (windows != null) return windows;
    }

    if (_config.blockEmulators) {
      final verdict = _decide(
        DeviceBlockReason.emulator,
        [
          if (info != null) ..._androidBuildSignals(info),
          ...await _artifactSignals({
            ...DeviceFingerprints.emulatorArtifacts,
            ..._config.extraEmulatorArtifacts,
          }),
          if (info != null && !info.isPhysicalDevice)
            const DeviceSignal('build:not-physical', SignalWeight.strong),
          // `safe_device` reports "not real" when its own channel fails, so
          // this one must never block on its own.
          if (await _ask('isRealDevice', probe.isRealDevice) == false)
            const DeviceSignal('safe_device:emulator', SignalWeight.strong),
        ],
        observed,
      );
      if (verdict != null) return verdict;
    }

    if (_config.blockCompromisedDevices) {
      final tags = info?.tags.toLowerCase() ?? '';
      final type = info?.type.toLowerCase() ?? '';
      final verdict = _decide(
        DeviceBlockReason.compromised,
        [
          ...await _artifactSignals({
            ...DeviceFingerprints.rootArtifacts,
            ..._config.extraRootArtifacts,
          }),
          // Cheap retail hardware does occasionally ship a test-keys build, so
          // these corroborate rather than convict.
          if (tags.contains('test-keys'))
            const DeviceSignal('build:test-keys', SignalWeight.strong),
          if (DeviceFingerprints.nonRetailBuildTypes.contains(type))
            DeviceSignal('build:type-$type', SignalWeight.strong),
          // Purpose-built native check that returns `false` on error, so a
          // positive here is meaningful on its own.
          if (await _ask('isJailBroken', probe.isJailBroken) ?? false)
            const DeviceSignal('safe_device:rooted', SignalWeight.conclusive),
        ],
        observed,
      );
      if (verdict != null) return verdict;
    }

    final tampered = await _tamperVerdict(probe, observed);
    if (tampered != null) return tampered;

    if (_config.blockDeveloperMode) {
      final verdict = _decide(
        DeviceBlockReason.developerMode,
        [
          if (await _ask('developerMode', probe.isDeveloperModeEnabled) ?? false)
            const DeviceSignal('developer-options', SignalWeight.conclusive),
          if (_config.blockUsbDebugging &&
              (await _ask('usbDebugging', probe.isUsbDebuggingEnabled) ?? false))
            const DeviceSignal('usb-debugging', SignalWeight.conclusive),
        ],
        observed,
      );
      if (verdict != null) return verdict;
    }

    return DeviceIntegrityResult.allowed(List.unmodifiable(observed));
  }

  /// Windows Subsystem for Android and Windows-hosted Android-x86 ports.
  static List<DeviceSignal> _windowsSubsystemSignals(AndroidProbeInfo info) {
    final brand = info.brand.toLowerCase();
    final model = info.model.toLowerCase();
    final manufacturer = info.manufacturer.toLowerCase();
    final device = info.device.toLowerCase();
    final product = info.product.toLowerCase();

    return [
      if (brand == 'windows')
        const DeviceSignal('wsa:brand', SignalWeight.conclusive),
      if (manufacturer.contains('microsoft'))
        const DeviceSignal('wsa:manufacturer', SignalWeight.conclusive),
      if (model.contains('subsystem for android'))
        const DeviceSignal('wsa:model', SignalWeight.conclusive),
      if (device.startsWith('windows') || product.startsWith('windows'))
        const DeviceSignal('wsa:device', SignalWeight.conclusive),
      if (info.systemFeatures
          .any((f) => f.toLowerCase().startsWith('com.microsoft.windows')))
        const DeviceSignal('wsa:feature', SignalWeight.conclusive),
    ];
  }

  /// Emulator fingerprints in `android.os.Build`.
  static List<DeviceSignal> _androidBuildSignals(AndroidProbeInfo info) {
    String lower(String v) => v.toLowerCase().trim();

    final brand = lower(info.brand);
    final device = lower(info.device);
    final product = lower(info.product);
    final manufacturer = lower(info.manufacturer);
    final hardware = lower(info.hardware);
    final board = lower(info.board);
    final bootloader = lower(info.bootloader);
    final fingerprint = lower(info.fingerprint);

    final haystack = [
      brand,
      device,
      lower(info.model),
      product,
      manufacturer,
      hardware,
      board,
      fingerprint,
    ].join('|');

    final signals = <DeviceSignal>[
      for (final name in DeviceFingerprints.emulatorNames)
        if (haystack.contains(name))
          DeviceSignal('build:$name', SignalWeight.conclusive),

      // Exact matches on the short fields, split by how much they prove.
      if (DeviceFingerprints.emulatorExactValues.contains(hardware))
        DeviceSignal('hardware:$hardware', SignalWeight.conclusive),
      if (DeviceFingerprints.ambiguousExactValues.contains(hardware))
        DeviceSignal('hardware:$hardware', SignalWeight.weak),
      if (DeviceFingerprints.emulatorExactValues.contains(board))
        DeviceSignal('board:$board', SignalWeight.conclusive),
      if (DeviceFingerprints.ambiguousExactValues.contains(board))
        DeviceSignal('board:$board', SignalWeight.weak),
      if (DeviceFingerprints.emulatorExactValues.contains(product) ||
          DeviceFingerprints.emulatorProducts.contains(product))
        DeviceSignal('product:$product', SignalWeight.conclusive),
      if (DeviceFingerprints.ambiguousExactValues.contains(product))
        DeviceSignal('product:$product', SignalWeight.weak),

      // Generic AOSP images.
      if (fingerprint.startsWith('generic'))
        const DeviceSignal('fingerprint:generic', SignalWeight.conclusive),
      if (fingerprint.startsWith('unknown'))
        const DeviceSignal('fingerprint:unknown', SignalWeight.weak),
      if (brand.startsWith('generic') && device.startsWith('generic'))
        const DeviceSignal('build:generic', SignalWeight.conclusive),

      // Both are common on genuine budget hardware and on Android 8+ ROMs that
      // stopped reporting a bootloader at all — corroboration only.
      if (manufacturer == 'unknown' || manufacturer.isEmpty)
        const DeviceSignal('manufacturer:unknown', SignalWeight.weak),
      if (bootloader == 'unknown')
        const DeviceSignal('bootloader:unknown', SignalWeight.weak),

      // App players advertise their own system features.
      if (info.systemFeatures
          .map(lower)
          .any((f) => f.contains('bluestacks') || f.contains('.bst.')))
        const DeviceSignal('feature:bluestacks', SignalWeight.conclusive),
    ];

    // An x86-only ABI list means an app player or a VM on a PC — but also a
    // Chrome OS device running Android apps, or an Intel Atom phone. It never
    // shows up alone on a real app player (they all trip a file or feature
    // fingerprint too), so it corroborates rather than convicts.
    final abis = info.supportedAbis.map(lower).toList();
    if (abis.isNotEmpty && !abis.any((a) => a.contains('arm'))) {
      signals.add(DeviceSignal('abi:${abis.join("+")}', SignalWeight.weak));
    }

    return signals;
  }

  ///-----------///
  ///----iOS----///
  ///-----------///

  static Future<DeviceIntegrityResult> _evaluateIOS(DeviceProbe probe) async {
    final info = await _ask('iosInfo', probe.iosInfo);
    final observed = <DeviceSignal>[];

    // "Designed for iPad" running on Apple Silicon macOS — a desktop.
    if (info != null && info.isAppOnMac) {
      final verdict = _decide(
        DeviceBlockReason.unsupportedPlatform,
        [const DeviceSignal('ios:app-on-mac', SignalWeight.conclusive)],
        observed,
      );
      if (verdict != null) return verdict;
    }

    if (_config.blockEmulators) {
      final machine = info?.machine.toLowerCase().trim() ?? '';
      final verdict = _decide(
        DeviceBlockReason.emulator,
        [
          if (info != null && !info.isPhysicalDevice)
            const DeviceSignal('ios:not-physical', SignalWeight.strong),
          if (probe.environment.containsKey('SIMULATOR_DEVICE_NAME'))
            const DeviceSignal('ios:simulator-env', SignalWeight.conclusive),
          if (info != null && info.model.toLowerCase().contains('simulator'))
            const DeviceSignal('ios:model-simulator', SignalWeight.conclusive),
          // Genuine hardware reports a model identifier (`iPhone14,5`); the
          // Simulator reports the host arch. Strong, not conclusive, so an
          // unreleased Apple prefix cannot lock out a whole new device line.
          if (machine.isNotEmpty &&
              !DeviceFingerprints.iosMachinePrefixes.any(machine.startsWith))
            DeviceSignal('ios:machine-$machine', SignalWeight.strong),
          if (await _ask('isRealDevice', probe.isRealDevice) == false)
            const DeviceSignal('safe_device:emulator', SignalWeight.strong),
        ],
        observed,
      );
      if (verdict != null) return verdict;
    }

    if (_config.blockCompromisedDevices) {
      final verdict = _decide(
        DeviceBlockReason.compromised,
        [
          ...await _artifactSignals({
            ...DeviceFingerprints.jailbreakArtifacts,
            ..._config.extraJailbreakArtifacts,
          }),
          if (await _ask('isJailBroken', probe.isJailBroken) ?? false)
            const DeviceSignal(
              'safe_device:jailbroken',
              SignalWeight.conclusive,
            ),
        ],
        observed,
      );
      if (verdict != null) return verdict;
    }

    final tampered = await _tamperVerdict(probe, observed);
    if (tampered != null) return tampered;

    return DeviceIntegrityResult.allowed(List.unmodifiable(observed));
  }

  ///-----------------///
  ///----App tamper---///
  ///-----------------///

  /// Where this build came from, rather than what it is running on.
  static Future<DeviceIntegrityResult?> _tamperVerdict(
    DeviceProbe probe,
    List<DeviceSignal> observed,
  ) async {
    if (!_config.blockTamperedInstalls) return null;

    final install = await _ask('installInfo', probe.installInfo);
    if (install == null) return null;

    final store = install.installerStore?.toLowerCase().trim() ?? '';
    final signature = install.buildSignature.toLowerCase().trim();
    final expected = _config.expectedSignatures;

    return _decide(
      DeviceBlockReason.tampered,
      [
        if (store.isEmpty)
          const DeviceSignal('installer:none', SignalWeight.strong)
        else if (!_config.allowedInstallerStores.any(store.contains))
          DeviceSignal('installer:$store', SignalWeight.strong),
        // Re-signing is unavoidable for a cracked build, so a mismatch is as
        // conclusive as evidence gets — but only when we know what to expect.
        if (expected.isNotEmpty &&
            signature.isNotEmpty &&
            !expected.map((s) => s.toLowerCase()).contains(signature))
          const DeviceSignal('signature:mismatch', SignalWeight.conclusive),
      ],
      observed,
    );
  }

  ///---------------------///
  ///----Disk artifacts---///
  ///---------------------///

  /// Presence of on-disk fingerprints, one label per hit.
  ///
  /// Async and cached: the old synchronous version ran ~50 blocking `stat`
  /// calls on the UI isolate every time the app was resumed.
  static Future<List<DeviceSignal>> _artifactSignals(
    Map<String, String> artifacts,
  ) async {
    final labels = <String>{};
    await Future.wait(
      artifacts.entries.map((entry) async {
        if (await _exists(entry.key)) labels.add(entry.value);
      }),
    );
    return [
      for (final label in labels)
        DeviceSignal('file:$label', SignalWeight.conclusive),
    ];
  }

  static Future<bool> _exists(String path) async {
    final cached = _pathCache[path];
    if (cached != null) return cached;
    // Not routed through _ask: a denied path is the normal case on modern
    // Android and reporting it would drown out real probe failures.
    var present = false;
    try {
      present = await _probe.pathExists(path).timeout(_config.probeTimeout);
    } catch (_) {
      // Unreadable path — indistinguishable from absent, and treated as such.
    }
    _pathCache[path] = present;
    return present;
  }
}
