import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
/*
═══════════════════════════════════════════════════════════════════════
IMAGE PICKER HELPER (Clean Architecture Version)
═══════════════════════════════════════════════════════════════════════

This helper:
✔ Supports Android / iOS / Web
✔ Returns structured result (Success / Failure)
✔ Does NOT show dialogs internally
✔ Lets UI decide how to handle errors
✔ Supports:
    - Allowed image types
    - Max file size
    - Optional resizing
    - Force compression
    - Web strict size enforcement

───────────────────────────────────────────────────────────────────────
SINGLE IMAGE EXAMPLE
───────────────────────────────────────────────────────────────────────

final outcome = await ImagePickerHelperClean.pickSingle(
  source: ImageSource.gallery,
  options: ImagePickOptions(
    allowedExtensions: {'jpg', 'jpeg', 'png'},
    maxSizeBytes: 1 * 1024 * 1024, // 1MB
    maxWidth: 1920,
    maxHeight: 1920,
    outputFormat: CompressFormat.jpeg,
  ),
);

if (!outcome.isSuccess) {
  // Handle error in UI
  final error = outcome.failure!;
  print('Error: ${error.type} - ${error.message}');

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.message)),
  );
  return;
}

// SUCCESS
final result = outcome.result!;
print(result); // Example:
               // PickResult(original: 2.34 MB, final: 845.21 KB, compressed: true, passes: 2)

final XFile file = result.file;

// On mobile:
print(file.path);

// On web:
final bytes = await file.readAsBytes();


───────────────────────────────────────────────────────────────────────
MULTIPLE IMAGES EXAMPLE
───────────────────────────────────────────────────────────────────────

final multiOutcome = await ImagePickerHelperClean.pickMultiple(
  options: ImagePickOptions(
    maxSizeBytes: 2 * 1024 * 1024, // 2MB
    outputFormat: CompressFormat.jpeg,
  ),
);

if (!multiOutcome.isSuccess) {
  print('Failure: ${multiOutcome.failure?.message}');
  return;
}

final images = multiOutcome.results!;

for (final img in images) {
  print(img);
}

// If some images failed but others succeeded:
if (multiOutcome.failures.isNotEmpty) {
  for (final failure in multiOutcome.failures) {
    print('One image failed: ${failure.message}');
  }
}

───────────────────────────────────────────────────────────────────────
COMMON OPTIONS EXPLAINED
───────────────────────────────────────────────────────────────────────

allowedExtensions:
    Restrict file types.
    Example: {'jpg','png'}

maxSizeBytes:
    Hard size limit.
    Example: 1 * 1024 * 1024 (1MB)

absoluteMaxBytes:
    Safety cap (default 50MB).

maxWidth / maxHeight:
    Resize image before compression.

outputFormat:
    Convert to JPEG / WEBP / PNG.
    JPEG usually best for size reduction.

forceProcessEvenIfUnderLimit:
    If true, image will still be processed even if under size limit.

enforceMaxSizeOnWebWithoutCompression:
    On Web, if true, image larger than maxSizeBytes will be rejected
    because compression isn't reliable.

───────────────────────────────────────────────────────────────────────
ERROR TYPES
───────────────────────────────────────────────────────────────────────

PickFailureType.cancelled
PickFailureType.permissionDenied
PickFailureType.unsupportedType
PickFailureType.tooLarge
PickFailureType.platform
PickFailureType.unknown

UI decides how to display these.

═══════════════════════════════════════════════════════════════════════
*/

class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  // ─────────────────────── Public API ───────────────────────

  static Future<PickOutcome> pickSingle({
    required ImageSource source,
    ImagePickOptions options = const ImagePickOptions(),
  }) async {
    try {
      final XFile? file;
      if (kIsWeb) {
        file = await _pickWebSingle(options: options);
      } else {
        file = await _picker.pickImage(
          source: source,
          imageQuality: options.initialQuality,
          maxWidth: options.maxWidth,
          maxHeight: options.maxHeight,
        );
      }

      if (file == null) return const PickOutcome.cancelled();

      final result = await _validateAndMaybeReduce(file, options: options);
      return PickOutcome.success(result);
    } on PlatformException catch (e) {
      return PickOutcome.failure(PickFailure.fromPlatformException(e));
    } catch (e) {
      return PickOutcome.failure(
        PickFailure(
          type: PickFailureType.unknown,
          message: 'Unexpected error: $e',
        ),
      );
    }
  }

  static Future<MultiPickOutcome> pickMultiple({
    ImagePickOptions options = const ImagePickOptions(),
  }) async {
    try {
      final List<XFile> files;

      if (kIsWeb) {
        files = await _pickWebMultiple(options: options);
      } else {
        files = await _picker.pickMultiImage(
          imageQuality: options.initialQuality,
          maxWidth: options.maxWidth,
          maxHeight: options.maxHeight,
        );
      }

      if (files.isEmpty) return const MultiPickOutcome.cancelled();

      final results = <PickResult>[];
      final failures = <PickFailure>[];

      for (final f in files) {
        try {
          results.add(await _validateAndMaybeReduce(f, options: options));
        } catch (e) {
          failures.add(
            e is PickFailure
                ? e
                : PickFailure(
                    type: PickFailureType.unknown,
                    message: 'Unexpected error: $e',
                  ),
          );
        }
      }

      // If all files failed, return a single Failure (or return the list of failures)
      if (results.isEmpty) {
        return MultiPickOutcome.failure(
          failures.isNotEmpty
              ? failures.first
              : const PickFailure(
                  type: PickFailureType.unknown,
                  message: 'No images were processed.',
                ),
          failures: failures,
        );
      }

      return MultiPickOutcome.success(results, failures: failures);
    } on PlatformException catch (e) {
      return MultiPickOutcome.failure(PickFailure.fromPlatformException(e));
    } catch (e) {
      return MultiPickOutcome.failure(
        PickFailure(
          type: PickFailureType.unknown,
          message: 'Unexpected error: $e',
        ),
      );
    }
  }

  // ─────────────────────── Web pickers ───────────────────────

  static Future<XFile?> _pickWebSingle({
    required ImagePickOptions options,
  }) async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: _filePickerType(options),
      allowedExtensions: _normalizedFilePickerExtensions(options),
    );

    if (picked == null || picked.files.isEmpty) return null;

    final f = picked.files.single;
    final bytes = f.bytes;
    if (bytes == null) return null;

    final mimeType = lookupMimeType(f.name);
    return XFile.fromData(bytes, name: f.name, mimeType: mimeType);
  }

  static Future<List<XFile>> _pickWebMultiple({
    required ImagePickOptions options,
  }) async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: _filePickerType(options),
      allowedExtensions: _normalizedFilePickerExtensions(options),
    );

    if (picked == null || picked.files.isEmpty) return [];

    final out = <XFile>[];
    for (final f in picked.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      final mimeType = lookupMimeType(f.name);
      out.add(XFile.fromData(bytes, name: f.name, mimeType: mimeType));
    }
    return out;
  }

  // ───────────────── Validation + reduce ─────────────────

  static Future<PickResult> _validateAndMaybeReduce(
    XFile file, {
    required ImagePickOptions options,
  }) async {
    if (!_isAllowedType(file, options)) {
      throw PickFailure(
        type: PickFailureType.unsupportedType,
        message:
            'Unsupported image type. Allowed: ${(options.allowedExtensions ?? _kDefaultImageExtensions).join(', ')}',
      );
    }

    final originalBytes = await file.readAsBytes();
    final originalSize = originalBytes.lengthInBytes;

    final absoluteMax = options.absoluteMaxBytes;
    if (absoluteMax != null && originalSize > absoluteMax) {
      throw PickFailure(
        type: PickFailureType.tooLarge,
        message:
            'Image is ${_formatBytes(originalSize)}. Max allowed is ${_formatBytes(absoluteMax)}.',
      );
    }

    final maxBytes = options.maxSizeBytes;

    // If there is no limit and no processing required, return as-is
    if ((maxBytes == null || originalSize <= maxBytes) &&
        options.forceProcessEvenIfUnderLimit == false) {
      return PickResult(
        file: file,
        originalSizeBytes: originalSize,
        finalSizeBytes: originalSize,
        wasCompressed: false,
        compressionPasses: 0,
      );
    }

    // If under the limit but forceProcessEvenIfUnderLimit is true, run a single compression pass
    if ((maxBytes == null || originalSize <= maxBytes) &&
        options.forceProcessEvenIfUnderLimit == true) {
      final processed = await _compressOnce(
        input: originalBytes,
        quality: options.initialQuality,
        maxWidth: options.maxWidth,
        maxHeight: options.maxHeight,
        format: options.outputFormat,
      );

      if (processed == null) {
        // best effort: return the original
        return PickResult(
          file: file,
          originalSizeBytes: originalSize,
          finalSizeBytes: originalSize,
          wasCompressed: false,
          compressionPasses: 0,
        );
      }

      final outFile = await _bytesToXFile(
        bytes: processed,
        original: file,
        format: options.outputFormat,
      );

      return PickResult(
        file: outFile,
        originalSizeBytes: originalSize,
        finalSizeBytes: processed.lengthInBytes,
        wasCompressed: true,
        compressionPasses: 1,
      );
    }

    // If the size exceeds maxSizeBytes, we must reduce it
    if (maxBytes != null && originalSize > maxBytes) {
      final reduced = await _reduceToFit(
        originalBytes: originalBytes,
        maxBytes: maxBytes,
        options: options,
      );

      if (reduced == null) {
        // Web: usually reject (unless you decide otherwise)
        throw PickFailure(
          type: PickFailureType.tooLarge,
          message: kIsWeb
              ? 'Image is too large (${_formatBytes(originalSize)}). On Web, cannot reliably reduce. Max is ${_formatBytes(maxBytes)}.'
              : 'Could not reduce image below ${_formatBytes(maxBytes)}.',
        );
      }

      final outFile = await _bytesToXFile(
        bytes: reduced.bytes,
        original: file,
        format: options.outputFormat,
      );

      return PickResult(
        file: outFile,
        originalSizeBytes: originalSize,
        finalSizeBytes: reduced.bytes.lengthInBytes,
        wasCompressed: true,
        compressionPasses: reduced.passes,
      );
    }

    // fallback
    return PickResult(
      file: file,
      originalSizeBytes: originalSize,
      finalSizeBytes: originalSize,
      wasCompressed: false,
      compressionPasses: 0,
    );
  }

  static Future<_ReduceResult?> _reduceToFit({
    required Uint8List originalBytes,
    required int maxBytes,
    required ImagePickOptions options,
  }) async {
    if (kIsWeb && options.enforceMaxSizeOnWebWithoutCompression) {
      // No compression attempt here (strict on web)
      return null;
    }

    // If on web and best-effort only is desired without actual compression, return null (letting the UI accept or reject)
    if (kIsWeb) return null;

    int quality = options.initialQuality.clamp(10, 100);
    Uint8List current = originalBytes;
    Uint8List? smallest;
    int passes = 0;

    for (int i = 0; i < options.maxCompressionAttempts; i++) {
      passes++;

      final compressed = await _compressOnce(
        input: current,
        quality: quality,
        maxWidth: options.maxWidth,
        maxHeight: options.maxHeight,
        format: options.outputFormat,
      );

      if (compressed == null || compressed.isEmpty) break;

      if (smallest == null ||
          compressed.lengthInBytes < smallest.lengthInBytes) {
        smallest = compressed;
      }

      if (compressed.lengthInBytes <= maxBytes) {
        return _ReduceResult(bytes: compressed, passes: passes);
      }

      current = compressed;
      final nextQ = max(options.minQuality, quality - options.qualityStep);
      if (nextQ == quality) break;
      quality = nextQ;

      if (quality <= options.minQuality) break;
    }

    if (smallest != null && options.returnBestEffortOnFailure) {
      return _ReduceResult(bytes: smallest, passes: passes);
    }

    return null;
  }

  static Future<Uint8List?> _compressOnce({
    required Uint8List input,
    required int quality,
    required double? maxWidth,
    required double? maxHeight,
    required CompressFormat format,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        input,
        quality: quality,
        format: format,
        minWidth: maxWidth?.toInt() ?? 0,
        minHeight: maxHeight?.toInt() ?? 0,
      );
      if (result.isEmpty) return null;
      return Uint8List.fromList(result);
    } catch (_) {
      return null;
    }
  }

  // ───────────────────── Type validation ─────────────────────

  static const _kDefaultImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
    'gif',
    'bmp',
  };

  static bool _isAllowedType(XFile file, ImagePickOptions options) {
    final name = file.name.isNotEmpty ? file.name : p.basename(file.path);
    final ext = _extensionOf(name);

    final allowedExts =
        options.allowedExtensions != null &&
            options.allowedExtensions!.isNotEmpty
        ? options.allowedExtensions!
              .map((e) => e.toLowerCase().replaceAll('.', ''))
              .toSet()
        : _kDefaultImageExtensions;

    if (ext.isEmpty || !allowedExts.contains(ext)) return false;

    final mimeType = file.mimeType ?? lookupMimeType(name);
    if (mimeType != null && !mimeType.startsWith('image/')) return false;

    return true;
  }

  // ───────────────────── File helpers ─────────────────────

  static Future<XFile> _bytesToXFile({
    required Uint8List bytes,
    required XFile original,
    required CompressFormat format,
  }) async {
    final baseName = p.basenameWithoutExtension(_safeBaseName(original));
    final newExt = _extForFormat(format);
    final newName = '$baseName.$newExt';
    final mimeType = lookupMimeType(newName);

    if (kIsWeb) {
      return XFile.fromData(bytes, name: newName, mimeType: mimeType);
    }

    final dir = await getTemporaryDirectory();
    final outPath = p.join(
      dir.path,
      '${DateTime.now().millisecondsSinceEpoch}_$newName',
    );
    await File(outPath).writeAsBytes(bytes, flush: true);
    return XFile(outPath);
  }

  static String _extForFormat(CompressFormat f) {
    switch (f) {
      case CompressFormat.png:
        return 'png';
      case CompressFormat.webp:
        return 'webp';
      case CompressFormat.heic:
        return 'heic';
      case CompressFormat.jpeg:
      default:
        return 'jpg';
    }
  }

  static FileType _filePickerType(ImagePickOptions options) {
    if (options.allowedExtensions != null &&
        options.allowedExtensions!.isNotEmpty) {
      return FileType.custom;
    }
    return FileType.image;
  }

  static List<String>? _normalizedFilePickerExtensions(
    ImagePickOptions options,
  ) {
    if (options.allowedExtensions == null || options.allowedExtensions!.isEmpty)
      return null;
    return options.allowedExtensions!
        .map((e) => e.toLowerCase().replaceAll('.', ''))
        .toList();
  }

  static String _safeBaseName(XFile f) {
    if (f.name.isNotEmpty) return f.name;
    if (f.path.isNotEmpty) return p.basename(f.path);
    return 'image.jpg';
  }

  static String _extensionOf(String nameOrPath) {
    final dot = nameOrPath.lastIndexOf('.');
    if (dot == -1 || dot == nameOrPath.length - 1) return '';
    return nameOrPath.substring(dot + 1).toLowerCase();
  }

  static String _formatBytes(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(2)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(2)} KB';
    return '$bytes B';
  }
}

// ───────────────────────────────
// Options
// ───────────────────────────────

class ImagePickOptions {
  final Set<String>? allowedExtensions;

  /// hard limit
  final int? maxSizeBytes;

  /// safety limit (default 50MB)
  final int? absoluteMaxBytes;

  final double? maxWidth;
  final double? maxHeight;

  final CompressFormat outputFormat;

  final int initialQuality;
  final int minQuality;
  final int qualityStep;
  final int maxCompressionAttempts;

  /// If true: return smallest result even if it didn't hit maxSizeBytes (mobile).
  final bool returnBestEffortOnFailure;

  /// If true: even if the image is originally under the limit, process it once (convert/resize).
  final bool forceProcessEvenIfUnderLimit;

  /// On web: reject if > maxSizeBytes (default true)
  final bool enforceMaxSizeOnWebWithoutCompression;

  const ImagePickOptions({
    this.allowedExtensions,
    this.maxSizeBytes,
    this.absoluteMaxBytes = 50 * 1024 * 1024,
    this.maxWidth,
    this.maxHeight,
    this.outputFormat = CompressFormat.jpeg,
    this.initialQuality = 85,
    this.minQuality = 40,
    this.qualityStep = 10,
    this.maxCompressionAttempts = 6,
    this.returnBestEffortOnFailure = true,
    this.forceProcessEvenIfUnderLimit = false,
    this.enforceMaxSizeOnWebWithoutCompression = true,
  });
}

// ───────────────────────────────
// Result models
// ───────────────────────────────

enum PickFailureType {
  cancelled,
  permissionDenied,
  unsupportedType,
  tooLarge,
  platform,
  unknown,
}

class PickFailure implements Exception {
  final PickFailureType type;
  final String message;
  final String? code;

  const PickFailure({required this.type, required this.message, this.code});

  factory PickFailure.fromPlatformException(PlatformException e) {
    final code = e.code.toLowerCase();
    final denied =
        code.contains('denied') ||
        code.contains('permission') ||
        code.contains('access');

    if (denied) {
      return PickFailure(
        type: PickFailureType.permissionDenied,
        message: 'Permission denied: ${e.message ?? e.code}',
        code: e.code,
      );
    }

    return PickFailure(
      type: PickFailureType.platform,
      message: 'Platform error: ${e.message ?? e.code}',
      code: e.code,
    );
  }
}

class PickResult {
  final XFile file;
  final int originalSizeBytes;
  final int finalSizeBytes;
  final bool wasCompressed;
  final int compressionPasses;

  const PickResult({
    required this.file,
    required this.originalSizeBytes,
    required this.finalSizeBytes,
    required this.wasCompressed,
    required this.compressionPasses,
  });

  double get savedPercent {
    if (!wasCompressed || originalSizeBytes == 0) return 0;
    return ((originalSizeBytes - finalSizeBytes) / originalSizeBytes) * 100;
  }

  @override
  String toString() =>
      'PickResult('
      'original: ${_fmt(originalSizeBytes)}, '
      'final: ${_fmt(finalSizeBytes)}, '
      'compressed: $wasCompressed, '
      'passes: $compressionPasses'
      ')';

  static String _fmt(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(2)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(2)} KB';
    return '$bytes B';
  }
}

/// Single pick outcome
class PickOutcome {
  final PickResult? result;
  final PickFailure? failure;

  const PickOutcome._({this.result, this.failure});

  const PickOutcome.cancelled()
    : result = null,
      failure = const PickFailure(
        type: PickFailureType.cancelled,
        message: 'User cancelled picking.',
      );

  factory PickOutcome.success(PickResult r) => PickOutcome._(result: r);

  factory PickOutcome.failure(PickFailure f) => PickOutcome._(failure: f);

  bool get isSuccess => result != null;
  @override
  String toString() {
    if (result != null) return result.toString();
    if (failure != null) {
      return 'PickFailure(${failure!.type}: ${failure!.message})';
    }
    return 'PickOutcome(empty)';
  }
}

/// Multi pick outcome
class MultiPickOutcome {
  final List<PickResult>? results;
  final PickFailure? failure;

  /// If some files failed and others succeeded, they will be listed in [failures]
  final List<PickFailure> failures;

  const MultiPickOutcome._({
    this.results,
    this.failure,
    this.failures = const [],
  });

  const MultiPickOutcome.cancelled()
    : results = null,
      failure = const PickFailure(
        type: PickFailureType.cancelled,
        message: 'User cancelled picking.',
      ),
      failures = const [];

  factory MultiPickOutcome.success(
    List<PickResult> r, {
    List<PickFailure> failures = const [],
  }) => MultiPickOutcome._(results: r, failures: failures);

  factory MultiPickOutcome.failure(
    PickFailure f, {
    List<PickFailure> failures = const [],
  }) => MultiPickOutcome._(failure: f, failures: failures);

  bool get isSuccess => results != null && results!.isNotEmpty;
}

class _ReduceResult {
  final Uint8List bytes;
  final int passes;
  const _ReduceResult({required this.bytes, required this.passes});
}
