import 'package:flutter/foundation.dart';

import 'device_signal.dart';

/// Why the app refuses to run on the current device.
enum DeviceBlockReason {
  /// Device passed every enabled check.
  none,

  /// Not an Android phone or an iPhone/iPad — a desktop or web build, Windows
  /// Subsystem for Android, or an iOS app running on Apple Silicon macOS.
  unsupportedPlatform,

  /// Emulator, virtual machine or Android app player (BlueStacks, LDPlayer,
  /// Nox, MEmu, Genymotion, the Android Studio emulator, the iOS Simulator…).
  emulator,

  /// Rooted / jailbroken / otherwise tampered device.
  compromised,

  /// The *app* rather than the device: sideloaded outside a trusted store, or
  /// re-signed with a certificate that is not ours.
  tampered,

  /// Android developer options or USB debugging are switched on. Recoverable
  /// by the user, so it gets its own reason and its own message.
  developerMode,
}

/// Outcome of a device check, plus the weighted evidence that produced it.
///
/// [evidence] is deliberately kept even when the verdict is *allowed*: a
/// device that scored 60 against a threshold of 100 is exactly what you want
/// to see in telemetry before tightening the rules.
@immutable
class DeviceIntegrityResult {
  const DeviceIntegrityResult(this.reason, this.evidence, {this.score = 0});

  /// A pass. [evidence] carries any signals that fired but stayed under the
  /// threshold.
  const DeviceIntegrityResult.allowed([this.evidence = const []])
      : reason = DeviceBlockReason.none,
        score = 0;

  final DeviceBlockReason reason;

  /// Signals that survived `ignoredSignals`, with their applied weights.
  final List<DeviceSignal> evidence;

  /// Sum of [evidence] points for a block; `0` for a pass.
  final int score;

  bool get isAllowed => reason == DeviceBlockReason.none;

  /// The signal ids, e.g. `['build:bluestacks', 'abi:x86_64']`. These are the
  /// strings a host app puts in `DeviceIntegrityConfig.ignoredSignals`.
  List<String> get signals => [for (final signal in evidence) signal.id];

  /// Short, stable string to quote in a support ticket. The bracketed number
  /// is the score, so support can tell "barely tripped" from "unmistakable".
  String get reference => evidence.isEmpty
      ? reason.name
      : '${reason.name}[$score]: ${signals.join(', ')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceIntegrityResult &&
          other.reason == reason &&
          other.score == score &&
          listEquals(other.evidence, evidence));

  @override
  int get hashCode => Object.hash(reason, score, Object.hashAll(evidence));

  @override
  String toString() => 'DeviceIntegrityResult($reference)';
}
