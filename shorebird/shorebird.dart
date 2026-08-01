/// Shorebird over-the-air update helper.
///
/// Single import for the whole module:
///
/// ```dart
/// import 'package:sanad_rewards/utils/helpers/shorebird/shorebird.dart';
/// ```
///
/// See `README.md` in this folder for setup and usage.
library;

export 'package:shorebird_code_push/shorebird_code_push.dart'
    show Patch, UpdateStatus, UpdateTrack;

export 'restart_widget.dart';
export 'shorebird_update_config.dart';
export 'shorebird_update_manager.dart';
export 'shorebird_update_options.dart';
export 'shorebird_update_prompter.dart';
export 'shorebird_update_state.dart';
export 'shorebird_update_strings.dart';
