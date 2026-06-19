import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:share_handler/share_handler.dart';

/// {@template shared_media_service}
/// Receives files that the OS hands to the app through the **system Share Sheet**
/// ("Share with…") or **Open-with** action, on both iOS and Android, and exposes
/// them as strongly-typed [SharedFile] objects.
///
/// This service is intentionally **self-contained**: it depends only on
/// `share_handler` and the Flutter SDK (no `file_picker`, no app-specific
/// logging), so it can be dropped into any app — new or old — by copying this
/// single file and following `shared_media_service.README.md`.
///
/// ### Lifecycle
/// 1. Construct once (e.g. as a singleton) with the [SharedFileType]s you accept.
/// 2. Call [init] once from your root widget's `initState`.
/// 3. Listen to [onFileReceived] for every accepted file (cold + warm start).
/// 4. For auth-gated flows, read [pendingFile] after login then
///    [consumePendingFile].
/// 5. Call [dispose] from your root widget's `dispose`.
/// {@endtemplate}
class SharedMediaService {
  /// {@macro shared_media_service}
  ///
  /// [acceptedTypes] filters incoming files by extension. Pass
  /// `{SharedFileType.any}` (the default) to accept everything. The set must
  /// not be empty.
  SharedMediaService({
    Set<SharedFileType> acceptedTypes = const {SharedFileType.any},
  }) : assert(acceptedTypes.isNotEmpty, 'acceptedTypes must not be empty'),
       _acceptAny = acceptedTypes.contains(SharedFileType.any),
       _acceptedExtensions = acceptedTypes
           .expand((t) => kSharedFileExtensions[t] ?? const <String>{})
           .toSet();

  // ---- configuration --------------------------------------------------------

  final bool _acceptAny;
  final Set<String> _acceptedExtensions;

  // ---- state ----------------------------------------------------------------

  final StreamController<SharedFile> _controller =
      StreamController<SharedFile>.broadcast();
  StreamSubscription<SharedMedia>? _streamSub;
  SharedFile? _pendingFile;
  bool _initialHandled = false;

  // ---- public API -----------------------------------------------------------

  /// Broadcast stream that emits every accepted [SharedFile], for both
  /// cold-start (file launched the app) and warm-start (shared while running).
  Stream<SharedFile> get onFileReceived => _controller.stream;

  /// The most recent accepted file that has not been consumed yet.
  ///
  /// Useful for auth-gated flows: after the user logs in, check this, navigate
  /// if non-null, then call [consumePendingFile].
  SharedFile? get pendingFile => _pendingFile;

  /// Clears [pendingFile] after it has been handled.
  void consumePendingFile() => _pendingFile = null;

  /// Starts listening for shared files. Call **once**. No-op on web.
  void init() {
    if (kIsWeb) return;

    // Cold start via "Open with" can arrive as a platform `file://` route.
    unawaited(_handlePlatformDefaultRoute());

    // Cold start: media that launched the app.
    if (!_initialHandled) {
      _initialHandled = true;
      ShareHandlerPlatform.instance
          .getInitialSharedMedia()
          .then((media) async {
            await _handleSharedMedia(media);
            // Prevent the same media from replaying on a hot restart.
            await ShareHandlerPlatform.instance.resetInitialSharedMedia();
          })
          .catchError((Object e) {
            _log('initial media error — $e');
          });
    }

    // Warm start: media shared while the app is running.
    _streamSub?.cancel();
    _streamSub = ShareHandlerPlatform.instance.sharedMediaStream.listen(
      (media) => unawaited(_handleSharedMedia(media)),
      onError: (Object e) => _log('media stream error — $e'),
    );
  }

  /// Handles a `file://` URI surfaced by the platform route channel.
  ///
  /// On iOS, "Open in…" for an in-place document can arrive as a `file://`
  /// route rather than plugin media. If your router blocks that route, forward
  /// the [uri] here so the same pending-file flow continues. Returns whether an
  /// accepted file was produced.
  Future<bool> handleExternalUri(Uri uri) async {
    if (kIsWeb || uri.scheme.toLowerCase() != 'file') return false;
    try {
      return _handlePath(uri.toFilePath());
    } catch (e) {
      _log('invalid file URI — $e');
      return false;
    }
  }

  /// Releases resources. Call from your root widget's `dispose`.
  void dispose() {
    _streamSub?.cancel();
    _streamSub = null;
    _controller.close();
  }

  // ---- internals ------------------------------------------------------------

  Future<void> _handlePlatformDefaultRoute() async {
    final routeName =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    final uri = Uri.tryParse(routeName);
    if (uri == null) return;
    await handleExternalUri(uri);
  }

  Future<void> _handleSharedMedia(SharedMedia? media) async {
    final attachments = media?.attachments;
    if (attachments == null || attachments.isEmpty) return;

    for (final attachment in attachments) {
      final path = attachment?.path;
      if (path == null || path.isEmpty) continue;
      await _handlePath(path, attachmentType: attachment?.type);
    }
  }

  Future<bool> _handlePath(
    String path, {
    SharedAttachmentType? attachmentType,
  }) async {
    final ext = _extensionOf(path);

    if (!_acceptAny && !_acceptedExtensions.contains(ext)) {
      _log('ignored unsupported file (ext="$ext", path=$path)');
      return false;
    }

    final file = await _toSharedFile(path, ext, attachmentType);
    if (file == null) return false;

    _pendingFile = file;
    _controller.add(file);
    _log('accepted file — ${file.name}');
    return true;
  }

  Future<SharedFile?> _toSharedFile(
    String path,
    String ext,
    SharedAttachmentType? attachmentType,
  ) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        _log('file not found — $path');
        return null;
      }
      return SharedFile(
        path: path,
        name: path.split(Platform.pathSeparator).last,
        size: await file.length(),
        fileExtension: ext,
        type: _resolveType(ext, attachmentType),
      );
    } catch (e) {
      _log('failed to inspect file — $e');
      return null;
    }
  }

  /// Resolves the [SharedFileType] by extension first, then falls back to the
  /// attachment hint reported by the OS.
  static SharedFileType _resolveType(
    String ext,
    SharedAttachmentType? attachmentType,
  ) {
    for (final entry in kSharedFileExtensions.entries) {
      if (entry.key == SharedFileType.any) continue;
      if (entry.value.contains(ext)) return entry.key;
    }
    switch (attachmentType) {
      case SharedAttachmentType.image:
        return SharedFileType.image;
      case SharedAttachmentType.video:
        return SharedFileType.video;
      case SharedAttachmentType.audio:
        return SharedFileType.audio;
      case SharedAttachmentType.file:
      case null:
        return SharedFileType.other;
    }
  }

  /// Lowercase extension without the leading dot (e.g. `"pdf"`); `""` if none.
  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    return path.substring(dot + 1).toLowerCase();
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[SharedMediaService] $message');
  }
}

/// A file received from the OS share/open-with flow.
@immutable
class SharedFile {
  const SharedFile({
    required this.path,
    required this.name,
    required this.size,
    required this.fileExtension,
    required this.type,
  });

  /// Absolute path to the file on disk.
  final String path;

  /// File name including extension (e.g. `contract.pdf`).
  final String name;

  /// Size in bytes.
  final int size;

  /// Lowercase extension without the dot (e.g. `pdf`); empty when unknown.
  final String fileExtension;

  /// Resolved category of the file.
  final SharedFileType type;

  /// File-name without its extension (e.g. `contract`).
  String get nameWithoutExtension {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  /// A [File] handle for the [path].
  File get file => File(path);

  @override
  String toString() =>
      'SharedFile(name: $name, type: $type, size: $size, path: $path)';
}

/// Categories used both to filter incoming files and to tag the result.
///
/// Add a value here and a matching entry in [kSharedFileExtensions] to support a
/// new category.
enum SharedFileType {
  /// PDF documents.
  pdf,

  /// Images (jpg, png, heic, …).
  image,

  /// Word documents (doc, docx).
  doc,

  /// Plain text (txt).
  text,

  /// Video files (mp4, mov, …).
  video,

  /// Audio files (mp3, m4a, …).
  audio,

  /// Anything that doesn't match a known category.
  other,

  /// Sentinel for "accept every file" — use only in the constructor's
  /// `acceptedTypes`; never returned as a resolved [SharedFile.type].
  any,
}

/// Maps each [SharedFileType] to the lowercase extensions it accepts.
const Map<SharedFileType, Set<String>> kSharedFileExtensions = {
  SharedFileType.pdf: {'pdf'},
  SharedFileType.image: {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
    'heic',
    'heif',
  },
  SharedFileType.doc: {'doc', 'docx'},
  SharedFileType.text: {'txt'},
  SharedFileType.video: {'mp4', 'mov', 'm4v', 'avi', 'mkv', 'webm'},
  SharedFileType.audio: {'mp3', 'wav', 'm4a', 'aac', 'ogg'},
  SharedFileType.other: {},
  SharedFileType.any: {},
};
