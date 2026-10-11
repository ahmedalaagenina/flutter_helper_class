import 'dart:async';

import 'package:flutter/widgets.dart';

// Relative on purpose: the motion/ folder is copied into apps as one unit.
// ignore: always_use_package_imports
import 'springs.dart';

/// Text that cycles through a list of phrases, each one sliding up into place.
///
/// ```dart
/// RotatingText(
///   texts: const ['Flutter apps', 'Design systems', 'Realtime maps'],
///   style: textTheme.headlineSmall,
///   active: isOnScreen, // pause while scrolled away
/// )
/// ```
///
/// * The old phrase leaves upward while the new one rises from below,
///   exactly one line apart, so the two never overlap.
/// * Screen readers get one stable label (every phrase) instead of a stream
///   of changes. Reduced motion keeps the current phrase still.
/// * The timer runs only while [active] is true. The slide ticker runs only
///   during a change, inside a [RepaintBoundary], and is muted on a covered
///   route, so a hidden page draws no frames (the pending change plays when
///   the page shows again).
class RotatingText extends StatefulWidget {
  /// Creates text that rotates through [texts].
  // No `texts` assert here: a const constructor's asserts may not read a
  // List's length, which would break `const RotatingText(...)`. The State
  // checks it instead.
  const RotatingText({
    super.key,
    required this.texts,
    this.style,
    this.interval = const Duration(milliseconds: 2600),
    this.active = true,
    this.alignment = AlignmentDirectional.centerStart,
    this.semanticsLabel,
    this.spring,
  });

  /// The phrases to cycle through, in order. Must not be empty. Each stays
  /// on a single line.
  final List<String> texts;

  /// Text style, merged over the ambient [DefaultTextStyle] like [Text].
  final TextStyle? style;

  /// Time from one phrase change to the next (the slide is part of it).
  final Duration interval;

  /// Whether the phrases cycle. Set it to false to pause, e.g. off screen.
  final bool active;

  /// Where the phrases sit while the outgoing and incoming ones share the
  /// box. Match it to how the parent aligns this widget (start, centre or
  /// end), so the box can shrink after a change without the text moving.
  final AlignmentGeometry alignment;

  /// What screen readers announce. Defaults to every phrase, comma-joined.
  final String? semanticsLabel;

  /// The spring for the slide. Defaults to [Springs.gentle] (no visible
  /// bounce).
  final SpringDescription? spring;

  @override
  State<RotatingText> createState() => _RotatingTextState();
}

class _RotatingTextState extends State<RotatingText>
    with SingleTickerProviderStateMixin {
  late SpringCurve _curve;
  late final AnimationController _slide;
  Timer? _timer;
  int _index = 0;

  // The phrase sliding out, or null when nothing is moving.
  int? _leaving;

  @override
  void initState() {
    super.initState();
    _debugCheckWidget();
    _curve = SpringCurve(widget.spring ?? Springs.gentle);
    // Starts settled (value 1): the first phrase is simply in place.
    _slide = AnimationController(
      vsync: this,
      duration: _curve.duration,
      value: 1,
    )..addStatusListener(_onSlideStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RotatingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _debugCheckWidget();
    if (oldWidget.spring != widget.spring) {
      _curve = SpringCurve(widget.spring ?? Springs.gentle);
      _slide.duration = _curve.duration;
    }
    final count = widget.texts.length;
    if (_index >= count || (_leaving ?? 0) >= count) {
      // The list shrank under us: restart calmly from the first phrase.
      _index = 0;
      _leaving = null;
      _slide.value = 1;
    }
    if (oldWidget.interval != widget.interval) _stopTimer();
    _sync();
  }

  @override
  void dispose() {
    _stopTimer();
    _slide.dispose();
    super.dispose();
  }

  void _debugCheckWidget() {
    assert(widget.texts.isNotEmpty, 'RotatingText needs at least one phrase.');
    assert(
      widget.interval > Duration.zero,
      'RotatingText.interval must be greater than zero.',
    );
  }

  /// Starts or stops the timer to match [RotatingText.active] and reduced
  /// motion.
  ///
  /// [TickerMode] is deliberately not read here: `TickerMode.valuesOf` needs
  /// Flutter 3.41+ and `TickerMode.of` is deprecated. On a covered route the
  /// slide's ticker is muted instead: the next change starts but draws no
  /// frame, and later ticks skip while it is pending (see [_advance]).
  void _sync() {
    final reduceMotion = context.reduceMotion;
    final run = widget.active && widget.texts.length > 1 && !reduceMotion;
    if (run) {
      _timer ??= Timer.periodic(widget.interval, (_) => _advance());
    } else {
      _stopTimer();
    }
    // Reduced motion: finish a running slide at once.
    if (reduceMotion && _slide.isAnimating) _slide.value = 1;
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _advance() {
    // Skip a beat rather than cut a slide short (interval < slide time), or
    // while a change waits on a muted ticker (covered route).
    if (!mounted || _slide.isAnimating) return;
    setState(() {
      _leaving = _index;
      _index = (_index + 1) % widget.texts.length;
    });
    _slide.forward(from: 0);
  }

  void _onSlideStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _leaving != null) {
      setState(() => _leaving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Release builds skip the assert: show nothing rather than throw.
    if (widget.texts.isEmpty) return const SizedBox.shrink();
    // Built once per change, not per frame: the builder below only moves
    // and fades these, so their paragraphs are never laid out again.
    final current = _phrase(_index);
    final leaving = _leaving == null ? null : _phrase(_leaving!);
    return Semantics(
      label: widget.semanticsLabel ?? widget.texts.join(', '),
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _slide,
            builder: (context, _) {
              // One value drives both phrases, a full line apart: the new
              // one rises from below while the old one leaves above.
              final t = _curve.transform(_slide.value);
              return ClipRect(
                // Clip only while sliding, so glyphs that overhang the line
                // box (tall accents, tight line height) are never cut at rest.
                clipBehavior: leaving == null ? Clip.none : Clip.hardEdge,
                child: Stack(
                  alignment: widget.alignment,
                  children: [
                    if (leaving != null)
                      _shift(
                        leaving,
                        key: _leaving!,
                        offset: -t,
                        opacity: 1 - t,
                      ),
                    _shift(current, key: _index, offset: 1 - t, opacity: t),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _phrase(int index) => Text(
    widget.texts[index],
    style: widget.style,
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.ellipsis,
  );

  /// Moves [phrase] by [offset] of its own height. Paint-only: neither the
  /// translation nor the opacity triggers a layout. Keyed by phrase index so
  /// a phrase keeps its element when it switches from incoming to leaving.
  static Widget _shift(
    Widget phrase, {
    required int key,
    required double offset,
    required double opacity,
  }) {
    return FractionalTranslation(
      key: ValueKey<int>(key),
      translation: Offset(0, offset),
      child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: phrase),
    );
  }
}
