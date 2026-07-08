/// Smart signature/stamp image cleanup.
///
/// Auto-detects the ink content of a picked image, lets the user fine-tune
/// the crop, trims all margins, and converts the background to transparency
/// — producing an upload-ready PNG.
///
/// This module is self-contained (depends only on Flutter and
/// `package:image`) so it can be copied into any app. See README.md in this
/// directory for usage.
library;

export 'domain/cleanup_options.dart';
export 'domain/cleanup_result.dart';
export 'helpers/image_cleanup_helper.dart';
export 'presentation/pages/image_cleanup_page.dart';
export 'presentation/widgets/adjustable_crop_view.dart';
export 'presentation/widgets/checkerboard_background.dart';
export 'services/background_removal_service.dart';
export 'services/image_cleanup_service.dart';
export 'services/ink_detection_service.dart';
