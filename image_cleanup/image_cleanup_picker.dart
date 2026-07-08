// APP-INTEGRATION GLUE — depends on this app's picker, snackbars and l10n.
// The portable core of the module (domain/services/presentation) does not
// import any of those; when copying the module into another app, rewrite or
// drop this file against that app's equivalents.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:idara_esign/core/helpers/image_picker_helper.dart';
import 'package:idara_esign/core/responsive/breakpoints.dart';
import 'package:idara_esign/core/widgets/app_snack_bars.dart';
import 'package:idara_esign/generated/l10n.dart';
import 'package:image_picker/image_picker.dart';

import 'domain/cleanup_options.dart';
import 'helpers/image_cleanup_helper.dart';
import 'services/image_cleanup_service.dart';

enum _PickChoice { edit, original }

/// The one pick → choose → clean/normalize pipeline shared by every upload
/// surface (stamps, signatures), so accepted formats, error feedback, and
/// cancel handling cannot drift between them.
class ImageCleanupPicker {
  ImageCleanupPicker._();

  /// Lets the user pick a gallery image, choose between **Edit & Cleanup**
  /// (the interactive crop/background-removal flow) and **Use Original**
  /// (no visual changes — silently re-encoded so the output format is still
  /// guaranteed), and returns the resulting PNG bytes.
  ///
  /// Returns null when the user cancels at any step or the pick fails
  /// (feedback is shown here via snackbars). Either path yields an 8-bit
  /// RGBA PNG, which is what PDF generation requires.
  ///
  /// Callers must still check `mounted` before using their State after
  /// awaiting this (it spans a full navigation).
  static Future<Uint8List?> pickAndClean(
    BuildContext context, {
    CleanupOptions options = const CleanupOptions(),
  }) async {
    // Preserve the original file: image_picker would otherwise re-encode
    // PNGs to JPEG on Android. Any decodable image is fine — both paths
    // below output a PNG regardless of the input format.
    final outcome = await ImagePickerHelper.pickSingle(
      source: ImageSource.gallery,
      options: const ImagePickOptions(
        preserveOriginal: true,
        allowedExtensions: {'png', 'jpg', 'jpeg', 'webp'},
      ),
    );
    final picked = outcome.result?.file;
    if (picked == null) {
      final failure = outcome.failure;
      if (failure != null && failure.type != PickFailureType.cancelled) {
        AppSnackBars.error(failure.message);
      }
      return null;
    }

    final bytes = await picked.readAsBytes();
    if (!context.mounted) return null;
    if (!ImageCleanupHelper.isSupportedImage(bytes)) {
      AppSnackBars.warning(S.of(context).unsupportedImageFormat);
      return null;
    }

    final choice = await _askEditOrOriginal(context);
    if (choice == null || !context.mounted) return null;

    switch (choice) {
      case _PickChoice.edit:
        final cleaned = await ImageCleanupHelper.cleanImage(
          context,
          bytes: bytes,
          options: options,
        );
        return cleaned?.pngBytes;

      case _PickChoice.original:
        // Silent normalization: pixels untouched, but decode → engine PNG
        // encode guarantees the 8-bit RGBA PNG the backend/PDFs expect.
        final normalized = await ImageCleanupService.normalizeToPng(bytes);
        if (normalized == null && context.mounted) {
          AppSnackBars.error(S.of(context).imageCleanupCouldNotReadImage);
        }
        return normalized;
    }
  }

  /// Offers the two paths adaptively: a bottom sheet on phone-width
  /// layouts, a centered dialog on wide layouts (web/tablet), where a
  /// bottom-anchored full-width sheet would look out of place.
  /// Resolves null when dismissed.
  static Future<_PickChoice?> _askEditOrOriginal(BuildContext context) {
    final isCompact =
        MediaQuery.sizeOf(context).width < kMobileBreakPoint;
    if (isCompact) {
      return showModalBottomSheet<_PickChoice>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  S.of(context).imageCleanupChoiceTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              ..._choiceTiles(sheetContext),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }
    return showDialog<_PickChoice>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(
          S.of(context).imageCleanupChoiceTitle,
          textAlign: TextAlign.center,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        children: _choiceTiles(dialogContext),
      ),
    );
  }

  /// The two option rows, shared by the sheet and the dialog so the copy
  /// and behavior cannot diverge between form factors.
  static List<Widget> _choiceTiles(BuildContext context) {
    final s = S.of(context);
    return [
      ListTile(
        leading: const Icon(Icons.auto_fix_high_outlined),
        title: Text(s.imageCleanupChoiceEdit),
        subtitle: Text(s.imageCleanupChoiceEditDesc),
        onTap: () => Navigator.of(context).pop(_PickChoice.edit),
      ),
      ListTile(
        leading: const Icon(Icons.file_upload_outlined),
        title: Text(s.imageCleanupChoiceOriginal),
        subtitle: Text(s.imageCleanupChoiceOriginalDesc),
        onTap: () => Navigator.of(context).pop(_PickChoice.original),
      ),
    ];
  }
}
