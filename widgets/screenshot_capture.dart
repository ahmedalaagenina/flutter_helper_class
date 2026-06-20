import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

/// Outcome of a capture-and-act operation. Returned (instead of throwing or
/// showing a snackbar internally) so callers stay in control of localized
/// messaging — this widget is intentionally string-free and reusable across
/// apps.
enum CaptureResult {
  /// Bytes were produced and the action (share/save) completed.
  success,

  /// The user backed out (dismissed the share sheet / cancelled the save).
  cancelled,

  /// Capture failed or the action errored.
  failure,
}

/// Controller that drives a [ScreenshotCapture] subtree and exposes high-level
/// actions (capture → share / save).
///
/// ```dart
/// final shot = ScreenshotCaptureController();
/// // ...
/// ScreenshotCapture(controller: shot, child: ReceiptCard(...));
/// // elsewhere (e.g. an AppBar action):
/// final result = await shot.share(fileName: 'receipt');
/// ```
class ScreenshotCaptureController {
  ScreenshotCaptureController({this.pixelRatio = 3.0});

  /// Output resolution multiplier. Higher = sharper but heavier; 3.0 ≈ retina.
  final double pixelRatio;

  final ScreenshotController _engine = ScreenshotController();

  /// Captures the attached [ScreenshotCapture] subtree to PNG bytes.
  /// Returns null when nothing is attached yet or the capture fails.
  Future<Uint8List?> capture({double? pixelRatio}) async {
    try {
      return await _engine.capture(pixelRatio: pixelRatio ?? this.pixelRatio);
    } catch (_) {
      return null;
    }
  }

  /// Renders an arbitrary [widget] that is NOT in the tree (off-screen) and
  /// returns its PNG bytes. Handy for building a shareable card the user never
  /// actually sees on screen.
  Future<Uint8List?> captureWidget(
    Widget widget, {
    BuildContext? context,
    Size? targetSize,
    double? pixelRatio,
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    try {
      return await _engine.captureFromWidget(
        widget,
        context: context,
        pixelRatio: pixelRatio ?? this.pixelRatio,
        targetSize: targetSize,
        delay: delay,
      );
    } catch (_) {
      return null;
    }
  }

  /// Captures the subtree, then opens the native share sheet.
  ///
  /// [sharePositionOrigin] is required for a correct popover anchor on iPad;
  /// pass the source widget's global rect when triggering from a button.
  Future<CaptureResult> share({
    String fileName = 'screenshot',
    String? text,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    final bytes = await capture();
    if (bytes == null) return CaptureResult.failure;
    return ScreenshotFiles.shareBytes(
      bytes,
      fileName: fileName,
      text: text,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Captures the subtree, then lets the user pick a save location
  /// (Storage Access Framework on Android — no runtime permission needed;
  /// the Files app on iOS/desktop).
  Future<CaptureResult> save({
    String fileName = 'screenshot',
    String? dialogTitle,
  }) async {
    final bytes = await capture();
    if (bytes == null) return CaptureResult.failure;
    return ScreenshotFiles.saveBytes(
      bytes,
      fileName: fileName,
      dialogTitle: dialogTitle,
    );
  }
}

/// Wraps [child] so its rendered pixels can be captured via [controller].
/// A thin, dependency-hiding shim over the `screenshot` package.
class ScreenshotCapture extends StatelessWidget {
  const ScreenshotCapture({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScreenshotCaptureController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Screenshot(controller: controller._engine, child: child);
  }
}

/// Low-level, widget-free actions on already-captured PNG [Uint8List] bytes.
/// Exposed separately so callers that already hold image bytes (e.g. from a
/// `RepaintBoundary` or the network) can share/save without a controller.
abstract final class ScreenshotFiles {
  /// Writes [bytes] to a temp PNG and opens the native share sheet.
  static Future<CaptureResult> shareBytes(
    Uint8List bytes, {
    String fileName = 'screenshot',
    String? text,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${_ensurePng(fileName)}';
      await File(path).writeAsBytes(bytes, flush: true);

      final result = await Share.shareXFiles(
        [XFile(path, mimeType: 'image/png')],
        text: text,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      );

      return switch (result.status) {
        ShareResultStatus.success => CaptureResult.success,
        ShareResultStatus.dismissed => CaptureResult.cancelled,
        ShareResultStatus.unavailable => CaptureResult.failure,
      };
    } catch (_) {
      return CaptureResult.failure;
    }
  }

  /// Saves [bytes] to a user-chosen location as a PNG.
  static Future<CaptureResult> saveBytes(
    Uint8List bytes, {
    String fileName = 'screenshot',
    String? dialogTitle,
  }) async {
    try {
      final output = await FilePicker.saveFile(
        dialogTitle: dialogTitle,
        fileName: _ensurePng(fileName),
        bytes: bytes,
        type: FileType.image,
        allowedExtensions: const ['png'],
      );

      // On mobile, a null result means the user cancelled. On web the picker
      // returns null even on success (the download is triggered by bytes).
      if (output == null && !kIsWeb) return CaptureResult.cancelled;
      return CaptureResult.success;
    } catch (_) {
      return CaptureResult.failure;
    }
  }

  static String _ensurePng(String name) =>
      name.toLowerCase().endsWith('.png') ? name : '$name.png';
}
