import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The kinds of haptic feedback, so a haptic can be chosen at runtime / passed
/// as data (e.g. in a button config) via [HapticsHelper.fire].
enum HapticType {
  success,
  warning,
  error,
  light,
  medium,
  heavy,
  selection,
  vibrate,
}

/// App-wide haptic feedback built only on Flutter's [HapticFeedback] — no
/// third-party packages, and a safe no-op where haptics aren't available.
///
/// Drop this file into any Flutter project and call it directly:
/// ```dart
/// HapticsHelper.success();
/// HapticsHelper.fire(HapticType.light);
/// ```
///
/// Note: `success`/`warning`/`error` only produce feedback on Android 11+
/// (API 30); below that they no-op. iOS is unaffected.
class HapticsHelper {
  HapticsHelper._();

  /// Master switch. Set to `false` to silence all haptics (e.g. a user setting).
  static bool enabled = true;

  /// Minimum gap between pulses. Rapid repeats inside this window are dropped so
  /// high-frequency callers (drags, sliders, scrolling) don't spam the taptic
  /// engine. Set to [Duration.zero] to disable throttling.
  static Duration minInterval = const Duration(milliseconds: 40);
  static DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  /// Notification feedback (Android 11+ / all supported iOS).
  static void success() => _fire(HapticFeedback.successNotification);
  static void warning() => _fire(HapticFeedback.warningNotification);
  static void error() => _fire(HapticFeedback.errorNotification);

  /// Collision impacts, from subtle to strong.
  static void light() => _fire(HapticFeedback.lightImpact);
  static void medium() => _fire(HapticFeedback.mediumImpact);
  static void heavy() => _fire(HapticFeedback.heavyImpact);

  /// Selection moving through discrete values (pickers, sliders, page changes).
  static void selection() => _fire(HapticFeedback.selectionClick);

  /// Generic short vibration.
  static void vibrate() => _fire(HapticFeedback.vibrate);

  /// Fire a [HapticType] chosen at runtime.
  static void fire(HapticType type) {
    switch (type) {
      case HapticType.success:
        return success();
      case HapticType.warning:
        return warning();
      case HapticType.error:
        return error();
      case HapticType.light:
        return light();
      case HapticType.medium:
        return medium();
      case HapticType.heavy:
        return heavy();
      case HapticType.selection:
        return selection();
      case HapticType.vibrate:
        return vibrate();
    }
  }

  static void _fire(Future<void> Function() call) {
    if (!enabled) return;
    final now = DateTime.now();
    if (now.difference(_last) < minInterval) return; // throttle spam
    _last = now;
    unawaited(_safeCall(call));
  }

  /// Fire-and-forget: a failed haptic pulse must never crash the app.
  static Future<void> _safeCall(Future<void> Function() call) async {
    try {
      await call();
    } catch (e) {
      if (kDebugMode) debugPrint('HapticsHelper: feedback failed: $e');
    }
  }
}
