import 'dart:typed_data';

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
  }) : assert(
         (filePath != null && bytes == null) ||
             (filePath == null && bytes != null),
         'Either filePath or bytes must be provided, but not both',
       );

  /// Create from file path (for mobile)
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

  /// Create from bytes (for web)
  factory FileData.fromBytes(
    Uint8List bytes, {
    required String filename,
    (String, String)? contentType,
  }) {
    return FileData(bytes: bytes, filename: filename, contentType: contentType);
  }

  /// Create from PlatformFileService FileResult
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

/// Result object containing file information
class FileResult {
  final String path;
  final Uint8List bytes;
  final bool isWeb;

  FileResult({required this.path, required this.bytes, required this.isWeb});

  /// Helper to get bytes for saving to database/backend
  Uint8List getBytes() => bytes;

  /// Helper to check if this is a web file
  bool get isWebFile => isWeb;
}

/// Custom exception for file service errors
class FileServiceException implements Exception {
  final String message;
  FileServiceException(this.message);

  @override
  String toString() => 'FileServiceException: $message';
}
