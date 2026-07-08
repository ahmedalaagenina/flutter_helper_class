import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

/// Pure, isolate-safe image analysis: background estimation, ink masking
/// (Otsu thresholding) and robust content bounding-box detection.
///
/// All functions operate on raw **straight (un-premultiplied) RGBA** pixel
/// buffers (`ui.Image.toByteData(format: rawStraightRgba)`), row-major,
/// 4 bytes per pixel. No image-package dependency — this keeps the hot path
/// free of pure-Dart decoding and its allocation cost.
class InkDetectionService {
  InkDetectionService._();

  /// Distances below this are never considered ink, regardless of what Otsu
  /// picks. Guards against JPEG noise on nearly blank scans.
  static const double _minInkDistance = 0.08;

  /// Fraction of total ink allowed to be trimmed away from each side of the
  /// bounding box. Makes the box robust to dust specks and stray marks.
  static const double _speckFraction = 0.003;

  /// True when the image carries real transparency (any see-through pixels).
  /// Sampled on a grid for speed — a single transparent hit is decisive, so
  /// thin/sparse ink on a transparent canvas cannot flip the answer the way
  /// a paired opaque-pixel requirement could (misclassifying such an image
  /// as non-alpha would estimate the background from transparent black and
  /// erase the ink).
  static bool hasAlphaContent(Uint8List rgba, int width, int height) {
    final step = math.max(1, math.min(width, height) ~/ 64);
    for (var y = 0; y < height; y += step) {
      final row = y * width;
      for (var x = 0; x < width; x += step) {
        if (rgba[(row + x) * 4 + 3] < 32) return true;
      }
    }
    return false;
  }

  /// Fraction of border samples that must sit within [_bgTolerance] of the
  /// median (per channel) for the background to count as "uniform". Below
  /// this, the background is a gradient / busy / multi-color surface where
  /// single-color keying produces artifacts, so removal should be off by
  /// default.
  static const double _bgUniformFraction = 0.75;
  static const int _bgTolerance = 22;

  /// If an inner ring's median color differs from the outer border median by
  /// more than this (normalized 0..1 RGB distance), the background varies
  /// across the image — a gradient — even when the outer border alone looks
  /// uniform (e.g. a radial gradient that is dark all around the edge but
  /// bright in the middle). Such images route to flood-fill removal.
  static const double _bgGradientThreshold = 0.075;

  /// Estimates the background color from the median of the border pixels and
  /// reports whether that background is *uniform* enough for reliable
  /// single-color removal. Signatures/stamps virtually never touch all four
  /// edges, so the border ring is a reliable background sample.
  ///
  /// `uniform` is false for gradients and busy backgrounds (e.g. a logo on a
  /// dark radial gradient): there is no single background color to key on, so
  /// keying leaves banding artifacts.
  static ({int argb, bool uniform}) estimateBackground(
    Uint8List rgba,
    int width,
    int height,
  ) {
    // Per-channel medians via 256-bin histograms: one pass, no sorting.
    final histR = Uint32List(256);
    final histG = Uint32List(256);
    final histB = Uint32List(256);
    var samples = 0;
    final ring = math.max(2, (math.min(width, height) * 0.02).round());

    void sample(int x, int y) {
      final i = (y * width + x) * 4;
      histR[rgba[i]]++;
      histG[rgba[i + 1]]++;
      histB[rgba[i + 2]]++;
      samples++;
    }

    final stepX = math.max(1, width ~/ 128);
    final stepY = math.max(1, height ~/ 128);
    for (var d = 0; d < ring; d++) {
      for (var x = 0; x < width; x += stepX) {
        sample(x, d);
        sample(x, height - 1 - d);
      }
      for (var y = 0; y < height; y += stepY) {
        sample(d, y);
        sample(width - 1 - d, y);
      }
    }

    int median(Uint32List hist) {
      final half = samples ~/ 2;
      var acc = 0;
      for (var v = 0; v < 256; v++) {
        acc += hist[v];
        if (acc > half) return v;
      }
      return 255;
    }

    // Fraction of samples within ±tolerance of the channel median. A tight
    // cluster on all three channels ⇒ a single, uniform background color.
    double within(Uint32List hist, int center) {
      final lo = math.max(0, center - _bgTolerance);
      final hi = math.min(255, center + _bgTolerance);
      var acc = 0;
      for (var v = lo; v <= hi; v++) {
        acc += hist[v];
      }
      return samples == 0 ? 1.0 : acc / samples;
    }

    final mr = median(histR), mg = median(histG), mb = median(histB);
    final borderTight = within(histR, mr) >= _bgUniformFraction &&
        within(histG, mg) >= _bgUniformFraction &&
        within(histB, mb) >= _bgUniformFraction;

    // Second check: sample an inner ring (~12% inset) and compare its median
    // to the border median. A gradient that looks uniform at the very edge
    // (dark all around) but brightens toward the center shows up here as a
    // large border-vs-inner difference. Median is robust to the inner ring
    // clipping the subject, as long as the subject isn't the majority of it.
    final histR2 = Uint32List(256);
    final histG2 = Uint32List(256);
    final histB2 = Uint32List(256);
    var samples2 = 0;
    final inset = (math.min(width, height) * 0.12).round();
    final thickness = math.max(1, (math.min(width, height) * 0.02).round());

    void sample2(int x, int y) {
      if (x < 0 || y < 0 || x >= width || y >= height) return;
      final i = (y * width + x) * 4;
      histR2[rgba[i]]++;
      histG2[rgba[i + 1]]++;
      histB2[rgba[i + 2]]++;
      samples2++;
    }

    if (inset > 0 && inset * 2 < math.min(width, height)) {
      for (var d = 0; d < thickness; d++) {
        final top = inset + d, bottom = height - 1 - inset - d;
        for (var x = inset; x < width - inset; x += stepX) {
          sample2(x, top);
          sample2(x, bottom);
        }
        final left = inset + d, right = width - 1 - inset - d;
        for (var y = inset; y < height - inset; y += stepY) {
          sample2(left, y);
          sample2(right, y);
        }
      }
    }

    var uniform = borderTight;
    if (uniform && samples2 > 0) {
      int median2(Uint32List hist) {
        final half = samples2 ~/ 2;
        var acc = 0;
        for (var v = 0; v < 256; v++) {
          acc += hist[v];
          if (acc > half) return v;
        }
        return 255;
      }

      final ir = median2(histR2), ig = median2(histG2), ib = median2(histB2);
      final dr = (ir - mr), dg = (ig - mg), db = (ib - mb);
      final dist = math.sqrt(dr * dr + dg * dg + db * db) / 441.6729559;
      if (dist > _bgGradientThreshold) uniform = false;
    }

    return (argb: 0xFF000000 | (mr << 16) | (mg << 8) | mb, uniform: uniform);
  }

  /// Background color only — kept for callers that don't need the uniformity
  /// flag.
  static int estimateBackgroundColorArgb(
    Uint8List rgba,
    int width,
    int height,
  ) {
    return estimateBackground(rgba, width, height).argb;
  }

  /// Normalized (0..1) Euclidean RGB distance between a pixel and the
  /// background color.
  static double pixelDistance(int r, int g, int b, int bgArgb) {
    final dr = r - ((bgArgb >> 16) & 0xFF);
    final dg = g - ((bgArgb >> 8) & 0xFF);
    final db = b - (bgArgb & 0xFF);
    // 441.67 = sqrt(3 * 255^2), the max possible distance.
    return math.sqrt(dr * dr + dg * dg + db * db) / 441.6729559;
  }

  /// Builds a 0..255 distance-from-background map, sampling the buffer on a
  /// grid so the cost is bounded by [maxDimension] regardless of input size.
  /// When [useAlpha] is set the alpha channel itself is the map (the image
  /// already has transparency, so alpha *is* the ink signal).
  ///
  /// The returned `stride` maps sampled coordinates back to source pixels
  /// (`sourceX = sampledX * stride`).
  static ({Uint8List map, int width, int height, int stride}) sampledDistanceMap(
    Uint8List rgba,
    int width,
    int height, {
    required int backgroundArgb,
    required bool useAlpha,
    required int maxDimension,
  }) {
    final stride = math.max(1, (math.max(width, height) / maxDimension).ceil());
    final sw = ((width - 1) ~/ stride) + 1;
    final sh = ((height - 1) ~/ stride) + 1;
    final map = Uint8List(sw * sh);
    var i = 0;
    for (var sy = 0; sy < sh; sy++) {
      final rowBase = (sy * stride) * width;
      for (var sx = 0; sx < sw; sx++) {
        final p = (rowBase + sx * stride) * 4;
        if (useAlpha) {
          map[i++] = rgba[p + 3];
        } else {
          final d = pixelDistance(rgba[p], rgba[p + 1], rgba[p + 2], backgroundArgb);
          map[i++] = (d * 255).round().clamp(0, 255);
        }
      }
    }
    return (map: map, width: sw, height: sh, stride: stride);
  }

  /// Otsu's method over a 256-bin histogram of the distance map. Returns the
  /// threshold as a 0..1 fraction, floored at [_minInkDistance].
  static double otsuThreshold(List<int> distanceMap) {
    final hist = List<int>.filled(256, 0);
    for (final v in distanceMap) {
      hist[v]++;
    }
    final total = distanceMap.length;

    var sumAll = 0.0;
    for (var t = 0; t < 256; t++) {
      sumAll += t * hist[t];
    }

    var sumB = 0.0;
    var weightB = 0;
    var maxVariance = -1.0;
    var best = 128;
    for (var t = 0; t < 256; t++) {
      weightB += hist[t];
      if (weightB == 0) continue;
      final weightF = total - weightB;
      if (weightF == 0) break;
      sumB += t * hist[t];
      final meanB = sumB / weightB;
      final meanF = (sumAll - sumB) / weightF;
      final between =
          weightB.toDouble() * weightF.toDouble() * (meanB - meanF) * (meanB - meanF);
      if (between > maxVariance) {
        maxVariance = between;
        best = t;
      }
    }
    return math.max(best / 255.0, _minInkDistance);
  }

  /// Finds the bounding box of ink pixels, trimming up to [_speckFraction]
  /// of the ink from each side so isolated dust specks don't inflate the box.
  /// Returns null when the image contains no ink at all.
  static Rect? inkBoundingBox(
    List<int> map,
    int width,
    int height,
    double threshold,
  ) {
    final t = (threshold * 255).round();
    final rowInk = List<int>.filled(height, 0);
    final colInk = List<int>.filled(width, 0);
    var total = 0;

    var i = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (map[i++] >= t) {
          rowInk[y]++;
          colInk[x]++;
          total++;
        }
      }
    }
    if (total == 0) return null;

    final allow = math.max(1, (total * _speckFraction).round());

    int trimForward(List<int> ink) {
      var acc = 0, pos = 0;
      while (pos < ink.length && acc + ink[pos] <= allow) {
        acc += ink[pos];
        pos++;
      }
      return math.min(pos, ink.length - 1);
    }

    int trimBackward(List<int> ink) {
      var acc = 0, pos = ink.length - 1;
      while (pos >= 0 && acc + ink[pos] <= allow) {
        acc += ink[pos];
        pos--;
      }
      return math.max(pos, 0);
    }

    final top = trimForward(rowInk);
    final bottom = trimBackward(rowInk);
    final left = trimForward(colInk);
    final right = trimBackward(colInk);
    if (bottom < top || right < left) return null;

    return Rect.fromLTRB(
      left.toDouble(),
      top.toDouble(),
      (right + 1).toDouble(),
      (bottom + 1).toDouble(),
    );
  }

  /// Expands [box] by [fraction] of its longest side, clamped to the image.
  static Rect padBox(Rect box, double fraction, int width, int height) {
    final pad = box.longestSide * fraction;
    return Rect.fromLTRB(
      math.max(0, box.left - pad),
      math.max(0, box.top - pad),
      math.min(width.toDouble(), box.right + pad),
      math.min(height.toDouble(), box.bottom + pad),
    );
  }
}
