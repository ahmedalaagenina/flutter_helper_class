import 'dart:typed_data';

/// Cross-platform file payload for multipart uploads.
///
/// Two sources, exactly one of which must be provided:
/// - [filePath] — mobile / desktop filesystem path
/// - [bytes]    — raw bytes (use on Web: `await xFile.readAsBytes()`)
///
/// On Flutter Web, file pickers (`image_picker`, `file_picker`, `XFile`)
/// give you a handle that you can convert to bytes — call
/// `.readAsBytes()` and use [FileData.fromBytes].
class FileData {
  final String? filePath;
  final Uint8List? bytes;
  final String filename;
  final (String, String)? contentType;

  FileData({
    this.filePath,
    this.bytes,
    required this.filename,
    this.contentType,
  }) {
    // Runtime check (not assert) so release builds still catch misuse.
    final provided = [filePath, bytes].where((v) => v != null).length;
    if (provided != 1) {
      throw ArgumentError(
        'FileData: exactly one of filePath or bytes must be provided '
        '(got $provided).',
      );
    }
  }

  /// Mobile / desktop: pass a real filesystem path.
  factory FileData.fromPath(
    String path, {
    String? filename,
    (String, String)? contentType,
  }) {
    return FileData(
      filePath: path,
      filename: filename ?? path.split('/').last,
      contentType: contentType,
    );
  }

  /// Web / in-memory: pass raw bytes.
  ///
  /// ```dart
  /// final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  /// final bytes  = await picked!.readAsBytes();
  /// FileData.fromBytes(bytes, filename: picked.name);
  /// ```
  factory FileData.fromBytes(
    Uint8List bytes, {
    required String filename,
    (String, String)? contentType,
  }) {
    return FileData(bytes: bytes, filename: filename, contentType: contentType);
  }

  /// Convenience: build from a [FileResult] (your file picker's output).
  /// On Web the bytes branch is taken; otherwise the path branch.
  factory FileData.fromFileResult(
    FileResult fileResult, {
    (String, String)? contentType,
  }) {
    return FileData(
      filePath: fileResult.isWeb ? null : fileResult.path,
      bytes: fileResult.isWeb ? fileResult.bytes : null,
      filename: fileResult.path.split('/').last,
      contentType: contentType,
    );
  }

  bool get isFile => filePath != null;
  bool get isBytes => bytes != null;
}

/// Picker-output abstraction. On mobile, [path] is a real filesystem path
/// and [bytes] may be empty until read. On Web, [path] is whatever the
/// picker returns (opaque to the networking layer) and [bytes] must
/// already be populated.
class FileResult {
  final String path;
  final Uint8List bytes;
  final bool isWeb;

  FileResult({
    required this.path,
    required this.bytes,
    required this.isWeb,
  });

  Uint8List getBytes() => bytes;
  bool get isWebFile => isWeb;
}

/// Custom exception for file service errors.
class FileServiceException implements Exception {
  final String message;
  FileServiceException(this.message);

  @override
  String toString() => 'FileServiceException: $message';
}
