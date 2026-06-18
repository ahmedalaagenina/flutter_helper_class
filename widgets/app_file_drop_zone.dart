import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

/// A file dropped onto an [AppFileDropZone].
///
/// Platform-agnostic: [bytes] is always populated (read eagerly), while
/// [path] is only available on native platforms (null on web).
class DroppedFile {
  const DroppedFile({
    required this.name,
    required this.bytes,
    required this.size,
    this.path,
    this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final int size;
  final String? path;
  final String? mimeType;

  /// Lowercase extension without the dot (e.g. `pdf`). Empty when none.
  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }
}

/// A reusable, configurable drag-and-drop file target that works on web and
/// desktop (backed by the `desktop_drop` package).
///
/// You fully control the visuals through [builder], which is rebuilt with the
/// current drag state so you can highlight the zone while a file hovers over
/// it. Dropped files are read into memory, filtered by [allowedExtensions]
/// (and [maxFiles]), then handed back via [onFiles] / [onFile].
///
/// ```dart
/// AppFileDropZone(
///   allowedExtensions: const ['pdf'],
///   onFile: (file) => _handle(file),
///   onRejected: (rejected) => showError(),
///   builder: (context, isDragging) => MyZone(active: isDragging),
/// )
/// ```
class AppFileDropZone extends StatefulWidget {
  const AppFileDropZone({
    super.key,
    required this.builder,
    this.onFiles,
    this.onFile,
    this.allowedExtensions,
    this.allowMultiple = false,
    this.enabled = true,
    this.onRejected,
  });

  /// Builds the zone contents. [isDragging] is true while a draggable item is
  /// hovering over the zone — use it to render a highlighted/active state.
  final Widget Function(BuildContext context, bool isDragging) builder;

  /// Called with every accepted file. Fires alongside [onFile].
  final ValueChanged<List<DroppedFile>>? onFiles;

  /// Convenience callback for the first accepted file.
  final ValueChanged<DroppedFile>? onFile;

  /// Lowercase extensions (without the dot) to accept, e.g. `['pdf']`.
  /// When null, every file type is accepted.
  final List<String>? allowedExtensions;

  /// When false, only the first accepted file is kept.
  final bool allowMultiple;

  /// Disables drop handling (the [builder] is still rendered).
  final bool enabled;

  /// Called with files that were dropped but rejected by [allowedExtensions],
  /// so the caller can surface an error (e.g. a snack bar).
  final ValueChanged<List<DroppedFile>>? onRejected;

  @override
  State<AppFileDropZone> createState() => _AppFileDropZoneState();
}

class _AppFileDropZoneState extends State<AppFileDropZone> {
  bool _isDragging = false;

  bool _isAllowed(DroppedFile file) {
    final allowed = widget.allowedExtensions;
    if (allowed == null || allowed.isEmpty) return true;
    return allowed.map((e) => e.toLowerCase()).contains(file.extension);
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    if (!widget.enabled) return;

    final accepted = <DroppedFile>[];
    final rejected = <DroppedFile>[];

    for (final item in details.files) {
      // Skip directories / anything we can't read as bytes.
      final Uint8List bytes;
      try {
        bytes = await item.readAsBytes();
      } catch (_) {
        continue;
      }

      final file = DroppedFile(
        name: item.name,
        bytes: bytes,
        size: bytes.length,
        path: item.path.isEmpty ? null : item.path,
        mimeType: item.mimeType,
      );

      if (_isAllowed(file)) {
        accepted.add(file);
      } else {
        rejected.add(file);
      }
    }

    if (!mounted) return;
    setState(() => _isDragging = false);

    if (rejected.isNotEmpty) widget.onRejected?.call(rejected);
    if (accepted.isEmpty) return;

    final result = widget.allowMultiple ? accepted : [accepted.first];
    widget.onFiles?.call(result);
    widget.onFile?.call(result.first);
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      enable: widget.enabled,
      onDragEntered: (_) {
        if (widget.enabled) setState(() => _isDragging = true);
      },
      onDragExited: (_) {
        if (_isDragging) setState(() => _isDragging = false);
      },
      onDragDone: _handleDrop,
      child: widget.builder(context, _isDragging),
    );
  }
}
