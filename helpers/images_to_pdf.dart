import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf;

/// Builds a single PDF from a list of image bytes — one image per page, in the
/// order given. Each page is sized to the image's aspect ratio, scaled to fit
/// within A4 so the resulting document has sensible page dimensions.
///
/// Runs the (CPU-bound) PDF assembly on a background isolate.
Future<Uint8List> buildPdfFromImages(List<Uint8List> images) {
  return compute(_buildWorker, images);
}

// A4 in points (72 dpi). Pages are scaled to fit inside this box.
const double _a4Width = 595.0;
const double _a4Height = 842.0;

Uint8List _buildWorker(List<Uint8List> images) {
  final document = pdf.PdfDocument();
  // Maximise compression of the page content streams. The embedded JPEGs are
  // already compressed at pick time; this trims the remaining PDF overhead.
  document.compressionLevel = pdf.PdfCompressionLevel.best;
  document.pageSettings.setMargins(0);

  for (final imageBytes in images) {
    final bitmap = pdf.PdfBitmap(imageBytes);
    final widthPx = bitmap.width.toDouble();
    final heightPx = bitmap.height.toDouble();

    Size pageSize;
    if (widthPx <= 0 || heightPx <= 0) {
      pageSize = const Size(_a4Width, _a4Height);
    } else {
      // Scale to fit within A4 (never upscale beyond the original pixel size).
      final scale = math.min(
        1.0,
        math.min(_a4Width / widthPx, _a4Height / heightPx),
      );
      pageSize = Size(widthPx * scale, heightPx * scale);
    }

    document.pageSettings.size = pageSize;
    final page = document.pages.add();
    page.graphics.drawImage(
      bitmap,
      Rect.fromLTWH(0, 0, pageSize.width, pageSize.height),
    );
  }

  final bytes = Uint8List.fromList(document.saveSync());
  document.dispose();
  return bytes;
}
