import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'shorebird_update_config.dart';
import 'shorebird_update_options.dart';
import 'shorebird_update_prompter.dart';
import 'shorebird_update_state.dart';

/// Drop-in over-the-air update manager for Shorebird.
///
/// Wire it up once, in `main()`, before `runApp`:
///
/// ```dart
/// ShorebirdUpdateManager.initialize(navigatorKey: navigatorKey);
/// ```
///
/// That is the whole integration. Do **not** call [checkForUpdate] from a
/// screen: patches must reach signed-out users too, and any screen-scoped call
/// silently excludes everyone who never lands on that screen.
///
/// The manager owns its own scheduling: one check shortly after launch, then
/// one on every resume, throttled by
/// [ShorebirdUpdateConfig.minCheckInterval].
///
/// See `README.md` in this folder for the full guide.
class ShorebirdUpdateManager {
  const ShorebirdUpdateManager._();

  static ShorebirdUpdater? _updater;
  static ShorebirdUpdateConfig _config = const ShorebirdUpdateConfig();
  static GlobalKey<NavigatorState>? _navigatorKey;
  static _ShorebirdLifecycleObserver? _observer;
  static Timer? _startTimer;

  static bool _initialized = false;
  static bool _busy = false;
  static DateTime? _lastCheckedAt;

  /// Patch number we already surfaced to the user, so a pending update is
  /// announced once rather than on every resume.
  static int? _announcedPatch;

  /// Observable update state. Safe to use in a [ValueListenableBuilder].
  static final ValueNotifier<ShorebirdUpdateState> state =
      ValueNotifier<ShorebirdUpdateState>(const ShorebirdUpdateState.idle());

  static ShorebirdUpdateConfig get config => _config;

  static UpdateTrack get currentTrack => _config.track;

  /// `true` when the Shorebird engine is present. Always `false` under
  /// `flutter run`/`flutter build`; use `shorebird run`/`shorebird preview`.
  static bool get isAvailable => _updater?.isAvailable ?? false;

  static bool get isCheckingForUpdates => state.value.isBusy;

  /// Built per call so runtime changes to strings or navigator key are picked
  /// up without re-initializing.
  static ShorebirdUpdatePrompter get _ui => ShorebirdUpdatePrompter(
        navigatorKey: _navigatorKey,
        strings: _config.strings,
        logger: _log,
      );

  /// Wires up the manager. Idempotent: calling it twice is a no-op.
  ///
  /// [navigatorKey] is only needed for [ShorebirdUpdateMode.notifyWhenReady]
  /// and [ShorebirdUpdateMode.askBeforeDownload]; silent mode needs no context.
  static void initialize({
    GlobalKey<NavigatorState>? navigatorKey,
    ShorebirdUpdateConfig config = const ShorebirdUpdateConfig(),
  }) {
    if (_initialized) {
      _log('initialize() called more than once; ignoring.');
      return;
    }
    _initialized = true;
    _config = config;
    _navigatorKey = navigatorKey;
    _updater = ShorebirdUpdater();

    if (!isAvailable) {
      _log('Shorebird engine unavailable in this build; updates are disabled.');
      _emit(
          const ShorebirdUpdateState(phase: ShorebirdUpdatePhase.unavailable));
      return;
    }

    _emit(const ShorebirdUpdateState.idle());
    unawaited(_refreshPatchNumbers());

    if (config.checkOnResume) {
      _observer = _ShorebirdLifecycleObserver();
      WidgetsBinding.instance.addObserver(_observer!);
    }

    if (config.checkOnStart) {
      _startTimer = Timer(config.startDelay, () {
        unawaited(checkForUpdate());
      });
    }
  }

  /// Switches track at runtime (e.g. an internal "join beta" toggle) and
  /// immediately re-checks.
  static Future<void> setTrack(UpdateTrack track) async {
    if (track == _config.track) return;
    _config = _config.copyWith(track: track);
    _announcedPatch = null;
    await checkForUpdate(force: true);
  }

  /// Switches update mode at runtime.
  static void setMode(ShorebirdUpdateMode mode) {
    _config = _config.copyWith(mode: mode);
  }

  /// The patch the running app was launched with, or `null` on a base release.
  static Future<Patch?> getCurrentPatch() => _readPatch(next: false);

  /// The patch that will be applied on the next cold start, if one is staged.
  static Future<Patch?> getNextPatch() => _readPatch(next: true);

  /// Checks for a patch and, depending on [ShorebirdUpdateConfig.mode],
  /// downloads it.
  ///
  /// Returns the resulting state. Concurrent calls collapse into the first one.
  /// Automatic calls are throttled by
  /// [ShorebirdUpdateConfig.minCheckInterval]; pass `force: true` to bypass
  /// that (for a "Check for updates" button in settings).
  static Future<ShorebirdUpdateState> checkForUpdate({
    bool force = false,
    VoidCallback? onUpdateAvailable,
    VoidCallback? onNoUpdateAvailable,
    ValueChanged<String>? onError,
  }) async {
    if (!isAvailable) return state.value;
    if (_busy) return state.value;

    if (!force && _lastCheckedAt != null) {
      final elapsed = DateTime.now().difference(_lastCheckedAt!);
      if (elapsed < _config.minCheckInterval) {
        _log('Skipping check; last one was ${elapsed.inMinutes}m ago.');
        return state.value;
      }
    }

    _busy = true;
    _emit(state.value.copyWith(phase: ShorebirdUpdatePhase.checking));

    try {
      final status = await _updater!.checkForUpdate(track: _config.track);
      _lastCheckedAt = DateTime.now();
      _log('Update status on "${_config.track.name}": ${status.name}');

      switch (status) {
        case UpdateStatus.upToDate:
          onNoUpdateAvailable?.call();
          _emit(state.value.copyWith(phase: ShorebirdUpdatePhase.idle));

        case UpdateStatus.outdated:
          onUpdateAvailable?.call();
          if (_config.mode == ShorebirdUpdateMode.askBeforeDownload) {
            _emit(state.value.copyWith(phase: ShorebirdUpdatePhase.idle));
            _ui.askToDownload(onDownload: () => unawaited(_download()));
          } else {
            await _download();
          }

        case UpdateStatus.restartRequired:
          // A patch was already staged, by us or by a previous session.
          await _markReadyToApply();

        case UpdateStatus.unavailable:
          _emit(
            const ShorebirdUpdateState(phase: ShorebirdUpdatePhase.unavailable),
          );
      }
    } catch (error, stackTrace) {
      _reportError('Failed to check for update', error, stackTrace);
      onError?.call(error.toString());
      _emit(
        state.value.copyWith(
          phase: ShorebirdUpdatePhase.failed,
          error: error.toString(),
        ),
      );
    } finally {
      _busy = false;
    }

    return state.value;
  }

  /// Applies a downloaded patch.
  ///
  /// A patch is only loaded when the process starts, so unless
  /// [ShorebirdUpdateConfig.onRestartRequested] is provided this just tells the
  /// user the update lands on next launch — which it does, with no action from
  /// them.
  static void applyUpdate() {
    final restart = _config.onRestartRequested;
    if (restart != null) {
      _ui.hide();
      restart();
    } else {
      _log('No onRestartRequested handler; patch applies on next cold start.');
    }
  }

  /// Releases the lifecycle observer and resets state. Mainly for tests.
  @visibleForTesting
  static void dispose() {
    _startTimer?.cancel();
    _startTimer = null;
    if (_observer != null) {
      WidgetsBinding.instance.removeObserver(_observer!);
      _observer = null;
    }
    _updater = null;
    _navigatorKey = null;
    _initialized = false;
    _busy = false;
    _lastCheckedAt = null;
    _announcedPatch = null;
    _config = const ShorebirdUpdateConfig();
    state.value = const ShorebirdUpdateState.idle();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  static Future<void> _download() async {
    _emit(state.value.copyWith(phase: ShorebirdUpdatePhase.downloading));
    if (_config.mode != ShorebirdUpdateMode.silent) _ui.showDownloading();

    final attempts = _config.maxRetries + 1;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        await _updater!.update(track: _config.track);
        await _markReadyToApply();
        return;
      } on UpdateException catch (error, stackTrace) {
        if (error.reason == UpdateFailureReason.noUpdate) {
          _emit(state.value.copyWith(phase: ShorebirdUpdatePhase.idle));
          _ui.hide();
          return;
        }

        final canRetry = error.reason == UpdateFailureReason.downloadFailed ||
            error.reason == UpdateFailureReason.unknown;

        if (canRetry && attempt < attempts) {
          final delay = _config.retryBackoff * attempt;
          _log('Download attempt $attempt failed; retrying in '
              '${delay.inSeconds}s (${error.reason.name}).');
          await Future<void>.delayed(delay);
          continue;
        }

        _reportError('Failed to download patch', error, stackTrace);
        _emit(
          state.value.copyWith(
            phase: ShorebirdUpdatePhase.failed,
            error: error.message,
          ),
        );
        _ui.hide();
        if (_config.mode != ShorebirdUpdateMode.silent) {
          _ui.showError(error.message);
        }
        return;
      } catch (error, stackTrace) {
        _reportError('Failed to download patch', error, stackTrace);
        _emit(
          state.value.copyWith(
            phase: ShorebirdUpdatePhase.failed,
            error: error.toString(),
          ),
        );
        _ui.hide();
        return;
      }
    }
  }

  static Future<void> _markReadyToApply() async {
    final next = await _readPatch(next: true);
    _emit(
      state.value.copyWith(
        phase: ShorebirdUpdatePhase.readyToApply,
        nextPatch: next?.number,
      ),
    );
    _ui.hide();

    if (_config.mode == ShorebirdUpdateMode.silent) {
      _log('Patch ${next?.number} staged; applies on next cold start.');
      return;
    }

    // Announce a given patch at most once per session.
    if (next != null && _announcedPatch == next.number) return;
    _announcedPatch = next?.number;

    _ui.showReady(
      style: _config.promptStyle,
      onRestart: _config.onRestartRequested == null ? null : applyUpdate,
    );
  }

  static Future<void> _refreshPatchNumbers() async {
    final current = await _readPatch(next: false);
    final next = await _readPatch(next: true);
    _emit(
      state.value.copyWith(
        currentPatch: current?.number,
        nextPatch: next?.number,
        phase: next != null
            ? ShorebirdUpdatePhase.readyToApply
            : state.value.phase,
      ),
    );
    _log('Running patch ${current?.number ?? "none"}'
        '${next != null ? ", patch ${next.number} pending" : ""}.');
  }

  static Future<Patch?> _readPatch({required bool next}) async {
    if (!isAvailable) return null;
    try {
      return next
          ? await _updater!.readNextPatch()
          : await _updater!.readCurrentPatch();
    } catch (error, stackTrace) {
      _reportError('Failed to read patch', error, stackTrace);
      return null;
    }
  }

  static void _emit(ShorebirdUpdateState next) {
    if (state.value == next) return;
    state.value = next;
    _config.onStateChanged?.call(next);
  }

  static void _log(String message) {
    if (_config.logger != null) {
      _config.logger!(message);
    } else {
      developer.log(message, name: 'Shorebird');
    }
  }

  static void _reportError(String message, Object error, StackTrace stack) {
    _log('$message: $error');
    _config.onError?.call(error, stack);
  }
}

/// Re-checks for patches whenever the app comes back to the foreground.
class _ShorebirdLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ShorebirdUpdateManager.checkForUpdate());
    }
  }
}
