import 'dart:async';

import 'package:flutter/widgets.dart';

// Relative on purpose: the motion/ folder is copied into apps as one unit.
// ignore: always_use_package_imports
import 'springs.dart';

/// Text that appears letter by letter, each letter springing up into place.
///
/// ```dart
/// // Plays by itself the first time it builds.
/// StaggeredText(text: 'Ahmed Alaa', style: textTheme.displayLarge)
///
/// // Or let a parent controller run it together with other entrances.
/// StaggeredText(
///   text: 'Ahmed Alaa',
///   style: textTheme.displayLarge,
///   progress: CurvedAnimation(
///     parent: entrance,
///     curve: const Interval(0, 0.6),
///   ),
/// )
/// ```
///
/// * Each letter lands exactly where the real text layout draws it (kerning,
///   letter spacing, line breaks and baseline included). When the animation
///   completes, the widget swaps to one plain [Text], so the swap is
///   invisible and the steady state is just a paragraph.
/// * Per-frame work is paint-only: a single [Flow] behind a [RepaintBoundary]
///   moves and fades the letters, with no rebuild and no relayout.
/// * Screen readers hear [text] once. Reduced motion shows the plain text.
/// * Letters are drawn separately, so joined scripts such as Arabic look
///   unjoined until the final swap; prefer a whole-text entrance for those.
/// * While animating it measures with a [LayoutBuilder], which cannot run
///   under intrinsic sizing (`IntrinsicWidth`, an AlertDialog's content).
class StaggeredText extends StatefulWidget {
  /// Creates text that reveals itself letter by letter.
  const StaggeredText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.progress,
    this.duration = const Duration(milliseconds: 900),
    this.delay = Duration.zero,
    this.autoplay = true,
    this.stagger = 0.05,
    this.letterSpan = 0.5,
    this.rise = 0.4,
    this.spring,
  }) : assert(stagger >= 0, 'stagger cannot be negative.'),
       assert(letterSpan > 0, 'letterSpan must be greater than 0.');

  /// The text to show.
  final String text;

  /// Text style, merged over the ambient [DefaultTextStyle] like [Text].
  final TextStyle? style;

  /// How lines are aligned. Falls back to the ambient [DefaultTextStyle].
  final TextAlign? textAlign;

  /// Drives the reveal from 0 (hidden) to 1 (fully shown), so a parent can
  /// orchestrate it with other entrances. Pass a linear slice (e.g. an
  /// [Interval]): every letter already applies its own spring.
  ///
  /// Leave it null and the widget runs its own animation, configured by
  /// [duration], [delay] and [autoplay].
  final Animation<double>? progress;

  /// Length of the self-run animation. Ignored when [progress] is given.
  final Duration duration;

  /// Wait before the self-run animation starts. Ignored when [progress] is
  /// given.
  final Duration delay;

  /// Whether the self-run animation starts by itself. While false the text
  /// stays hidden (its space is already reserved) and it plays once this
  /// turns true, which suits "play when scrolled into view". Ignored when
  /// [progress] is given.
  final bool autoplay;

  /// Delay between one letter and the next, as a fraction of the whole
  /// animation. The timeline is normalised so the last letter always lands
  /// exactly at the end.
  final double stagger;

  /// Length of one letter's own animation, as a fraction of the whole.
  final double letterSpan;

  /// How far each letter rises into place, as a fraction of the font size.
  final double rise;

  /// The spring each letter follows. Defaults to [Springs.playful], which
  /// lands every letter with a small bounce.
  final SpringDescription? spring;

  @override
  State<StaggeredText> createState() => _StaggeredTextState();
}

class _StaggeredTextState extends State<StaggeredText>
    with SingleTickerProviderStateMixin {
  // Created only when the caller gives no progress, and at most once per
  // State, so one ticker is all this State ever makes.
  AnimationController? _own;
  Timer? _delay;
  bool _started = false;
  bool _complete = false;
  late SpringCurve _curve = SpringCurve(widget.spring ?? Springs.playful);

  Animation<double> get _progress =>
      widget.progress ??
      (_own ??= AnimationController(vsync: this, duration: widget.duration));

  @override
  void initState() {
    super.initState();
    _listenTo(_progress);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncOwn();
  }

  @override
  void didUpdateWidget(StaggeredText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spring != widget.spring) {
      _curve = SpringCurve(widget.spring ?? Springs.playful);
    }
    if (oldWidget.progress != widget.progress) {
      (oldWidget.progress ?? _own)?.removeStatusListener(_onStatus);
      if (widget.progress != null) {
        // The caller took over: park the self-run animation.
        _delay?.cancel();
        _own?.stop();
      } else {
        // Back to self-run: resume from wherever it was parked.
        _started = false;
      }
      _listenTo(_progress);
    }
    _own?.duration = widget.duration;
    _syncOwn();
  }

  @override
  void dispose() {
    _delay?.cancel();
    (widget.progress ?? _own)?.removeStatusListener(_onStatus);
    _own?.dispose();
    super.dispose();
  }

  void _listenTo(Animation<double> progress) {
    progress.addStatusListener(_onStatus);
    _complete = progress.status == AnimationStatus.completed;
  }

  // Rebuilds only when "complete" flips, to swap between letters and Text.
  void _onStatus(AnimationStatus status) {
    final complete = status == AnimationStatus.completed;
    if (complete != _complete) setState(() => _complete = complete);
  }

  /// Starts the self-run animation (only used when there is no progress).
  void _syncOwn() {
    final own = _own;
    if (own == null || widget.progress != null) return;
    if (context.reduceMotion) {
      // Calm static result: jump to the end without running the ticker.
      _delay?.cancel();
      _started = true;
      if (own.status != AnimationStatus.completed) own.value = 1;
      return;
    }
    if (_started || !widget.autoplay) return;
    _started = true;
    if (widget.delay <= Duration.zero) {
      own.forward();
      return;
    }
    _delay = Timer(widget.delay, () {
      if (!mounted) return;
      own.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_complete || context.reduceMotion || widget.text.isEmpty) {
      return Text(
        widget.text,
        style: widget.style,
        textAlign: widget.textAlign,
      );
    }
    return LayoutBuilder(builder: _buildLetters);
  }

  Widget _buildLetters(BuildContext context, BoxConstraints constraints) {
    // Resolve the same inherited settings that Text uses, so every letter
    // lands exactly where the final paragraph will draw it.
    final defaults = DefaultTextStyle.of(context);
    var style = defaults.style.merge(widget.style);
    if (MediaQuery.boldTextOf(context)) {
      style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    final scaler = MediaQuery.textScalerOf(context);
    final ellipsis =
        (style.overflow ?? defaults.overflow) == TextOverflow.ellipsis;
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      textAlign: widget.textAlign ?? defaults.textAlign ?? TextAlign.start,
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
      textScaler: scaler,
      maxLines: defaults.maxLines,
      ellipsis: ellipsis ? '…' : null,
      textWidthBasis: defaults.textWidthBasis,
      textHeightBehavior:
          defaults.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context),
    );
    painter.layout(
      minWidth: constraints.minWidth,
      maxWidth: defaults.softWrap || ellipsis
          ? constraints.maxWidth
          : double.infinity,
    );

    final lines = painter.computeLineMetrics();
    // Grapheme clusters, so an emoji or an accented letter is never split.
    final graphemes = widget.text.characters.toList();
    final total = widget.stagger * (graphemes.length - 1) + widget.letterSpan;
    final slots = <_Slot>[];
    final letters = <Widget>[];
    var end = 0;
    for (var i = 0; i < graphemes.length; i++) {
      final grapheme = graphemes[i];
      final start = end;
      end += grapheme.length;
      // Spaces keep their place in the timeline but draw nothing.
      if (grapheme.trim().isEmpty) continue;
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
      );
      // No box: the letter was cut off (e.g. by maxLines).
      if (boxes.isEmpty) continue;
      final box = boxes.first;
      slots.add(
        _Slot(
          box.left,
          widget.stagger * i / total,
          (widget.stagger * i + widget.letterSpan) / total,
        ),
      );
      // Align baselines, not box tops: a glyph box leaves out the line's
      // leading, so with a custom `height` a top-aligned letter would sit
      // off its line and jump at the swap.
      letters.add(
        Baseline(
          baseline: _baselineOf(lines, box),
          baselineType: TextBaseline.alphabetic,
          child: Text(grapheme, style: style),
        ),
      );
    }
    final size = constraints.constrain(painter.size);
    painter.dispose();

    return Semantics(
      label: widget.text,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: Flow(
            delegate: _LetterFlow(
              progress: _progress,
              slots: slots,
              curve: _curve,
              rise: widget.rise * scaler.scale(style.fontSize ?? 14),
              size: size,
            ),
            // Letters rise from below their spot; never clip them.
            clipBehavior: Clip.none,
            children: letters,
          ),
        ),
      ),
    );
  }

  /// Baseline of the line holding [box]: the glyph's vertical centre falls
  /// inside exactly one line's band.
  static double _baselineOf(List<LineMetrics> lines, TextBox box) {
    final centre = (box.top + box.bottom) / 2;
    for (final line in lines) {
      if (centre <= line.baseline + line.descent) return line.baseline;
    }
    return lines.isEmpty ? box.bottom : lines.last.baseline;
  }
}

/// Where one letter lands, and its slice of the timeline (fractions 0..1).
class _Slot {
  const _Slot(this.x, this.start, this.end);

  final double x;
  final double start;
  final double end;
}

/// Paints each letter at its slot, risen and faded by its share of
/// [progress]. Runs at paint time only: [progress] is the repaint trigger.
class _LetterFlow extends FlowDelegate {
  _LetterFlow({
    required this.progress,
    required this.slots,
    required this.curve,
    required this.rise,
    required this.size,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final List<_Slot> slots;
  final Curve curve;
  final double rise;
  final Size size;

  @override
  Size getSize(BoxConstraints constraints) => constraints.constrain(size);

  // Letters take their natural size; the delegate only positions them.
  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      const BoxConstraints();

  @override
  void paintChildren(FlowPaintingContext context) {
    // Clamp first: a parent driven by an overshooting curve can pass 1.0,
    // and Curve.transform asserts that its input is within 0..1.
    final p = progress.value.clamp(0.0, 1.0);
    for (var i = 0; i < context.childCount; i++) {
      final slot = slots[i];
      final local = ((p - slot.start) / (slot.end - slot.start)).clamp(
        0.0,
        1.0,
      );
      // The spring may overshoot 1 (the letter pops slightly above its spot,
      // then settles), so only the opacity needs clamping.
      final t = curve.transform(local);
      context.paintChild(
        i,
        transform: Matrix4.translationValues(slot.x, (1 - t) * rise, 0),
        opacity: t.clamp(0.0, 1.0),
      );
    }
  }

  @override
  bool shouldRepaint(_LetterFlow oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.slots != slots ||
      oldDelegate.curve != curve ||
      oldDelegate.rise != rise;

  @override
  bool shouldRelayout(_LetterFlow oldDelegate) => oldDelegate.size != size;
}
