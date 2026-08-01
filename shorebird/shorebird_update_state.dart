import 'package:flutter/foundation.dart';

/// Where the update flow currently is.
enum ShorebirdUpdatePhase {
  /// The Shorebird engine is not present in this build (`flutter run`,
  /// `flutter build`, web, or a debug session). Every call is a no-op.
  unavailable,

  /// Nothing in flight.
  idle,

  /// Asking the Shorebird servers whether a patch exists.
  checking,

  /// Downloading a patch.
  downloading,

  /// A patch is downloaded and will be applied on the next cold start.
  readyToApply,

  /// The last check or download failed. See [ShorebirdUpdateState.error].
  failed,
}

/// An immutable snapshot of the updater, exposed via
/// `ShorebirdUpdateManager.state` so any widget can render update status.
@immutable
class ShorebirdUpdateState {
  const ShorebirdUpdateState({
    required this.phase,
    this.currentPatch,
    this.nextPatch,
    this.error,
  });

  const ShorebirdUpdateState.idle() : this(phase: ShorebirdUpdatePhase.idle);

  final ShorebirdUpdatePhase phase;

  /// The patch the app is running right now, or `null` on the base release.
  final int? currentPatch;

  /// The patch that will be applied on the next cold start, if any.
  final int? nextPatch;

  /// Human readable failure message when [phase] is
  /// [ShorebirdUpdatePhase.failed].
  final String? error;

  bool get isBusy =>
      phase == ShorebirdUpdatePhase.checking ||
      phase == ShorebirdUpdatePhase.downloading;

  bool get hasPendingUpdate => phase == ShorebirdUpdatePhase.readyToApply;

  /// Note: [error] is intentionally *not* preserved when omitted, so moving to
  /// any non-failed phase clears the previous failure.
  ShorebirdUpdateState copyWith({
    ShorebirdUpdatePhase? phase,
    int? currentPatch,
    int? nextPatch,
    String? error,
  }) {
    return ShorebirdUpdateState(
      phase: phase ?? this.phase,
      currentPatch: currentPatch ?? this.currentPatch,
      nextPatch: nextPatch ?? this.nextPatch,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ShorebirdUpdateState &&
      other.phase == phase &&
      other.currentPatch == currentPatch &&
      other.nextPatch == nextPatch &&
      other.error == error;

  @override
  int get hashCode => Object.hash(phase, currentPatch, nextPatch, error);

  @override
  String toString() => 'ShorebirdUpdateState(${phase.name}, '
      'current: $currentPatch, next: $nextPatch, error: $error)';
}
