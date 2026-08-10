/// Drop-in device integrity gate: real Android phones and iPhones only.
///
/// Import this single file to get the whole module:
/// ```dart
/// import 'package:<your_app>/config/security/device_security.dart';
/// ```
///
/// See `README.md` in this folder for setup, policy options and how to tune
/// detection.
library;

export 'device_blocked_screen.dart';
export 'device_fingerprints.dart';
export 'device_gate.dart';
export 'device_integrity.dart';
export 'device_integrity_config.dart';
export 'device_integrity_result.dart';
export 'device_probe.dart';
export 'device_signal.dart';
