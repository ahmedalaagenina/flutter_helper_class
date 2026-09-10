import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';

/// A concrete [PlatformFile] for files the app produces itself.
///
/// Holds bytes, a local path, or both. [readAsBytes] prefers the in-memory
/// bytes and falls back to the path, so callers no longer need to branch on
/// `kIsWeb` to get at the content.
final class AppPlatformFile extends PlatformFile {
  AppPlatformFile({
    required this.name,
    Uint8List? bytes,
    String? path,
    int? size,
    String? mimeType,
  }) : assert(
         bytes != null || path != null,
         'AppPlatformFile needs bytes, a path, or both.',
       ),
       _bytes = bytes,
       _path = path,
       _size = size ?? bytes?.lengthInBytes,
       _mimeType = mimeType;

  @override
  final String name;

  final Uint8List? _bytes;
  final String? _path;
  final int? _size;
  final String? _mimeType;

  /// Overridden so the local path is returned directly rather than derived from
  /// [uri] — that keeps a bytes-only file from base64-encoding itself into a
  /// data URI just to answer "do you have a path?".
  @override
  String? get path => _path;

  @override
  late final Uri uri = _path != null
      ? Uri.file(_path)
      : Uri.dataFromBytes(
          _bytes!,
          mimeType: _mimeType ?? 'application/octet-stream',
        );

  @override
  late final XFile xFile = _path != null
      ? XFile(_path, name: name, length: _size, mimeType: _mimeType)
      : XFile.fromData(_bytes!, name: name, length: _size, mimeType: _mimeType);

  @override
  int? lengthSync() => _size;

  @override
  Future<int> length() async => _size ?? (await readAsBytes()).lengthInBytes;

  @override
  Future<Uint8List> readAsBytes() async => _bytes ?? await xFile.readAsBytes();

  @override
  Stream<Uint8List> readAsByteStream() =>
      _bytes != null ? Stream.value(_bytes) : xFile.openRead();
}
