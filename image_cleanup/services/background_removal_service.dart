import 'dart:math' as math;
import 'dart:typed_data';

import 'ink_detection_service.dart';

/// Converts a (near-)uniform background to transparency while preserving the
/// ink's anti-aliased edges. Pure and isolate-safe.
///
/// All functions operate in place on raw **straight (un-premultiplied) RGBA**
/// buffers, row-major, 4 bytes per pixel.
class BackgroundRemovalService {
  BackgroundRemovalService._();

  /// Turns the buffer's background into transparency, in place.
  ///
  /// For every pixel the color distance from [backgroundArgb] is mapped to
  /// alpha through a smooth ramp centered on [inkThreshold] (the Otsu
  /// threshold from the detection pass). [sensitivity] (0..1) shifts the
  /// ramp: higher keeps faint strokes, lower removes more background.
  ///
  /// Partially transparent pixels are "un-blended" from the background color
  /// so anti-aliased stroke edges don't keep a halo of the old background.
  /// When [solidInkArgb] is non-null all ink is recolored to that color
  /// (alpha preserved) for a crisp uniform result.
  static void removeBackground(
    Uint8List rgba,
    int width,
    int height, {
    required int backgroundArgb,
    required double inkThreshold,
    double sensitivity = 0.5,
    int? solidInkArgb,
  }) {
    final s = sensitivity.clamp(0.0, 1.0);
    // s = 0.5 gives a ramp from 0.5*t to 1.2*t.
    var low = inkThreshold * (0.8 - 0.6 * s);
    var high = inkThreshold * (1.8 - 1.2 * s);
    high = math.min(high, 1.0);
    if (high - low < 0.01) low = math.max(0, high - 0.01);

    final bgR = (backgroundArgb >> 16) & 0xFF;
    final bgG = (backgroundArgb >> 8) & 0xFF;
    final bgB = backgroundArgb & 0xFF;
    final inkR = solidInkArgb != null ? (solidInkArgb >> 16) & 0xFF : 0;
    final inkG = solidInkArgb != null ? (solidInkArgb >> 8) & 0xFF : 0;
    final inkB = solidInkArgb != null ? solidInkArgb & 0xFF : 0;

    final count = width * height;
    for (var i = 0; i < count; i++) {
      final p = i * 4;
      final d = InkDetectionService.pixelDistance(
        rgba[p],
        rgba[p + 1],
        rgba[p + 2],
        backgroundArgb,
      );
      final a = _smoothstep(low, high, d);
      final alpha = a * (rgba[p + 3] / 255.0);

      if (alpha <= 0.003) {
        rgba[p] = 0;
        rgba[p + 1] = 0;
        rgba[p + 2] = 0;
        rgba[p + 3] = 0;
        continue;
      }

      if (solidInkArgb != null) {
        rgba[p] = inkR;
        rgba[p + 1] = inkG;
        rgba[p + 2] = inkB;
        rgba[p + 3] = (alpha * 255).round();
        continue;
      }

      if (alpha < 1.0) {
        // Observed = alpha * ink + (1 - alpha) * background  →  solve for ink.
        rgba[p] = ((rgba[p] - (1 - alpha) * bgR) / alpha).round().clamp(0, 255);
        rgba[p + 1] =
            ((rgba[p + 1] - (1 - alpha) * bgG) / alpha).round().clamp(0, 255);
        rgba[p + 2] =
            ((rgba[p + 2] - (1 - alpha) * bgB) / alpha).round().clamp(0, 255);
        rgba[p + 3] = (alpha * 255).round();
      }
    }
  }

  /// Makes everything outside the ellipse inscribed in the buffer's bounds
  /// transparent, in place, with a lightly feathered (anti-aliased) edge.
  /// Used for oval-shaped crops (round stamps).
  static void applyOvalMask(
    Uint8List rgba,
    int width,
    int height, {
    double featherPx = 1.5,
  }) {
    final rx = width / 2.0;
    final ry = height / 2.0;
    if (rx <= 0 || ry <= 0) return;
    final cx = (width - 1) / 2.0;
    final cy = (height - 1) / 2.0;
    // Feather width in normalized ellipse space.
    final feather = featherPx / math.min(rx, ry);

    for (var y = 0; y < height; y++) {
      final ny = (y - cy) / ry;
      final rowBase = y * width;
      for (var x = 0; x < width; x++) {
        final nx = (x - cx) / rx;
        final d = math.sqrt(nx * nx + ny * ny);
        if (d <= 1 - feather) continue;
        final p = (rowBase + x) * 4;
        if (d >= 1) {
          rgba[p] = 0;
          rgba[p + 1] = 0;
          rgba[p + 2] = 0;
          rgba[p + 3] = 0;
          continue;
        }
        final factor = (1 - d) / feather;
        rgba[p + 3] = (rgba[p + 3] * factor).round();
      }
    }
  }

  /// Removes the background by **flood-filling inward from the edges**,
  /// absorbing each neighbor only when it is nearly identical to the pixel it
  /// grew from ([localTolerance], a normalized 0..1 RGB step). Because the
  /// test is between *adjacent* pixels, a smooth gradient is followed all the
  /// way in (each step is tiny) while a hard color change — the boundary of a
  /// logo or subject — stops the flood. Background enclosed by the subject is
  /// never reached, so it is preserved.
  ///
  /// This is the counterpart to [removeBackground] for **non-uniform**
  /// backgrounds (gradients, colored surfaces) where a single background
  /// color cannot be keyed. Colors are left unchanged; only alpha is edited,
  /// with a 1px feather so the cut edge isn't jagged.
  static void removeConnectedBackground(
    Uint8List rgba,
    int width,
    int height, {
    required int seedReferenceArgb,
    double localTolerance = 0.06,
    double seedTolerance = 0.22,
  }) {
    final count = width * height;
    if (count == 0) return;
    const maxDist = 441.6729559; // sqrt(3*255^2)
    final tolSq = math.pow(localTolerance * maxDist, 2).toDouble();
    final seedTolSq = math.pow(seedTolerance * maxDist, 2).toDouble();
    final refR = (seedReferenceArgb >> 16) & 0xFF;
    final refG = (seedReferenceArgb >> 8) & 0xFF;
    final refB = seedReferenceArgb & 0xFF;

    final isBg = Uint8List(count); // 1 once flooded as background
    final stack = <int>[];

    // Only seed border pixels that look like the estimated background color.
    // This protects a subject that happens to touch an edge (e.g. a signature
    // stroke running off the page) from being flooded away.
    void seed(int i) {
      if (isBg[i] != 0) return;
      final p = i * 4;
      final dr = rgba[p] - refR;
      final dg = rgba[p + 1] - refG;
      final db = rgba[p + 2] - refB;
      if (dr * dr + dg * dg + db * db > seedTolSq) return;
      isBg[i] = 1;
      stack.add(i);
    }

    for (var x = 0; x < width; x++) {
      seed(x); // top row
      seed((height - 1) * width + x); // bottom row
    }
    for (var y = 0; y < height; y++) {
      seed(y * width); // left col
      seed(y * width + width - 1); // right col
    }

    void tryGrow(int j, int r, int g, int b) {
      if (isBg[j] != 0) return;
      final pj = j * 4;
      final dr = rgba[pj] - r;
      final dg = rgba[pj + 1] - g;
      final db = rgba[pj + 2] - b;
      if (dr * dr + dg * dg + db * db <= tolSq) {
        isBg[j] = 1;
        stack.add(j);
      }
    }

    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      final pi = i * 4;
      final r = rgba[pi], g = rgba[pi + 1], b = rgba[pi + 2];
      final x = i % width;
      if (x > 0) tryGrow(i - 1, r, g, b);
      if (x < width - 1) tryGrow(i + 1, r, g, b);
      if (i >= width) tryGrow(i - width, r, g, b);
      if (i < count - width) tryGrow(i + width, r, g, b);
    }

    for (var i = 0; i < count; i++) {
      if (isBg[i] != 0) rgba[i * 4 + 3] = 0;
    }
    _featherAlphaEdges(rgba, width, height);
  }

  /// One-pixel anti-alias of the alpha channel so a hard flood-fill cut
  /// doesn't leave a stair-stepped edge. Averages each boundary pixel's alpha
  /// with its 4-neighbors; solid interior and fully-clear areas are untouched.
  static void _featherAlphaEdges(Uint8List rgba, int width, int height) {
    final count = width * height;
    final src = Uint8List(count);
    for (var i = 0; i < count; i++) {
      src[i] = rgba[i * 4 + 3];
    }
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = y * width + x;
        final a = src[i];
        // Only touch boundary pixels (a neighbor differs in opacity).
        final left = x > 0 ? src[i - 1] : a;
        final right = x < width - 1 ? src[i + 1] : a;
        final up = y > 0 ? src[i - width] : a;
        final down = y < height - 1 ? src[i + width] : a;
        if (left == a && right == a && up == a && down == a) continue;
        rgba[i * 4 + 3] = ((a + left + right + up + down) / 5).round();
      }
    }
  }

  /// Bounding box of pixels with alpha above a small cutoff, or null when
  /// the buffer is fully transparent.
  static ({int left, int top, int right, int bottom})? opaqueBounds(
    Uint8List rgba,
    int width,
    int height, {
    int alphaCutoff = 8,
  }) {
    var left = width, top = height, right = -1, bottom = -1;
    for (var y = 0; y < height; y++) {
      final rowBase = y * width;
      for (var x = 0; x < width; x++) {
        if (rgba[(rowBase + x) * 4 + 3] > alphaCutoff) {
          if (x < left) left = x;
          if (x > right) right = x;
          if (y < top) top = y;
          if (y > bottom) bottom = y;
        }
      }
    }
    if (right < left || bottom < top) return null;
    return (left: left, top: top, right: right, bottom: bottom);
  }

  static double _smoothstep(double low, double high, double x) {
    if (x <= low) return 0;
    if (x >= high) return 1;
    final t = (x - low) / (high - low);
    return t * t * (3 - 2 * t);
  }
}
