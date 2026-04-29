import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'logger_service.dart';

// ---------------------------------------------------------------------------
// SharedFileService — Reusable file-intent handler for Flutter apps
// ---------------------------------------------------------------------------
//
// ## Overview
//
// Handles files received via the system "Open with" or "Share" actions on
// iOS and Android.  Converts incoming file paths into [PlatformFile] objects
// and exposes them through a broadcast stream.
//
// ## Quick start
//
// ```dart
// // 1. Create the service with the file types you accept.
// final service = SharedFileService(
//   supportedTypes: {SharedFileType.pdf},          // only PDFs
// );
//
// // 2. Initialise (call once, e.g. in your App widget's initState).
// service.init();
//
// // 3. Listen for incoming files.
// service.onFileReceived.listen((PlatformFile file) {
//   // Navigate, upload, preview — whatever your app needs.
// });
//
// // 4. For auth-gated flows, check for a pending file after login.
// final pending = service.pendingFile;
// if (pending != null) {
//   navigateWithFile(pending);
//   service.consumePendingFile();
// }
//
// // 5. Dispose when done (e.g. in your App widget's dispose).
// service.dispose();
// ```
//
// ## Supported file types
//
// Add entries to [SharedFileType] for new categories.  Each entry maps to a
// set of lowercase extensions (without the leading dot).
//
// ## Platform setup
//
// ### iOS  — Info.plist
// ```xml
// <key>CFBundleDocumentTypes</key>
// <array>
//     <dict>
//         <key>CFBundleTypeName</key>
//         <string>PDF Document</string>
//         <key>CFBundleTypeRole</key>
//         <string>Viewer</string>
//         <key>LSHandlerRank</key>
//         <string>Alternate</string>
//         <key>LSItemContentTypes</key>
//         <array>
//             <string>com.adobe.pdf</string>
//         </array>
//     </dict>
// </array>
// <key>LSSupportsOpeningDocumentsInPlace</key>
// <true/>
// ```
//
// ### Android — AndroidManifest.xml  (inside <activity>)
// ```xml
// <!-- Open PDF files directly -->
// <intent-filter>
//     <action android:name="android.intent.action.VIEW" />
//     <category android:name="android.intent.category.DEFAULT" />
//     <data android:mimeType="application/pdf" />
// </intent-filter>
// <!-- Receive shared PDF files -->
// <intent-filter>
//     <action android:name="android.intent.action.SEND" />
//     <category android:name="android.intent.category.DEFAULT" />
//     <data android:mimeType="application/pdf" />
// </intent-filter>
// ```
// ---------------------------------------------------------------------------

/// Supported file-type categories.
///
/// Each entry defines a group of extensions that will be accepted when
/// filtering incoming shared files.  Pass a `Set<SharedFileType>` to
/// [SharedFileService] to control which files are let through.
///
/// **Adding a new type** — simply add an enum value and its extensions to
/// [_extensionMap].
enum SharedFileType {
  /// PDF documents (`.pdf`).
  pdf,

  /// Common image formats (`.jpg`, `.jpeg`, `.png`, `.gif`, `.bmp`, `.webp`,
  /// `.heic`, `.heif`).
  image,

  /// Microsoft Word documents (`.doc`, `.docx`).
  doc,

  /// Plain-text files (`.txt`).
  text,

  /// Any file
  any,
}

/// Maps each [SharedFileType] to its set of accepted lowercase extensions.
const Map<SharedFileType, Set<String>> _extensionMap = {
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
  SharedFileType.any: {},
};

/// A reusable service that intercepts files opened or shared to the app from
/// the operating system and exposes them as [PlatformFile] objects.
///
/// ### File-type filtering
///
/// Only files whose extension matches one of the configured [supportedTypes]
/// are emitted.  All other files are silently ignored.
///
/// ```dart
/// // Accept PDFs only:
/// SharedFileService(supportedTypes: {SharedFileType.pdf});
///
/// // Accept PDFs and images:
/// SharedFileService(supportedTypes: {SharedFileType.pdf, SharedFileType.image});
/// ```
///
/// ### Pending-file pattern (auth-gated flows)
///
/// When a file is received but the user isn't logged in yet, the service
/// stores it as [pendingFile].  After the user authenticates, read
/// [pendingFile] and call [consumePendingFile] to clear it.
class SharedFileService {
  /// Creates a [SharedFileService] that accepts only files matching
  /// [supportedTypes].
  ///
  /// [supportedTypes] must contain at least one entry.
  SharedFileService({required Set<SharedFileType> supportedTypes})
    : assert(supportedTypes.isNotEmpty, 'supportedTypes must not be empty'),
      _supportedExtensions = supportedTypes
          .expand((type) => _extensionMap[type] ?? <String>{})
          .toSet();

  // ---- private state --------------------------------------------------------

  final Set<String> _supportedExtensions;
  final StreamController<PlatformFile> _controller =
      StreamController<PlatformFile>.broadcast();

  StreamSubscription<List<SharedMediaFile>>? _intentSub;
  PlatformFile? _pendingFile;
  bool _initialHandled = false;

  // ---- public API -----------------------------------------------------------

  /// A broadcast stream of accepted files received from the OS.
  ///
  /// Emits each time a new file arrives (both cold-start and warm-start).
  Stream<PlatformFile> get onFileReceived => _controller.stream;

  /// The most recently received file that has not been consumed yet.
  ///
  /// Useful for auth-gated flows: check this after login, navigate if non-null,
  /// then call [consumePendingFile].
  PlatformFile? get pendingFile => _pendingFile;

  /// Clears the [pendingFile] after it has been handled.
  void consumePendingFile() => _pendingFile = null;

  /// Starts listening for incoming file intents.
  ///
  /// **Must be called once** (typically in your root widget's `initState`).
  /// On native platforms it subscribes to both the initial intent (cold start)
  /// and the media stream (warm start / subsequent shares).
  ///
  /// Does nothing on web.
  void init() {
    if (kIsWeb) return;

    unawaited(_handlePlatformDefaultRoute());

    // --- Cold start: file that launched the app ---
    if (!_initialHandled) {
      _initialHandled = true;
      ReceiveSharingIntent.instance
          .getInitialMedia()
          .then(_handleSharedFiles)
          .catchError((Object e) {
            AppLog.e('SharedFileService: initial media error — $e');
          });
    }

    // --- Warm start: files received while app is running ---
    _intentSub?.cancel();
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) => unawaited(_handleSharedFiles(files)),
      onError: (Object e) {
        AppLog.e('SharedFileService: media stream error — $e');
      },
    );
  }

  /// Handles file URLs surfaced by Flutter's platform route channel.
  ///
  /// On iOS, opening a document via "Open in..." can arrive as a `file://`
  /// route instead of plugin media. GoRouter blocks that route and forwards it
  /// here so the same pending-file flow can continue.
  Future<bool> handleExternalUri(Uri uri) async {
    if (kIsWeb || uri.scheme.toLowerCase() != 'file') return false;

    try {
      return _handleFilePath(uri.toFilePath());
    } catch (e) {
      AppLog.e('SharedFileService: invalid file URI — $e');
      return false;
    }
  }

  /// Releases resources. Call from your root widget's `dispose`.
  void dispose() {
    _intentSub?.cancel();
    _intentSub = null;
    _controller.close();
  }

  // ---- private helpers ------------------------------------------------------

  Future<void> _handlePlatformDefaultRoute() async {
    final routeName =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    final uri = Uri.tryParse(routeName);
    if (uri == null) return;

    await handleExternalUri(uri);
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;

    for (final shared in files) {
      final path = shared.path;
      if (path.isEmpty) continue;

      await _handleFilePath(path);
    }

    // Tell the plugin we're done so iOS doesn't replay the same intent.
    ReceiveSharingIntent.instance.reset();
  }

  Future<bool> _handleFilePath(String path) async {
    final ext = _extensionOf(path);
    if (!_supportedExtensions.contains(ext)) {
      AppLog.w(
        'SharedFileService: ignored unsupported file '
        '(ext=$ext, path=$path)',
      );
      return false;
    }

    final platformFile = await _toPlatformFile(path);
    if (platformFile == null) return false;

    _pendingFile = platformFile;
    _controller.add(platformFile);
    AppLog.i('SharedFileService: accepted file — ${platformFile.name}');
    return true;
  }

  /// Converts a file-system [path] into a [PlatformFile], reading its bytes
  /// for cross-platform compatibility.
  Future<PlatformFile?> _toPlatformFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        AppLog.w('SharedFileService: file not found — $path');
        return null;
      }

      final bytes = await file.readAsBytes();
      final name = path.split(Platform.pathSeparator).last;

      return PlatformFile(
        path: path,
        name: name,
        size: bytes.length,
        bytes: bytes,
      );
    } catch (e) {
      AppLog.e('SharedFileService: failed to read file — $e');
      return null;
    }
  }

  /// Returns the lowercase extension without the leading dot,
  /// e.g. `"pdf"` from `"/path/to/doc.PDF"`.
  static String _extensionOf(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == path.length - 1) return '';
    return path.substring(dotIndex + 1).toLowerCase();
  }
}
