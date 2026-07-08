import 'dart:typed_data';
import 'dart:ui' show Rect;

/// Metadata produced by the detection pass over a picked image.
class InkAnalysis {
  const InkAnalysis({
    required this.imageWidth,
    required this.imageHeight,
    required this.suggestedCrop,
    required this.hasAlphaContent,
    required this.backgroundColorArgb,
    required this.backgroundUniform,
    required this.inkThreshold,
  });

  /// Dimensions of the decoded source image, in pixels.
  final int imageWidth;
  final int imageHeight;

  /// Auto-detected content bounding box (in source-image pixel coordinates),
  /// already padded. Falls back to the full image when nothing is detected.
  final Rect suggestedCrop;

  /// True when the source already contains meaningful transparency — in that
  /// case background removal is skipped and the existing alpha is trusted.
  final bool hasAlphaContent;

  /// Estimated background color (ARGB). Meaningless when [hasAlphaContent].
  final int backgroundColorArgb;

  /// Whether the background is a single, uniform color (reliable for
  /// single-color removal). False for gradients / busy backgrounds, where
  /// keying leaves artifacts — the UI defaults removal off and warns in that
  /// case. Always true when [hasAlphaContent] (no removal needed).
  final bool backgroundUniform;

  /// Otsu-derived ink threshold (0..1 distance from background) used to seed
  /// the background-removal alpha ramp.
  final double inkThreshold;
}

/// Final output of the cleanup pipeline.
class CleanupResult {
  const CleanupResult({
    required this.pngBytes,
    required this.width,
    required this.height,
    required this.backgroundRemoved,
  });

  /// The cleaned image, always PNG-encoded (supports transparency).
  final Uint8List pngBytes;

  /// Output dimensions in pixels.
  final int width;
  final int height;

  /// Whether the background was converted to transparency.
  final bool backgroundRemoved;
}
