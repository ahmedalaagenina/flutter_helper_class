import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:idara_esign/config/theme/theme_extensions.dart';
import 'package:idara_esign/core/helpers/image_picker_helper.dart';
import 'package:idara_esign/core/helpers/pdf_view_helpers.dart';
import 'package:idara_esign/core/responsive/responsive.dart';
import 'package:idara_esign/core/widgets/widgets.dart';
import 'package:idara_esign/features/document/presentation/utils/images_to_pdf.dart';
import 'package:idara_esign/generated/l10n.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

class ImageToDocumentPage extends StatefulWidget {
  const ImageToDocumentPage({super.key});

  @override
  State<ImageToDocumentPage> createState() => _ImageToDocumentPageState();
}

class _PickedImage {
  _PickedImage({required this.bytes, required this.name});
  final Uint8List bytes;
  final String name;
}

class _ImageToDocumentPageState extends State<ImageToDocumentPage> {
  final List<_PickedImage> _images = [];
  bool _busy = false;
  static const _pickOptions = ImagePickOptions(
    allowedExtensions: {'jpg', 'jpeg', 'png', 'heic', 'heif', 'webp'},
    maxWidth: 1240,
    maxHeight: 1240,
    maxSizeBytes: 250 * 1024,
    initialQuality: 70,
    minQuality: 35,
    qualityStep: 8,
    maxCompressionAttempts: 8,
    forceProcessEvenIfUnderLimit: true,
  );

  Future<void> _takePhoto() async {
    if (_busy) return;
    final outcome = await ImagePickerHelper.pickSingle(
      source: ImageSource.camera,
      options: _pickOptions,
    );
    final picked = outcome.result?.file;
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _images.add(_PickedImage(bytes: bytes, name: picked.name)));
  }

  Future<void> _pickFromGallery() async {
    if (_busy) return;
    final outcome = await ImagePickerHelper.pickMultiple(options: _pickOptions);
    final results = outcome.results;
    if (results == null || results.isEmpty) return;

    final added = <_PickedImage>[];
    for (final r in results) {
      added.add(
        _PickedImage(bytes: await r.file.readAsBytes(), name: r.file.name),
      );
    }
    if (!mounted) return;
    setState(() => _images.addAll(added));
  }

  void _removeAt(int index) {
    setState(() => _images.removeAt(index));
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);
    });
  }

  Future<void> _createPdf() async {
    if (_busy || _images.isEmpty) return;
    setState(() => _busy = true);
    try {
      final pdfBytes = await buildPdfFromImages(
        _images.map((e) => e.bytes).toList(),
      );
      if (!mounted) return;
      setState(() => _busy = false);

      // Let the user preview the assembled PDF before committing it to the
      // create-document flow.
      final confirmed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _PdfPreviewPage(pdfBytes: pdfBytes),
        ),
      );
      if (confirmed != true || !mounted) return;

      final dir = await getTemporaryDirectory();
      final fileName = 'Document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${dir.path}/$fileName';
      await File(filePath).writeAsBytes(pdfBytes, flush: true);

      if (!mounted) return;
      Navigator.of(context).pop(
        PlatformFile(
          path: filePath,
          name: fileName,
          size: pdfBytes.lengthInBytes,
          bytes: pdfBytes,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackBars.error(S.of(context).failedToCreatePdf);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: MaxWidthCenter(
          maxWidth: 750,
          child: Column(
            children: [
              CustomAppBar(
                title: s.createFromImages,
                subtitle: s.createFromImagesSubtitle,
              ),
              Expanded(
                child: _images.isEmpty
                    ? _EmptyState(
                        onTakePhoto: _takePhoto,
                        onPickGallery: _pickFromGallery,
                      )
                    : _ImageList(
                        images: _images,
                        busy: _busy,
                        onRemove: _removeAt,
                        onReorder: _reorder,
                      ),
              ),
              if (_images.isNotEmpty)
                _BottomBar(
                  count: _images.length,
                  busy: _busy,
                  onAddMore: _showAddSourceSheet,
                  onCreate: _createPdf,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddSourceSheet() async {
    if (_busy) return;
    // No camera on web — go straight to the gallery picker.
    if (kIsWeb) {
      _pickFromGallery();
      return;
    }
    final s = S.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(s.takePhoto),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(s.chooseFromGallery),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onTakePhoto, required this.onPickGallery});

  final VoidCallback onTakePhoto;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final primary = context.colors.primary;
    // Full-width buttons on mobile; intrinsic (compact) on tablet/web/desktop.
    final double? buttonWidth = context.isBiggerThanMobile
        ? null
        : double.infinity;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withOpacity(0.1),
              ),
              child: Icon(Icons.image_outlined, color: primary, size: 40),
            ),
            const SizedBox(height: 18),
            Text(
              s.noImagesAddedYet,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.imagesToPdfHint,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 26),
            // Camera capture is unavailable on web — only offer gallery there.
            if (!kIsWeb) ...[
              AppButtonLeadingIcon(
                title: s.takePhoto,
                icon: Icons.photo_camera_outlined,
                iconSize: 18,
                titleSize: 15,
                height: 50,
                width: buttonWidth,
                onPressed: onTakePhoto,
                backgroundColor: primary,
                titleColor: Colors.white,
                iconColor: Colors.white,
                radius: 24,
              ),
              const SizedBox(height: 12),
            ],
            AppButtonLeadingIcon(
              title: s.chooseFromGallery,
              icon: Icons.photo_library_outlined,
              iconSize: 18,
              titleSize: 15,
              height: 50,
              width: buttonWidth,
              onPressed: onPickGallery,
              backgroundColor: kIsWeb ? primary : Colors.transparent,
              titleColor: kIsWeb ? Colors.white : primary,
              iconColor: kIsWeb ? Colors.white : primary,
              border: kIsWeb
                  ? null
                  : Border.all(color: primary.withOpacity(0.5), width: 1.2),
              radius: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageList extends StatelessWidget {
  const _ImageList({
    required this.images,
    required this.busy,
    required this.onRemove,
    required this.onReorder,
  });

  final List<_PickedImage> images;
  final bool busy;
  final ValueChanged<int> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: busy,
      child: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: images.length,
        onReorder: onReorder,
        itemBuilder: (context, index) {
          final image = images[index];
          return _ImageTile(
            key: ValueKey(image),
            index: index,
            image: image,
            onRemove: () => onRemove(index),
          );
        },
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    super.key,
    required this.index,
    required this.image,
    required this.onRemove,
  });

  final int index;
  final _PickedImage image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primary.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              image.bytes,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withOpacity(0.12),
            ),
            child: Text(
              '${index + 1}',
              style: context.textTheme.labelMedium?.copyWith(
                color: primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              image.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.delete_outline, color: context.colors.error),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Icon(
              Icons.drag_handle_rounded,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.count,
    required this.busy,
    required this.onAddMore,
    required this.onCreate,
  });

  final int count;
  final bool busy;
  final VoidCallback onAddMore;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final primary = context.colors.primary;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: primary.withOpacity(0.12))),
      ),
      child: Row(
        mainAxisAlignment: context.isBiggerThanMobile
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          AppButtonLeadingIcon(
            title: s.addMore,
            icon: Icons.add_rounded,
            iconSize: 18,
            titleSize: 15,
            height: 50,
            onPressed: busy ? null : onAddMore,
            backgroundColor: Colors.transparent,
            titleColor: primary,
            iconColor: primary,
            border: Border.all(color: primary.withOpacity(0.5), width: 1.2),
            radius: 24,
          ),
          const SizedBox(width: 12),
          // Full-width create button on mobile; compact (intrinsic) on web.
          if (context.isBiggerThanMobile)
            AppButtonLeadingIcon(
              title: busy ? s.creatingPdf : s.generatePdf,
              icon: busy ? Icons.hourglass_top_rounded : Icons.picture_as_pdf,
              iconSize: 18,
              titleSize: 15,
              height: 50,
              onPressed: busy ? null : onCreate,
              backgroundColor: primary,
              titleColor: Colors.white,
              iconColor: Colors.white,
              radius: 24,
            )
          else
            Expanded(
              child: AppButtonLeadingIcon(
                title: busy ? s.creatingPdf : s.generatePdf,
                icon: busy ? Icons.hourglass_top_rounded : Icons.picture_as_pdf,
                iconSize: 18,
                titleSize: 15,
                height: 50,
                width: double.infinity,
                onPressed: busy ? null : onCreate,
                backgroundColor: primary,
                titleColor: Colors.white,
                iconColor: Colors.white,
                radius: 24,
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-screen preview of the assembled PDF. Pops `true` when the user accepts
/// it, so the caller can finalise and hand the file to the create flow.
class _PdfPreviewPage extends StatelessWidget {
  const _PdfPreviewPage({required this.pdfBytes});

  final Uint8List pdfBytes;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final primary = context.colors.primary;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: MaxWidthCenter(
          maxWidth: 900,
          child: Column(
            children: [
              CustomAppBar(title: s.preview),
              Expanded(
                child: PdfViewer.data(
                  pdfBytes,
                  sourceName: 'preview_${identityHashCode(pdfBytes)}',
                  params: PdfViewerParams(
                    margin: 8,
                    onViewerReady: applyPdfFitToPage,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  12 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border(
                    top: BorderSide(color: primary.withOpacity(0.12)),
                  ),
                ),
                child: AppButtonLeadingIcon(
                  title: s.useThisDocument,
                  icon: Icons.check_rounded,
                  iconSize: 18,
                  titleSize: 15,
                  height: 50,
                  width: context.isBiggerThanMobile ? null : double.infinity,
                  onPressed: () => Navigator.of(context).pop(true),
                  backgroundColor: primary,
                  titleColor: Colors.white,
                  iconColor: Colors.white,
                  radius: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
