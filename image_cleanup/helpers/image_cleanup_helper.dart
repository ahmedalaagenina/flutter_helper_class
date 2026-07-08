import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../domain/cleanup_options.dart';
import '../domain/cleanup_result.dart';
import '../presentation/pages/image_cleanup_page.dart';

/// One-line entry point for the cleanup flow.
///
/// ```dart
/// final result = await ImageCleanupHelper.cleanImage(context, bytes: picked);
/// if (result != null) upload(result.pngBytes);
/// ```
class ImageCleanupHelper {
  ImageCleanupHelper._();

  /// Pushes the cleanup flow and resolves with the cleaned PNG, or null when
  /// the user cancels. Uses plain [Navigator] so it works with any routing
  /// setup (go_router, auto_route, vanilla).
  static Future<CleanupResult?> cleanImage(
    BuildContext context, {
    required Uint8List bytes,
    CleanupOptions options = const CleanupOptions(),
    bool useRootNavigator = true,
  }) {
    return Navigator.of(context, rootNavigator: useRootNavigator)
        .push<CleanupResult>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => ImageCleanupPage(
              imageBytes: bytes,
              options: options,
            ),
          ),
        );
  }

  /// Quick magic-byte check for the formats the pipeline can decode
  /// (PNG, JPEG, WebP, GIF, BMP). Use to reject unsupported picks early
  /// without decoding.
  static bool isSupportedImage(Uint8List bytes) {
    if (bytes.length < 12) return false;
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E) return true;
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // WebP: "RIFF" .... "WEBP"
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    // GIF: "GIF8"
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    // BMP: "BM"
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return true;
    // TIFF: "II*\0" or "MM\0*" (decoded via the pure-Dart fallback).
    if (bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A) return true;
    if (bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[3] == 0x2A) return true;
    return false;
  }
}
