import 'device_fingerprints.dart';
import 'device_integrity_result.dart';
import 'device_probe.dart';
import 'device_signal.dart';

/// Reports a probe that could not answer, e.g. a missing platform channel.
///
/// Worth wiring to Crashlytics: the engine fails *open* on a probe error, so a
/// sudden spike here is either a broken build or somebody hooking the checks.
typedef ProbeErrorReporter = void Function(
  String probe,
  Object error,
  StackTrace stackTrace,
);

/// Host-app policy for `DeviceIntegrity`.
///
/// The detection engine itself knows nothing about the app it protects — every
/// product decision (what to block, how confident to be, who may skip the
/// check, where to report) is expressed here and injected via
/// `DeviceIntegrity.configure`.
class DeviceIntegrityConfig {
  const DeviceIntegrityConfig({
    this.blockEmulators = true,
    this.blockCompromisedDevices = true,
    this.blockTamperedInstalls = false,
    this.blockDeveloperMode = false,
    this.blockUsbDebugging = false,
    this.allowDebugBuilds = true,
    // Literal rather than SignalWeight.conclusive.points: enum field access is
    // not const-evaluable in a default value.
    this.blockThreshold = 100,
    this.probeTimeout = const Duration(seconds: 5),
    this.evaluationTimeout = const Duration(seconds: 10),
    this.probe,
    this.bypass,
    this.ignoredSignals = const {},
    this.ignoreSignal,
    this.signalWeights = const {},
    this.extraEmulatorArtifacts = const {},
    this.extraRootArtifacts = const {},
    this.extraJailbreakArtifacts = const {},
    this.expectedSignatures = const {},
    this.allowedInstallerStores = DeviceFingerprints.trustedInstallerStores,
    this.onBlocked,
    this.onEvaluated,
    this.onProbeError,
  });

  /// Refuse emulators, virtual machines and Android app players.
  final bool blockEmulators;

  /// Refuse rooted / jailbroken devices and non-retail (`test-keys`) builds.
  final bool blockCompromisedDevices;

  /// Refuse builds that were sideloaded or re-signed.
  ///
  /// Off by default because it needs configuring: without
  /// [expectedSignatures] only the installer store is checked, and on iOS
  /// `installerStore` is frequently unreported even for a legitimate App Store
  /// install. Turn it on for Android once you have pinned your signature.
  final bool blockTamperedInstalls;

  /// Refuse Android devices with developer options switched on.
  ///
  /// **Off by default.** It is the strictest flag and it fires on a large slice
  /// of ordinary users — anyone who followed a YouTube tutorial or had their
  /// phone serviced. Turn it on only if you have measured the cost first via
  /// [onEvaluated].
  final bool blockDeveloperMode;

  /// Refuse Android devices with USB debugging switched on.
  /// Ignored unless [blockDeveloperMode] is also true.
  final bool blockUsbDebugging;

  /// Never block a debug build. Keep this on or you cannot run the app on an
  /// emulator while developing it.
  ///
  /// The checks still run and the verdict is still cached — only the block and
  /// the reporting are suppressed. See `DeviceIntegrity.isBypassed`.
  final bool allowDebugBuilds;

  /// Points a category has to accumulate before the app is actually blocked.
  ///
  /// Defaults to [SignalWeight.conclusive] (100), i.e. one conclusive signal,
  /// two strong ones, or one strong plus two weak. Raise it to be more
  /// forgiving, lower it to make a single strong signal enough.
  final int blockThreshold;

  /// Ceiling on a single probe. A channel that never answers contributes
  /// nothing instead of stalling the check.
  ///
  /// `main()` awaits the first evaluation before `runApp`, so an unbounded
  /// wait here would mean an app that never starts.
  final Duration probeTimeout;

  /// Ceiling on the whole evaluation. Every probe is already bounded by
  /// [probeTimeout], so this only catches a pathological engine bug.
  final Duration evaluationTimeout;

  /// Source of platform facts. Defaults to [PlatformDeviceProbe]; override in
  /// tests, or to add attestation of your own.
  final DeviceProbe? probe;

  /// Extra escape hatch, re-read on **every gate rebuild** — not just once at
  /// start-up. Point it at whatever the sign-in response told you:
  ///
  /// ```dart
  /// bypass: () => session.user?.isReviewer ?? false,
  /// ```
  ///
  /// Store reviewers run the app on emulators, so a released app almost always
  /// needs one. Because it is re-read rather than cached, flipping it after
  /// login opens or closes the gate without re-probing the device.
  ///
  /// Keep in mind this is the module's weakest link: a local boolean is
  /// trivially flipped on exactly the compromised devices being blocked. Back
  /// it with a server-issued, short-lived token if the content is worth it.
  final bool Function()? bypass;

  /// Signals to treat as harmless, e.g. `{'hardware:intel'}`.
  ///
  /// An entry ending in `:` retires a whole category — `{'abi:'}` ignores
  /// `abi:x86_64+x86` and every other ABI signal without you having to guess
  /// the exact string.
  final Set<String> ignoredSignals;

  /// Arbitrary predicate, checked in addition to [ignoredSignals].
  final bool Function(String signalId)? ignoreSignal;

  /// Re-weight signals without editing the module.
  ///
  /// Keyed by exact id (`'bootloader:unknown'`) or by category prefix
  /// (`'abi:'`). Use it to promote a signal you trust on your own user base,
  /// or demote one that keeps false-positiving.
  final Map<String, SignalWeight> signalWeights;

  /// Additional emulator file fingerprints, merged over the built-in table.
  /// Keys are absolute paths, values are the label used in the signal string.
  final Map<String, String> extraEmulatorArtifacts;

  /// Additional root file fingerprints, merged over the built-in table.
  final Map<String, String> extraRootArtifacts;

  /// Additional iOS jailbreak file fingerprints.
  final Map<String, String> extraJailbreakArtifacts;

  /// Lower-cased signing certificate SHAs this app may legitimately carry.
  /// Empty disables the signature half of the tamper check.
  final Set<String> expectedSignatures;

  /// Installer package names that count as a legitimate channel.
  final Set<String> allowedInstallerStores;

  /// Called when a verdict *blocks*, and only when the verdict changed —
  /// re-checks on resume will not re-report the same block.
  final void Function(DeviceIntegrityResult result)? onBlocked;

  /// Called for every changed verdict, pass or block. Wire this to analytics
  /// to see which signals fire in the field, and how close to the threshold
  /// real devices get, *before* tightening anything.
  final void Function(DeviceIntegrityResult result)? onEvaluated;

  /// Called when a probe fails and the engine falls back to the safe answer.
  final ProbeErrorReporter? onProbeError;

  /// Whether a verdict of [reason] should actually stop the app.
  bool blocks(DeviceBlockReason reason) => switch (reason) {
        DeviceBlockReason.none => false,
        // A desktop or web build is never in scope for a mobile-only app.
        DeviceBlockReason.unsupportedPlatform => true,
        DeviceBlockReason.emulator => blockEmulators,
        DeviceBlockReason.compromised => blockCompromisedDevices,
        DeviceBlockReason.tampered => blockTamperedInstalls,
        DeviceBlockReason.developerMode => blockDeveloperMode,
      };

  /// Whether [signalId] has been retired by the host app.
  bool isIgnored(String signalId) {
    if (ignoredSignals.contains(signalId)) return true;
    final categoryKey = '${signalId.split(':').first}:';
    if (ignoredSignals.contains(categoryKey)) return true;
    return ignoreSignal?.call(signalId) ?? false;
  }

  /// Applies any [signalWeights] override to [signal].
  DeviceSignal weigh(DeviceSignal signal) {
    final override =
        signalWeights[signal.id] ?? signalWeights['${signal.category}:'];
    return override == null ? signal : signal.withWeight(override);
  }
}
