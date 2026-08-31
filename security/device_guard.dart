import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:scio_phile/config/db_shared.dart';
import 'package:scio_phile/config/security/device_signals.dart';
import 'package:scio_phile/config/utils/collections.dart';

export 'package:scio_phile/config/security/device_signals.dart'
    show DeviceBlockReason;

/// One check's outcome. [signals] is the raw evidence, and the unit the remote
/// policy retires false positives by — so those strings are part of the
/// contract, not debug text.
@immutable
class DeviceVerdict {
  const DeviceVerdict(this.reason, this.signals);
  const DeviceVerdict.allowed()
      : reason = DeviceBlockReason.none,
        signals = const [];

  final DeviceBlockReason reason;
  final List<String> signals;

  bool get isAllowed => reason == DeviceBlockReason.none;

  /// Short code for support tickets, e.g. `emulator-3f2a1b`. FNV-1a rather than
  /// `hashCode`, which is only stable inside a single run.
  String get reference {
    if (isAllowed) return 'ok';
    var h = 0x811c9dc5;
    for (final c in signals.join('|').codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
    }
    return '${reason.name}-${h.toRadixString(16)}';
  }

  /// Value equality so the gate's notifier skips a rebuild on an unchanged
  /// re-check — every resume produces a new object.
  @override
  bool operator ==(Object other) =>
      other is DeviceVerdict &&
      other.reason == reason &&
      listEquals(other.signals, signals);

  @override
  int get hashCode => Object.hash(reason, Object.hashAll(signals));

  @override
  String toString() => '${reason.name}(${signals.join(",")})';
}

/// What the check is allowed to block.
///
/// The field defaults below are the policy the app ships with and falls back on
/// whenever no other source is available — see [defaults]. A `security/policy`
/// document in Firestore is a *control layer on top of them*, never a
/// prerequisite: it overrides the fields it names and leaves the rest as built.
/// See README.md.
@immutable
class SecurityPolicy {
  const SecurityPolicy({
    this.enabled = true,
    this.blockUnsupportedPlatform = true,
    this.blockEmulator = true,
    this.blockRoot = true,
    // The one pair that ships off. Developer options and USB debugging get
    // switched on by ordinary students on ordinary phones — they locked out a
    // genuine TECNO handset during testing. They are real signals, just not
    // ones worth a lockout without evidence; turn them on from Firestore if you
    // ever decide the trade is worth it.
    this.blockDeveloperMode = false,
    this.blockUsbDebugging = false,
    this.allowedSignals = const {},
    this.allowedUids = const {},
  });

  /// Master kill switch — the lever to pull for a store review window.
  final bool enabled;
  final bool blockUnsupportedPlatform;
  final bool blockEmulator;
  final bool blockRoot;

  /// Highest false-positive risk of the set: a student who once enabled
  /// developer options is caught by it. First field to turn off if support
  /// tickets start arriving.
  final bool blockDeveloperMode;
  final bool blockUsbDebugging;

  /// Individual signals to treat as harmless, e.g. `{'build:not-physical'}` —
  /// retires one false positive without switching a whole category off.
  final Set<String> allowedSignals;

  /// Accounts exempt from every check. Only usable after sign-in, so it
  /// complements [enabled] rather than replacing it.
  final Set<String> allowedUids;

  /// The policy compiled into the binary. In force before the first fetch, when
  /// Firestore holds no policy document at all, and when that document is
  /// deleted — so the device is always checked, backend or no backend.
  ///
  /// Covers what can be detected with near-zero false positives on a genuine
  /// phone: unsupported platforms, emulators and Android app players, and
  /// rooted/jailbroken devices.
  static const SecurityPolicy defaults = SecurityPolicy();

  bool blocks(DeviceBlockReason reason) => switch (reason) {
        DeviceBlockReason.none => false,
        DeviceBlockReason.unsupportedPlatform => blockUnsupportedPlatform,
        DeviceBlockReason.emulator => blockEmulator,
        DeviceBlockReason.compromised => blockRoot,
        DeviceBlockReason.developerMode => blockDeveloperMode,
        DeviceBlockReason.usbDebugging => blockUsbDebugging,
      };

  /// Overlays a policy document onto [defaults]: a field the document names
  /// wins, a field it omits or misspells keeps the compiled-in value. A partial
  /// document is therefore a targeted override rather than a silent reset, and a
  /// typo degrades to shipped behaviour rather than to no protection at all.
  factory SecurityPolicy.fromMap(Map<String, dynamic> map) {
    bool flag(String key, bool fallback) =>
        map[key] is bool ? map[key] as bool : fallback;
    Set<String> list(String key) => map[key] is List
        ? (map[key] as List).whereType<String>().toSet()
        : const {};
    return SecurityPolicy(
      enabled: flag('enabled', defaults.enabled),
      blockUnsupportedPlatform:
          flag('blockUnsupportedPlatform', defaults.blockUnsupportedPlatform),
      blockEmulator: flag('blockEmulator', defaults.blockEmulator),
      blockRoot: flag('blockRoot', defaults.blockRoot),
      blockDeveloperMode:
          flag('blockDeveloperMode', defaults.blockDeveloperMode),
      blockUsbDebugging:
          flag('blockUsbDebugging', defaults.blockUsbDebugging),
      allowedSignals: list('allowedSignals'),
      allowedUids: list('allowedUids'),
    );
  }
}

/// Decides whether the app may run here, and republishes the verdict whenever
/// the device or the policy changes.
///
/// **Self-contained, and fail-open.** Two separate properties, and conflating
/// them is what made the previous attempt lock out genuine phones:
///
/// * *Self-contained* — the device is checked against [SecurityPolicy.defaults]
///   with no backend of any kind. Firestore only ever *adjusts* which checks
///   run; its absence is not a failure and does not change the outcome.
/// * *Fail-open* — a channel error or a timeout inside the check itself
///   resolves to "allowed" and is recorded. A bug in the detector must never
///   cost a student access.
///
/// What the defaults leave out is the one pair with real false-positive risk on
/// genuine hardware; see [SecurityPolicy].
abstract final class DeviceGuard {
  /// The gate listens to this, so a policy that lands a second after launch
  /// still takes effect in the same session.
  static final ValueNotifier<DeviceVerdict> verdict =
      ValueNotifier<DeviceVerdict>(const DeviceVerdict.allowed());

  static SecurityPolicy _policy = SecurityPolicy.defaults;
  static DeviceSignals? _signals;
  static Future<void>? _inFlight;

  static SecurityPolicy get policy => _policy;
  static bool get isBlocked => !verdict.value.isAllowed;

  /// First check. Call from `main()` before `runApp`.
  ///
  /// Uses the *cached* policy so nothing waits on the network before the first
  /// frame; the live one is fetched afterwards and applied to the verdict
  /// without re-reading the device.
  static Future<void> start({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    _policy = _PolicyStore.cached();
    await evaluate(timeout: timeout);
    refreshPolicy(); // deliberately not awaited — startup must not wait on it
  }

  /// Re-reads the device. Concurrent calls share one run, so a resume and the
  /// retry button cannot double every platform-channel round trip.
  static Future<void> evaluate({
    Duration timeout = const Duration(seconds: 5),
  }) =>
      _inFlight ??= _evaluate(timeout).whenComplete(() => _inFlight = null);

  /// Pulls the live policy and re-decides.
  static Future<void> refreshPolicy() async {
    final fresh = await _PolicyStore.fetchIfChanged();
    if (fresh == null) return;
    _policy = fresh;
    log('DeviceGuard: policy updated (enabled: ${fresh.enabled})');
    reassess();
  }

  /// Re-decides from the evidence already in hand — no native calls. Use it
  /// when the policy or the signed-in user changed, not the hardware.
  static void reassess() {
    if (_isExempt) return _publish(const DeviceVerdict.allowed());
    final current = _signals;
    if (current == null) {
      evaluate();
      return;
    }
    _publish(_decide(current));
  }

  static Future<void> _evaluate(Duration timeout) async {
    if (_isExempt) return _publish(const DeviceVerdict.allowed());
    try {
      _signals = await DeviceSignalReader.read().timeout(timeout);
      log('DeviceGuard: $_signals');
      _publish(_decide(_signals!));
    } catch (e, s) {
      log('DeviceGuard: check failed, allowing -> $e');
      FirebaseCrashlytics.instance
          .recordError(e, s, reason: 'device_guard_failed', fatal: false);
      _publish(const DeviceVerdict.allowed());
    }
  }

  /// Order matters: the debug build first (development never fights the guard),
  /// then the remote kill switch, then locally flagged testers, then the remote
  /// uid allowlist.
  static bool get _isExempt {
    if (kDebugMode) return true;
    if (!_policy.enabled) return true;
    if (SP.isStoreTest || SP.isDevTester) return true;
    if (SP.shPref == null) return false;
    final uid = SP.getUserId();
    return uid != null && _policy.allowedUids.contains(uid);
  }

  /// Reported in this order. An emulator is usually rooted too, so the emulator
  /// message wins — it is the accurate and actionable one.
  static const List<DeviceBlockReason> _precedence = [
    DeviceBlockReason.unsupportedPlatform,
    DeviceBlockReason.emulator,
    DeviceBlockReason.compromised,
    DeviceBlockReason.developerMode,
    DeviceBlockReason.usbDebugging,
  ];

  static DeviceVerdict _decide(DeviceSignals signals) {
    for (final reason in _precedence) {
      if (!_policy.blocks(reason)) continue;
      final kept = signals[reason]
          .where((s) => !_policy.allowedSignals.contains(s))
          .toList();
      if (kept.isNotEmpty) return DeviceVerdict(reason, kept);
    }
    return const DeviceVerdict.allowed();
  }

  static void _publish(DeviceVerdict next) {
    if (verdict.value == next) return;
    verdict.value = next;
    if (next.isAllowed) return;
    // `recordError`, not `log`: Crashlytics breadcrumbs only surface attached to
    // a crash report, so a blocked session that never crashes would be
    // invisible — and the block rate is exactly the number needed to judge
    // whether `blockDeveloperMode` is costing real students.
    FirebaseCrashlytics.instance.recordError(
      'device_blocked ${next.reference}',
      null,
      reason: next.reason.name,
      information: next.signals,
      fatal: false,
    );
  }
}

/// Firestore-backed policy with a local copy.
///
/// The split matters for startup cost: [cached] is synchronous, so the gate can
/// decide before the first frame without waiting on the network.
abstract final class _PolicyStore {
  static const String _key = 'security_policy_v1';

  static SecurityPolicy cached() {
    final raw = SP.shPref?.getString(_key);
    if (raw == null) return SecurityPolicy.defaults;
    try {
      return SecurityPolicy.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      log('DeviceGuard: unreadable policy cache, using defaults -> $e');
      return SecurityPolicy.defaults;
    }
  }

  /// Returns the policy to switch to, or `null` to keep the current one.
  ///
  /// The three outcomes are deliberately distinct:
  ///
  /// * the document exists and differs from the cache → that policy, cached;
  /// * the read succeeded and the document is **absent** →
  ///   [SecurityPolicy.defaults] with the cache dropped, so deleting the
  ///   document reverts to shipped behaviour instead of stranding devices on a
  ///   policy that can no longer be revoked;
  /// * the read **failed** — offline, timeout, rules → `null`, because an
  ///   unreachable Firestore is evidence of nothing.
  static Future<SecurityPolicy?> fetchIfChanged({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(Coll.security)
          .doc('policy')
          .get()
          .timeout(timeout);
      final data = doc.data();
      if (data == null) {
        // Nothing cached means the defaults are already the policy in force.
        if (SP.shPref?.getString(_key) == null) return null;
        await SP.shPref?.remove(_key);
        log('DeviceGuard: no policy document, reverting to defaults');
        return SecurityPolicy.defaults;
      }
      // The encoded document stands in for value equality on SecurityPolicy —
      // it is what gets cached anyway.
      final encoded = jsonEncode(data);
      if (encoded == SP.shPref?.getString(_key)) return null;
      await SP.shPref?.setString(_key, encoded);
      return SecurityPolicy.fromMap(data);
    } catch (e) {
      log('DeviceGuard: policy fetch failed, keeping current policy -> $e');
      return null;
    }
  }
}
