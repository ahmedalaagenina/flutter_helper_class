import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute, debugPrint;
// Fallback decoder only — the hot path uses the engine codecs (dart:ui).
import 'package:image/image.dart' as img;

import '../domain/cleanup_options.dart';
import '../domain/cleanup_result.dart';
import 'background_removal_service.dart';
import 'ink_detection_service.dart';

/// The analysis pass output: a normalized working image plus the detected
/// content metadata. All later steps (UI + processing) use the same working
/// pixels so what the user sees is exactly what gets processed.
class CleanupAnalysis {
  const CleanupAnalysis({
    required this.workingImage,
    required this.workingRgba,
    required this.analysis,
  });

  /// Engine-decoded working image (EXIF orientation baked, size capped).
  /// Display it with [RawImage] — no re-encode/re-decode round trip.
  ///
  /// Owned by the caller: call [dispose] when the flow is done with it.
  final ui.Image workingImage;

  /// Straight (un-premultiplied) RGBA pixels of [workingImage].
  final Uint8List workingRgba;

  final InkAnalysis analysis;

  void dispose() => workingImage.dispose();
}

/// High-level entry points for the cleanup pipeline.
///
/// Decode, downscale and PNG encode all go through the Flutter **engine
/// codecs** (`dart:ui`), which run in native code off the UI thread on every
/// platform — including web. A pure-Dart decoder (e.g. `package:image`)
/// would allocate hundreds of MB decoding a camera photo and freeze the UI
/// (shared-heap GC pauses on mobile, main-thread execution on web).
///
/// Only the per-pixel alpha math runs in Dart, on already-downscaled
/// buffers, via [compute] on mobile/desktop.
class ImageCleanupService {
  ImageCleanupService._();

  /// Working copies are capped to this dimension. Larger than the output cap
  /// so that cropping a region still leaves enough resolution.
  static const int _workingMaxDimension = 1600; // 150 KB to 1 MB

  /// Decodes [bytes] (engine codec: EXIF baked, capped to
  /// [_workingMaxDimension]) and detects the ink content. Returns null when
  /// the bytes are not a decodable image.
  ///
  /// Files the engine codec rejects (some BMP variants, unusual JPEG
  /// encodings, mildly corrupt files) get a second chance through the
  /// lenient pure-Dart decoder, in an isolate.
  static Future<CleanupAnalysis?> analyze(
    Uint8List bytes, {
    CleanupOptions options = const CleanupOptions(),
  }) async {
    ui.Image? working;
    Uint8List? rgba;

    try {
      working = await _decodeCapped(bytes, _workingMaxDimension);
      rgba = await _straightRgbaOf(working);
      if (rgba == null) {
        working.dispose();
        working = null;
      }
    } catch (e) {
      debugPrint('image_cleanup: engine decode failed ($e), trying fallback');
      working?.dispose();
      working = null;
    }

    if (working == null || rgba == null) {
      // Lenient pure-Dart decode (package:image) in an isolate.
      final fb = await compute(
        _fallbackDecode,
        _FallbackRequest(bytes: bytes, maxDimension: _workingMaxDimension),
        debugLabel: 'image_cleanup.fallback_decode',
      );
      if (fb == null) return null;
      rgba = fb.rgba;
      // decodeImageFromPixels wants premultiplied; keep [rgba] straight for
      // the detection/processing math and premultiply a display copy.
      final premul = Uint8List.fromList(fb.rgba);
      _premultiplyInPlace(premul);
      working = await _imageFromPixels(premul, fb.width, fb.height);
    }

    final ui.Image image = working;
    final Uint8List pixels = rgba;
    final w = image.width, h = image.height;

    // Detection runs on a bounded sample grid, so these passes are cheap
    // enough to stay inline (~tens of ms) on every platform.
    final hasAlpha = InkDetectionService.hasAlphaContent(pixels, w, h);
    // Sources with real transparency need no removal, so treat their
    // background as uniform (removal is skipped for them anyway).
    final bg = hasAlpha
        ? (argb: 0xFFFFFFFF, uniform: true)
        : InkDetectionService.estimateBackground(pixels, w, h);
    final bgArgb = bg.argb;
    final dm = InkDetectionService.sampledDistanceMap(
      pixels,
      w,
      h,
      backgroundArgb: bgArgb,
      useAlpha: hasAlpha,
      maxDimension: options.analysisMaxDimension,
    );
    final threshold = InkDetectionService.otsuThreshold(dm.map);
    var box = InkDetectionService.inkBoundingBox(
      dm.map,
      dm.width,
      dm.height,
      threshold,
    );

    ui.Rect suggested;
    if (box == null) {
      suggested = ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    } else {
      box = InkDetectionService.padBox(
        box,
        options.detectionPaddingFraction,
        dm.width,
        dm.height,
      );
      final s = dm.stride.toDouble();
      suggested = ui.Rect.fromLTRB(
        (box.left * s).clamp(0, w.toDouble()),
        (box.top * s).clamp(0, h.toDouble()),
        (box.right * s).clamp(0, w.toDouble()),
        (box.bottom * s).clamp(0, h.toDouble()),
      );
    }

    return CleanupAnalysis(
      workingImage: working,
      workingRgba: rgba,
      analysis: InkAnalysis(
        imageWidth: w,
        imageHeight: h,
        suggestedCrop: suggested,
        hasAlphaContent: hasAlpha,
        backgroundColorArgb: bgArgb,
        backgroundUniform: bg.uniform,
        inkThreshold: threshold,
      ),
    );
  }

  /// Crops the working pixels to [crop] (working-image pixel coordinates),
  /// applies the oval mask / background removal / trim, resizes, and encodes
  /// a PNG via the engine.
  static Future<CleanupResult?> process(
    CleanupAnalysis analysis, {
    required ui.Rect crop,
    CleanupOptions options = const CleanupOptions(),
  }) async {
    final info = analysis.analysis;
    final removeBackground = options.removeBackground && !info.hasAlphaContent;

    // Crop here with cheap row copies so only the selected region crosses
    // the isolate boundary (the full working frame can be ~10MB); the fresh
    // copy also lets _processBuffer mutate its input safely everywhere,
    // including web where `compute` passes references.
    final left = crop.left.floor().clamp(0, info.imageWidth - 1);
    final top = crop.top.floor().clamp(0, info.imageHeight - 1);
    final width = (crop.right.ceil() - left).clamp(1, info.imageWidth - left);
    final height = (crop.bottom.ceil() - top).clamp(1, info.imageHeight - top);
    final cropped = _cropRgba(
      analysis.workingRgba,
      info.imageWidth,
      left,
      top,
      width,
      height,
    );

    // Per-pixel work on the cropped buffer — real isolate on mobile/desktop.
    // On web `compute` runs inline (no isolates), so the UI blocks briefly;
    // the page shows a "this might take a moment" notice for that case.
    final buf = await compute(
      _processBuffer,
      _BufferRequest(
        rgba: cropped,
        width: width,
        height: height,
        removeBackground: removeBackground,
        backgroundUniform: info.backgroundUniform,
        connectedTolerance: options.connectedBackgroundTolerance,
        ovalCrop: options.cropShape == CropShape.oval,
        hasAlphaContent: info.hasAlphaContent,
        backgroundArgb: info.backgroundColorArgb,
        inkThreshold: info.inkThreshold,
        sensitivity: options.sensitivity,
        solidInkArgb: options.inkStyle == InkStyle.solid
            ? options.solidInkColor.toARGB32()
            : null,
        trimResult: options.trimTransparentResult,
      ),
      debugLabel: 'image_cleanup.process',
    );

    // Resize (engine, native) while building the ui.Image from the pixels.
    var targetW = buf.width, targetH = buf.height;
    if (options.outputMaxDimension > 0) {
      final longest = math.max(buf.width, buf.height);
      if (longest > options.outputMaxDimension) {
        final scale = options.outputMaxDimension / longest;
        targetW = math.max(1, (buf.width * scale).round());
        targetH = math.max(1, (buf.height * scale).round());
      }
    }
    var image = await _imageFromPixels(
      buf.rgba,
      buf.width,
      buf.height,
      targetWidth: targetW,
      targetHeight: targetH,
    );

    if (options.outputPaddingPx > 0) {
      final padded = await _compose(
        image,
        padding: options.outputPaddingPx,
        backgroundArgb: buf.transparentOutput ? null : info.backgroundColorArgb,
      );
      image.dispose();
      image = padded;
    }

    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final outW = image.width, outH = image.height;
    image.dispose();
    if (png == null) return null;

    return CleanupResult(
      pngBytes: png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
      width: outW,
      height: outH,
      backgroundRemoved: removeBackground,
    );
  }

  /// Silently re-encodes [bytes] as an 8-bit RGBA PNG **without any
  /// cleanup** — no crop, no background removal, no trim. Pixels are
  /// unchanged apart from EXIF orientation baking and the same
  /// [_workingMaxDimension] size cap the cleanup flow applies.
  ///
  /// Use this for "upload as-is" paths that bypass the cleanup UI but must
  /// still guarantee a PNG (e.g. for PDF generation). Returns null when the
  /// bytes are not a decodable image.
  static Future<Uint8List?> normalizeToPng(Uint8List bytes) async {
    ui.Image? image;
    try {
      image = await _decodeCapped(bytes, _workingMaxDimension);
    } catch (e) {
      debugPrint('image_cleanup: engine decode failed ($e), trying fallback');
    }
    if (image == null) {
      // Same lenient pure-Dart rescue as analyze(), for engine-rejected
      // files (TIFF, odd BMPs, mildly corrupt data).
      final fb = await compute(
        _fallbackDecode,
        _FallbackRequest(bytes: bytes, maxDimension: _workingMaxDimension),
        debugLabel: 'image_cleanup.normalize_fallback',
      );
      if (fb == null) return null;
      _premultiplyInPlace(fb.rgba);
      image = await _imageFromPixels(fb.rgba, fb.width, fb.height);
    }
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return null;
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  /// Reads straight (un-premultiplied) RGBA pixels out of [image]. Prefers
  /// `rawStraightRgba`; falls back to `rawRgba` + manual un-premultiply on
  /// engines where the straight format fails.
  static Future<Uint8List?> _straightRgbaOf(ui.Image image) async {
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data != null) {
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      }
    } catch (e) {
      debugPrint('image_cleanup: rawStraightRgba failed ($e), trying rawRgba');
    }
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final rgba = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    _unpremultiplyInPlace(rgba);
    return rgba;
  }

  /// Engine decode with EXIF orientation baked in, downscaled during decode
  /// so the full-resolution bitmap never materializes in Dart.
  ///
  /// Deliberately built on [ui.instantiateImageCodecWithSize] rather than
  /// `ImageDescriptor` introspection: the descriptor's `width`/`height`
  /// getters throw "not supported" on web, which would wrongly send every
  /// image through the slow pure-Dart fallback there. The target-size
  /// callback receives the intrinsic dimensions on every platform (this is
  /// the same path `Image(cacheWidth: …)` uses).
  static Future<ui.Image> _decodeCapped(
    Uint8List bytes,
    int maxDimension,
  ) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    // instantiateImageCodecWithSize takes ownership of the buffer and
    // disposes it; disposing it here too would throw.
    final codec = await ui.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (intrinsicWidth, intrinsicHeight) {
        final longest = math.max(intrinsicWidth, intrinsicHeight);
        if (longest <= maxDimension) {
          return ui.TargetImageSize(
            width: intrinsicWidth,
            height: intrinsicHeight,
          );
        }
        final scale = maxDimension / longest;
        return ui.TargetImageSize(
          width: math.max(1, (intrinsicWidth * scale).round()),
          height: math.max(1, (intrinsicHeight * scale).round()),
        );
      },
    );
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  /// Builds a [ui.Image] from **premultiplied** RGBA pixels, optionally
  /// resizing in the engine.
  static Future<ui.Image> _imageFromPixels(
    Uint8List premulRgba,
    int width,
    int height, {
    int? targetWidth,
    int? targetHeight,
  }) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      premulRgba,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      allowUpscaling: false,
    );
    return completer.future;
  }

  /// Draws [src] onto a canvas [padding] px larger on every side. With a
  /// [backgroundArgb] the canvas is filled first (non-transparent outputs);
  /// otherwise the padding stays transparent.
  static Future<ui.Image> _compose(
    ui.Image src, {
    required int padding,
    int? backgroundArgb,
  }) async {
    final w = src.width + padding * 2;
    final h = src.height + padding * 2;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    if (backgroundArgb != null) {
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Paint()..color = ui.Color(backgroundArgb),
      );
    }
    canvas.drawImage(
      src,
      ui.Offset(padding.toDouble(), padding.toDouble()),
      ui.Paint(),
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(w, h);
    } finally {
      picture.dispose();
    }
  }
}

class _BufferRequest {
  const _BufferRequest({
    required this.rgba,
    required this.width,
    required this.height,
    required this.removeBackground,
    required this.backgroundUniform,
    required this.connectedTolerance,
    required this.ovalCrop,
    required this.hasAlphaContent,
    required this.backgroundArgb,
    required this.inkThreshold,
    required this.sensitivity,
    required this.solidInkArgb,
    required this.trimResult,
  });

  /// Already cropped to the user's selection; a dedicated copy owned by
  /// [_processBuffer], which mutates it in place.
  final Uint8List rgba;
  final int width, height;
  final bool removeBackground;

  /// Selects the removal algorithm: true → single-color keying (uniform
  /// background); false → connected flood-fill (gradient / busy background).
  final bool backgroundUniform;
  final double connectedTolerance;
  final bool ovalCrop;
  final bool hasAlphaContent;
  final int backgroundArgb;
  final double inkThreshold;
  final double sensitivity;
  final int? solidInkArgb;
  final bool trimResult;
}

class _BufferResult {
  const _BufferResult({
    required this.rgba,
    required this.width,
    required this.height,
    required this.transparentOutput,
  });

  /// Premultiplied RGBA, ready for `decodeImageFromPixels`.
  final Uint8List rgba;
  final int width;
  final int height;
  final bool transparentOutput;
}

/// Oval mask → background removal → content trim → premultiply, all in
/// place on the pre-cropped buffer it receives (see [_BufferRequest.rgba]).
/// Pure buffer math; runs in an isolate via [compute] on mobile/desktop.
_BufferResult _processBuffer(_BufferRequest req) {
  var rgba = req.rgba;
  var w = req.width, h = req.height;

  // Mask first so background removal's alpha multiply preserves it.
  if (req.ovalCrop) {
    BackgroundRemovalService.applyOvalMask(rgba, w, h);
  }
  if (req.removeBackground) {
    if (req.backgroundUniform) {
      // Plain background: fast single-color keying, also handles ink that
      // touches the edge and un-blends anti-aliased strokes.
      BackgroundRemovalService.removeBackground(
        rgba,
        w,
        h,
        backgroundArgb: req.backgroundArgb,
        inkThreshold: req.inkThreshold,
        sensitivity: req.sensitivity,
        solidInkArgb: req.solidInkArgb,
      );
    } else {
      // Gradient / colored / busy background: flood-fill from the edges so a
      // single background color isn't assumed (e.g. a logo on a gradient).
      BackgroundRemovalService.removeConnectedBackground(
        rgba,
        w,
        h,
        seedReferenceArgb: req.backgroundArgb,
        localTolerance: req.connectedTolerance,
      );
    }
  }

  final transparentOutput =
      req.removeBackground || req.hasAlphaContent || req.ovalCrop;

  // Guarantee zero leftover margins: trim to the content bounding box.
  if (req.trimResult) {
    ({int left, int top, int right, int bottom})? bounds;
    if (transparentOutput) {
      bounds = BackgroundRemovalService.opaqueBounds(rgba, w, h);
    } else {
      final dm = InkDetectionService.sampledDistanceMap(
        rgba,
        w,
        h,
        backgroundArgb: req.backgroundArgb,
        useAlpha: false,
        maxDimension: math.max(w, h), // stride 1: exact trim
      );
      final box = InkDetectionService.inkBoundingBox(
        dm.map,
        dm.width,
        dm.height,
        req.inkThreshold,
      );
      if (box != null) {
        bounds = (
          left: box.left.floor(),
          top: box.top.floor(),
          right: box.right.ceil() - 1,
          bottom: box.bottom.ceil() - 1,
        );
      }
    }
    if (bounds != null) {
      final tw = bounds.right - bounds.left + 1;
      final th = bounds.bottom - bounds.top + 1;
      rgba = _cropRgba(rgba, w, bounds.left, bounds.top, tw, th);
      w = tw;
      h = th;
    }
  }

  _premultiplyInPlace(rgba);
  return _BufferResult(
    rgba: rgba,
    width: w,
    height: h,
    transparentOutput: transparentOutput,
  );
}

Uint8List _cropRgba(Uint8List src, int srcWidth, int x, int y, int w, int h) {
  final out = Uint8List(w * h * 4);
  final rowBytes = w * 4;
  for (var row = 0; row < h; row++) {
    final srcStart = (((y + row) * srcWidth) + x) * 4;
    out.setRange(row * rowBytes, (row + 1) * rowBytes, src, srcStart);
  }
  return out;
}

/// `decodeImageFromPixels` expects premultiplied alpha; our math works in
/// straight alpha, so convert as the last buffer step.
void _premultiplyInPlace(Uint8List rgba) {
  for (var i = 0; i < rgba.length; i += 4) {
    final a = rgba[i + 3];
    if (a == 255) continue;
    if (a == 0) {
      rgba[i] = 0;
      rgba[i + 1] = 0;
      rgba[i + 2] = 0;
      continue;
    }
    rgba[i] = (rgba[i] * a + 127) ~/ 255;
    rgba[i + 1] = (rgba[i + 1] * a + 127) ~/ 255;
    rgba[i + 2] = (rgba[i + 2] * a + 127) ~/ 255;
  }
}

/// Inverse of [_premultiplyInPlace], for engines that only hand out
/// premultiplied pixels (`rawRgba`).
void _unpremultiplyInPlace(Uint8List rgba) {
  for (var i = 0; i < rgba.length; i += 4) {
    final a = rgba[i + 3];
    if (a == 0 || a == 255) continue;
    rgba[i] = ((rgba[i] * 255 + a ~/ 2) ~/ a).clamp(0, 255);
    rgba[i + 1] = ((rgba[i + 1] * 255 + a ~/ 2) ~/ a).clamp(0, 255);
    rgba[i + 2] = ((rgba[i + 2] * 255 + a ~/ 2) ~/ a).clamp(0, 255);
  }
}

class _FallbackRequest {
  const _FallbackRequest({required this.bytes, required this.maxDimension});

  final Uint8List bytes;
  final int maxDimension;
}

class _FallbackResult {
  const _FallbackResult({
    required this.rgba,
    required this.width,
    required this.height,
  });

  /// Straight (un-premultiplied) RGBA.
  final Uint8List rgba;
  final int width;
  final int height;
}

/// Lenient pure-Dart decode (package:image) for files the engine codec
/// rejects — some BMP variants, unusual JPEG encodings, mildly corrupt
/// files. Slower and allocation-heavy, so it only ever runs after the
/// engine path has already failed, and always inside an isolate.
_FallbackResult? _fallbackDecode(_FallbackRequest req) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(req.bytes);
  } catch (_) {
    return null;
  }
  if (decoded == null || decoded.width == 0 || decoded.height == 0) {
    return null;
  }
  decoded = img.bakeOrientation(decoded);
  final longest = math.max(decoded.width, decoded.height);
  if (longest > req.maxDimension) {
    final scale = req.maxDimension / longest;
    decoded = img.copyResize(
      decoded,
      width: math.max(1, (decoded.width * scale).round()),
      height: math.max(1, (decoded.height * scale).round()),
      interpolation: img.Interpolation.linear,
    );
  }
  final rgbaImage = decoded.convert(format: img.Format.uint8, numChannels: 4);
  return _FallbackResult(
    rgba: Uint8List.fromList(rgbaImage.getBytes(order: img.ChannelOrder.rgba)),
    width: rgbaImage.width,
    height: rgbaImage.height,
  );
}
