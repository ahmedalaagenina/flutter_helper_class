import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:idara_esign/core/services/logger_service.dart';
import 'package:idara_esign/core/widgets/app_snack_bars.dart';
import 'package:idara_esign/generated/l10n.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service for handling document file operations (download, share)
/// Follows clean architecture - UI-agnostic business logic
class DocumentFileService {
  /// Share a document via the system share dialog
  ///
  /// Creates a temporary file and opens the native share sheet
  Future<void> shareDocument({
    required Uint8List pdfBytes,
    required String fileName,
    required BuildContext context,
  }) async {
    final s = S.of(context);
    try {
      // Save to temporary directory for sharing
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      // Share the file using system share dialog
      final result = await Share.shareXFiles(
        [XFile(filePath)],
        subject: fileName.replaceAll('.pdf', ''),
        text: s.sharingDocumentText(fileName.replaceAll('.pdf', '')),
      );

      if (context.mounted) {
        if (result.status == ShareResultStatus.success) {
          AppSnackBars.success(s.documentSharedSuccessfully);
        }
        // No message if dismissed - user just closed the dialog
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBars.error(s.failedToShareDocument(e.toString()));
      }
    }
  }

  /// Download a document to user-selected location
  ///
  /// Uses Storage Access Framework (no permissions needed on Android 10+)
  Future<void> downloadDocument({
    required Uint8List pdfBytes,
    required String fileName,
    required BuildContext context,
  }) async {
    final s = S.of(context);
    try {
      String? outputFile = await FilePicker.saveFile(
        dialogTitle: s.chooseSaveLocation,
        fileName: "$fileName.pdf",
        bytes: pdfBytes,
        allowedExtensions: ['pdf'],
      );

      if (outputFile == null && !kIsWeb) {
        AppSnackBars.error(s.failedToDownload('User cancelled'));
        return;
      }

      AppSnackBars.success(s.savedTo(fileName));
    } catch (e) {
      AppLog.e(e.toString());
      AppSnackBars.error(s.failedToDownload(e.toString()));
    }
  }

  Future<PlatformFile?> pickDocumentFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      withData: true,
      allowedExtensions: const ['pdf'],
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    return file;
  }
}
