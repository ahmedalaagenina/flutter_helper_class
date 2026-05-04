import 'dart:typed_data';

class FileData {
  final String? filePath;
  final Uint8List? bytes;
  final String? blobUrl;
  final String filename;
  final (String, String)? contentType;

  FileData({
    this.filePath,
    this.bytes,
    this.blobUrl,
    required this.filename,
    this.contentType,
  }) : assert(
         (filePath != null && bytes == null && blobUrl == null) ||
             (bytes != null && filePath == null && blobUrl == null) ||
             (blobUrl != null && filePath == null && bytes == null),
         'Only one of filePath, bytes, or blobUrl must be provided',
       );

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

  factory FileData.fromBytes(
    Uint8List bytes, {
    required String filename,
    (String, String)? contentType,
  }) {
    return FileData(bytes: bytes, filename: filename, contentType: contentType);
  }

  /// For web blob:// URLs — resolved later by ApiService using its own Dio
  factory FileData.fromBlobUrl(
    String blobUrl, {
    required String filename,
    (String, String)? contentType,
  }) {
    assert(blobUrl.startsWith('blob:'), 'blobUrl must start with blob:');
    return FileData(
      blobUrl: blobUrl,
      filename: filename,
      contentType: contentType,
    );
  }

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

  /// Smartly create from any image path string (blob or file path)
  factory FileData.fromImagePath(
    String imagePath, {
    required String filename,
    (String, String)? contentType,
  }) {
    if (imagePath.startsWith('blob:')) {
      return FileData.fromBlobUrl(
        imagePath,
        filename: filename,
        contentType: contentType,
      );
    }
    return FileData.fromPath(
      imagePath,
      filename: filename,
      contentType: contentType,
    );
  }

  bool get isFile => filePath != null;
  bool get isBytes => bytes != null;
  bool get isBlob => blobUrl != null;
}

/// Result object containing file information
class FileResult {
  final String path;
  final Uint8List bytes;
  final String? blobUrl;
  final bool isWeb;

  FileResult({
    required this.path,
    required this.bytes,
    required this.isWeb,
    this.blobUrl,
  });

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
