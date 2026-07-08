import 'dart:ui' show Color;

/// Shape of the crop region.
enum CropShape {
  /// Classic rectangular crop.
  rectangle,

  /// Elliptical crop inscribed in the crop rectangle (a circle when the
  /// rectangle is square). Pixels outside the ellipse become transparent —
  /// ideal for round stamps.
  oval,
}

/// How the ink (foreground) pixels should be colored in the output.
enum InkStyle {
  /// Keep the original ink colors (un-blended from the background so
  /// anti-aliased edges don't carry a white halo).
  original,

  /// Recolor every ink pixel to a single solid color while keeping the
  /// per-pixel alpha. Produces a crisp, uniform result for messy photos.
  solid,
}

/// Tuning knobs for the cleanup pipeline.
///
/// The defaults are chosen for signatures/stamps photographed or scanned on
/// a light background and work well without adjustment.
class CleanupOptions {
  const CleanupOptions({
    this.removeBackground = true,
    this.cropShape = CropShape.rectangle,
    this.sensitivity = 0.5,
    this.inkStyle = InkStyle.original,
    this.solidInkColor = const Color(0xFF1A1A1A),
    this.analysisMaxDimension = 640,
    this.outputMaxDimension = 1200,
    this.detectionPaddingFraction = 0.04,
    this.connectedBackgroundTolerance = 0.06,
    this.outputPaddingPx = 6,
    this.trimTransparentResult = true,
  }) : assert(sensitivity >= 0 && sensitivity <= 1);

  /// Convert the (near-)uniform background to transparency.
  final bool removeBackground;

  /// Initial crop shape. The user can switch shapes in the UI.
  final CropShape cropShape;

  /// 0..1. Higher values treat more pixels as ink (keeps faint pen strokes
  /// but may keep paper shadows); lower values are more aggressive at
  /// dropping the background. 0.5 is a balanced default.
  final double sensitivity;

  /// How ink pixels are colored in the output.
  final InkStyle inkStyle;

  /// Ink color used when [inkStyle] is [InkStyle.solid].
  final Color solidInkColor;

  /// The image is downscaled to at most this dimension for the detection
  /// pass (bounding-box + threshold estimation). Full resolution is always
  /// used for the final output.
  final int analysisMaxDimension;

  /// Final output is downscaled to at most this dimension (longest side).
  /// Set to 0 to keep the original resolution.
  final int outputMaxDimension;

  /// Padding added around the auto-detected bounding box, as a fraction of
  /// the box's longest side.
  final double detectionPaddingFraction;

  /// Max normalized (0..1) RGB step between adjacent pixels for the
  /// flood-fill removal used on non-uniform backgrounds. Small values follow
  /// smooth gradients but stop at hard subject edges; larger values remove
  /// more but risk leaking into the subject.
  final double connectedBackgroundTolerance;

  /// Transparent padding (in output pixels) kept around the final trimmed
  /// content so strokes don't touch the image edge.
  final int outputPaddingPx;

  /// After background removal, re-trim to the opaque content's bounding box
  /// so the uploaded image is guaranteed to have no extra margins.
  final bool trimTransparentResult;

  CleanupOptions copyWith({
    bool? removeBackground,
    CropShape? cropShape,
    double? sensitivity,
    InkStyle? inkStyle,
    Color? solidInkColor,
    int? analysisMaxDimension,
    int? outputMaxDimension,
    double? detectionPaddingFraction,
    double? connectedBackgroundTolerance,
    int? outputPaddingPx,
    bool? trimTransparentResult,
  }) {
    return CleanupOptions(
      removeBackground: removeBackground ?? this.removeBackground,
      cropShape: cropShape ?? this.cropShape,
      sensitivity: sensitivity ?? this.sensitivity,
      inkStyle: inkStyle ?? this.inkStyle,
      solidInkColor: solidInkColor ?? this.solidInkColor,
      analysisMaxDimension: analysisMaxDimension ?? this.analysisMaxDimension,
      connectedBackgroundTolerance:
          connectedBackgroundTolerance ?? this.connectedBackgroundTolerance,
      outputMaxDimension: outputMaxDimension ?? this.outputMaxDimension,
      detectionPaddingFraction:
          detectionPaddingFraction ?? this.detectionPaddingFraction,
      outputPaddingPx: outputPaddingPx ?? this.outputPaddingPx,
      trimTransparentResult:
          trimTransparentResult ?? this.trimTransparentResult,
    );
  }
}
