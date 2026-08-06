/// Crash reporting with every credential removed on the way out.
///
/// Barrel export — the only import you need:
///
/// ```dart
/// import 'package:my_app/core/crash/crash_reporting.dart';
/// ```
///
/// `dio_error_describer.dart` is deliberately **not** exported: it is the only
/// file here that depends on `dio`. Import it directly if you use Dio.
library;

export 'crash_description.dart';
export 'crash_reporter.dart';
export 'crash_reporter_config.dart';
export 'log_scrubber.dart';
