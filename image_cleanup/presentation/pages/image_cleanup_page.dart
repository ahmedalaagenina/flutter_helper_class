import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:idara_esign/generated/l10n.dart';

import '../../domain/cleanup_options.dart';
import '../../domain/cleanup_result.dart';
import '../../services/image_cleanup_service.dart';
import '../widgets/adjustable_crop_view.dart';
import '../widgets/checkerboard_background.dart';

/// Full-screen flow that turns a raw signature/stamp photo into a tightly
/// cropped, transparent PNG:
///
/// 1. auto-detects the ink and seeds a crop rectangle,
/// 2. lets the user adjust the crop,
/// 3. removes the background and shows a transparency preview,
/// 4. pops with a [CleanupResult] (or null when cancelled).
///
/// Push it directly, or use `ImageCleanupHelper.cleanImage` for a one-liner.
class ImageCleanupPage extends StatefulWidget {
  const ImageCleanupPage({
    super.key,
    required this.imageBytes,
    this.options = const CleanupOptions(),
  });

  /// Raw picked image bytes (PNG, JPEG, WebP, BMP, GIF, TIFF).
  final Uint8List imageBytes;

  final CleanupOptions options;

  @override
  State<ImageCleanupPage> createState() => _ImageCleanupPageState();
}

enum _Step { analyzing, adjust, processing, preview, error }

class _ImageCleanupPageState extends State<ImageCleanupPage> {
  /// Shared height so paired action buttons always match exactly.
  static const double _actionButtonHeight = 52;

  _Step _step = _Step.analyzing;
  CleanupAnalysis? _analysis;

  /// Single source of truth for the crop rectangle, shared with
  /// [AdjustableCropView]. Auto-detect resets it; drags write to it.
  final ValueNotifier<Rect> _crop = ValueNotifier(Rect.zero);

  CleanupResult? _result;
  late bool _removeBackground = widget.options.removeBackground;
  late CropShape _cropShape = widget.options.cropShape;

  /// Distinguishes "your file could not be read" (analyze failed) from
  /// "processing went wrong, try again" (the image was fine; a later stage
  /// failed) so the error step can say the right thing.
  bool _processingFailed = false;

  @override
  void initState() {
    super.initState();
    // Start heavy work only after the page's first frame is on screen, so
    // the navigation + loading indicator always appear immediately (on web
    // `compute` runs inline and would otherwise block the route transition).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _analyze();
    });
  }

  @override
  void dispose() {
    _crop.dispose();
    _analysis?.dispose();
    super.dispose();
  }

  /// Completes once the route's push animation has fully settled, so heavy
  /// work never competes with the transition frames.
  Future<void> _waitForRouteSettled() async {
    if (!mounted) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) return;
    final completer = Completer<void>();
    late final AnimationStatusListener listener;
    listener = (status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        animation.removeStatusListener(listener);
        if (!completer.isCompleted) completer.complete();
      }
    };
    animation.addStatusListener(listener);
    await completer.future;
  }

  /// Guarantees the loading indicator is actually painted before heavy work
  /// starts. Only web needs the extra settling delay: there `compute` runs
  /// inline and blocks the UI thread, so the spinner must be on screen
  /// first; on mobile/desktop the work runs in a real isolate.
  Future<void> _waitForLoadingFrame() async {
    await SchedulerBinding.instance.endOfFrame;
    if (kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _analyze() async {
    // Sequence: navigation finishes → spinner visibly painted → work starts.
    await _waitForRouteSettled();
    if (!mounted) return;
    await _waitForLoadingFrame();
    if (!mounted) return;
    final analysis = await ImageCleanupService.analyze(
      widget.imageBytes,
      options: widget.options,
    );
    if (!mounted) {
      // The user backed out mid-analysis; nothing will ever own this
      // analysis, so free its ui.Image here.
      analysis?.dispose();
      return;
    }
    if (analysis == null) {
      setState(() {
        _processingFailed = false;
        _step = _Step.error;
      });
      return;
    }
    _crop.value = analysis.analysis.suggestedCrop;
    setState(() {
      _analysis = analysis;
      _step = _Step.adjust;
    });
  }

  Future<void> _process() async {
    final analysis = _analysis;
    if (analysis == null) return;
    setState(() => _step = _Step.processing);
    // Same sequencing: spinner visibly painted before the heavy work.
    await _waitForLoadingFrame();
    if (!mounted) return;
    final result = await ImageCleanupService.process(
      analysis,
      crop: _crop.value,
      options: widget.options.copyWith(
        removeBackground: _removeBackground,
        cropShape: _cropShape,
      ),
    );
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _processingFailed = true;
        _step = _Step.error;
      });
      return;
    }
    setState(() {
      _result = result;
      _step = _Step.preview;
    });
  }

  void _resetCropToDetected() {
    final analysis = _analysis;
    if (analysis == null) return;
    // The controller notifies the crop view directly; no rebuild needed.
    _crop.value = analysis.analysis.suggestedCrop;
  }

  @override
  Widget build(BuildContext context) {
    final onPreview = _step == _Step.preview;
    final s = S.of(context);
    return PopScope(
      // On the preview step, system back returns to the adjust step instead
      // of leaving the flow.
      canPop: !onPreview,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && onPreview) {
          setState(() => _step = _Step.adjust);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(onPreview ? s.imageCleanupPreviewTitle : s.imageCleanupAdjustTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (onPreview) {
                setState(() => _step = _Step.adjust);
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
        ),
        body: SafeArea(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final s = S.of(context);
    switch (_step) {
      case _Step.analyzing:
        return _buildBusy(s.imageCleanupAnalyzing);
      case _Step.processing:
        return _buildBusy(s.imageCleanupProcessing);
      case _Step.error:
        return _buildError(context);
      case _Step.adjust:
        return _buildAdjust(context);
      case _Step.preview:
        return _buildPreview(context);
    }
  }

  Widget _buildBusy(String label) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(label, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            // Heavy images can block for a moment (especially on web, where
            // there are no isolates) — warn instead of looking broken.
            Text(
              S.of(context).imageCleanupPleaseWait,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final s = S.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _processingFailed
                  ? s.imageCleanupProcessingFailed
                  : s.imageCleanupCouldNotReadImage,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // A processing failure doesn't invalidate the image or the
            // user's crop — offer a way back to the adjust step.
            if (_processingFailed && _analysis != null)
              FilledButton(
                onPressed: () => setState(() => _step = _Step.adjust),
                child: Text(s.imageCleanupBack),
              )
            else
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(s.imageCleanupClose),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdjust(BuildContext context) {
    final analysis = _analysis!;
    final info = analysis.analysis;
    final s = S.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            s.imageCleanupCropHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AdjustableCropView(
              image: analysis.workingImage,
              controller: _crop,
              shape: _cropShape,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<CropShape>(
                segments: [
                  ButtonSegment(
                    value: CropShape.rectangle,
                    icon: const Icon(Icons.crop_square),
                    label: Text(s.imageCleanupShapeRectangle),
                  ),
                  ButtonSegment(
                    value: CropShape.oval,
                    icon: const Icon(Icons.circle_outlined),
                    label: Text(s.imageCleanupShapeCircle),
                  ),
                ],
                selected: {_cropShape},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    setState(() => _cropShape = selection.first),
              ),
              // Sources that already have transparency keep it; there is no
              // background left to remove.
              if (!info.hasAlphaContent) ...[
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(s.imageCleanupRemoveBackground),
                  value: _removeBackground,
                  onChanged: (v) => setState(() => _removeBackground = v),
                ),
                // Gradient / busy background: a different (flood-fill)
                // removal is used and usually works, but isn't guaranteed —
                // prime the user to check the result.
                if (!info.backgroundUniform)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.imageCleanupBackgroundNotUniform,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resetCropToDetected,
                      style: _actionButtonStyle,
                      icon: const Icon(Icons.center_focus_strong_outlined),
                      label: Text(s.imageCleanupAutoDetect),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _process,
                      style: _actionButtonStyle,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(s.imageCleanupContinue),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// One style for every paired action button so Outlined/Filled variants
  /// render with identical height and padding.
  ButtonStyle get _actionButtonStyle => ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size.fromHeight(_actionButtonHeight),
        ),
        maximumSize: const WidgetStatePropertyAll(
          Size.fromHeight(_actionButtonHeight),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
      );

  Widget _buildPreview(BuildContext context) {
    final result = _result!;
    final s = S.of(context);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: CheckerboardBackground(
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.memory(
                    result.pngBytes,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (result.backgroundRemoved)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    s.imageCleanupTransparencyHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              // The tool assists but the final image is the user's call —
              // ask them to confirm it looks right before using it.
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  s.imageCleanupResultDisclaimer,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _step = _Step.adjust),
                      style: _actionButtonStyle,
                      icon: const Icon(Icons.tune),
                      label: Text(s.imageCleanupBack),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(result),
                      style: _actionButtonStyle,
                      icon: const Icon(Icons.check),
                      label: Text(s.imageCleanupUseImage),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
