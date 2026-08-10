import 'package:flutter/foundation.dart';

/// How much a single detection signal counts towards a block.
///
/// Not every signal is equally trustworthy. `/data/bluestacks.prop` on disk
/// cannot happen on a retail phone; `Build.BOOTLOADER == "unknown"` happens on
/// plenty of them. Treating both as "block immediately" is how a device gate
/// locks paying users out, so each signal declares its own confidence and a
/// verdict is only raised once the surviving signals add up to
/// `DeviceIntegrityConfig.blockThreshold`.
enum SignalWeight {
  /// Cannot occur on genuine retail hardware. Blocks on its own.
  conclusive(100),

  /// Reliable, but has a plausible false-positive path — a spoofable field, or
  /// a native check that reports "unsafe" when its platform channel fails.
  /// Two of these block; one on its own does not.
  strong(60),

  /// Genuinely ambiguous: seen on real devices as well as on emulators.
  /// Only meaningful as corroboration.
  weak(30);

  const SignalWeight(this.points);

  /// Contribution towards [DeviceIntegrityConfig.blockThreshold].
  final int points;
}

/// One piece of evidence, e.g. `file:bluestacks` at [SignalWeight.conclusive].
///
/// [id] is always `category:value` and is the string a host app puts in
/// `ignoredSignals` or `signalWeights` to retune it without editing this
/// module.
@immutable
class DeviceSignal {
  const DeviceSignal(this.id, this.weight);

  /// `category:value`, e.g. `build:bluestacks`, `abi:x86_64+x86`.
  final String id;

  final SignalWeight weight;

  /// The part before the first `:`, e.g. `build`.
  String get category => id.split(':').first;

  int get points => weight.points;

  DeviceSignal withWeight(SignalWeight value) =>
      value == weight ? this : DeviceSignal(id, value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceSignal && other.id == id && other.weight == weight);

  @override
  int get hashCode => Object.hash(id, weight);

  @override
  String toString() => id;
}

/// Total score of [signals].
int scoreOf(Iterable<DeviceSignal> signals) =>
    signals.fold(0, (total, signal) => total + signal.points);
