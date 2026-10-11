import 'package:flutter/widgets.dart';

// Relative on purpose: the motion/ folder is copied into apps as one unit.
// ignore: always_use_package_imports
import 'springs.dart';

/// A terminal window that types a command, then prints its output lines.
///
/// ```dart
/// TypingTerminal(
///   command: 'flutter pub add my_package',
///   output: const ['Resolving dependencies...', 'Changed 1 dependency!'],
///   play: isOnScreen, // starts the first time this is true
///   replayKey: replays, // change it to type everything again
/// )
/// ```
///
/// * One controller drives the whole sequence: typing, a short pause, then
///   each output line (the last one is drawn in [successColor]).
/// * The window has its final size from the first frame, so nothing around
///   it shifts while lines print. Output lines only move and fade
///   (paint-only), and the whole window sits in a [RepaintBoundary].
/// * It fills the available width, so give it a bounded one (inside a
///   `Row`, wrap it in `Expanded` or a `SizedBox`).
/// * Screen readers get one label instead of animated characters. Reduced
///   motion shows the finished terminal straight away.
class TypingTerminal extends StatefulWidget {
  /// Creates a terminal that types [command] and then prints [output].
  const TypingTerminal({
    super.key,
    required this.command,
    this.output = const <String>[],
    this.play = true,
    this.replayKey,
    this.semanticsLabel,
    this.prompt = r'$ ',
    this.cursor = '█', // Full block.
    this.textStyle,
    this.windowColor = const Color(0xFF0A0E17),
    this.borderColor = const Color(0xFF232B3B),
    this.textColor = const Color(0xFFC9D1E0),
    this.promptColor = const Color(0xFF13B9FD),
    this.outputColor = const Color(0xFF8A94A8),
    this.successColor = const Color(0xFF3DDC97),
    this.cursorColor = const Color(0xFF6C7891),
    this.headerDots = const <Color>[
      Color(0xFF2B3446),
      Color(0xFF2B3446),
      Color(0xFF2B3446),
    ],
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 22),
    this.charDuration = const Duration(milliseconds: 42),
    this.outputDelay = const Duration(milliseconds: 380),
    this.lineInterval = const Duration(milliseconds: 300),
    this.textDirection = TextDirection.ltr,
  });

  /// The command typed after the [prompt].
  final String command;

  /// Lines printed one by one after the command. The last one is the
  /// success line, drawn in [successColor].
  final List<String> output;

  /// Starts the sequence the first time it is true (e.g. once scrolled into
  /// view). Turning it false later neither stops nor resets it.
  final bool play;

  /// Change this value to clear the window and type everything again (as
  /// soon as [play] is true).
  final Object? replayKey;

  /// What screen readers announce. Defaults to the command followed by the
  /// output lines.
  final String? semanticsLabel;

  /// Shown before the command, in [promptColor]. Include any trailing space.
  final String prompt;

  /// Glyph drawn where the next character will appear, until the sequence
  /// ends.
  final String cursor;

  /// Font settings merged over the monospace default (14 px, line height
  /// 1.7). Colours come from the colour parameters, not from this style.
  final TextStyle? textStyle;

  /// Window background.
  final Color windowColor;

  /// Window border, and the line under the header dots.
  final Color borderColor;

  /// Colour of the typed command.
  final Color textColor;

  /// Colour of the [prompt].
  final Color promptColor;

  /// Colour of every output line except the last.
  final Color outputColor;

  /// Colour of the last output line.
  final Color successColor;

  /// Colour of the [cursor].
  final Color cursorColor;

  /// Colours of the dots in the window's header bar. An empty list hides the
  /// header bar.
  final List<Color> headerDots;

  /// Corner radius of the window.
  final BorderRadius borderRadius;

  /// Space between the window edge and the text.
  final EdgeInsetsGeometry padding;

  /// Time to type one character.
  final Duration charDuration;

  /// Pause between the end of typing and the first output line.
  final Duration outputDelay;

  /// Time between one output line appearing and the next.
  final Duration lineInterval;

  /// Terminal content is code, so it lays out left to right by default,
  /// even inside a right-to-left app.
  final TextDirection textDirection;

  @override
  State<TypingTerminal> createState() => _TypingTerminalState();
}

class _TypingTerminalState extends State<TypingTerminal>
    with SingleTickerProviderStateMixin {
  static const _transparent = Color(0x00000000);

  // Each output line rises into place with this spring. Its settle time is
  // part of the timeline, so the controller ends when the last line lands.
  final _lineCurve = SpringCurve(Springs.gentle);

  late _Timeline _timeline;
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _timeline = _Timeline(widget, _lineCurve.duration);
    _controller = AnimationController(vsync: this, duration: _timeline.total);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(TypingTerminal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _timeline = _Timeline(widget, _lineCurve.duration);
    _controller.duration = _timeline.total;
    if (oldWidget.replayKey != widget.replayKey) {
      _started = false;
      _controller.value = 0;
    }
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sync() {
    if (context.reduceMotion) {
      // Calm static result: the finished terminal, with no ticker running.
      _started = true;
      if (!_controller.isCompleted) _controller.value = 1;
      return;
    }
    if (_started || !widget.play) return;
    _started = true;
    _controller.forward(from: 0);
  }

  double get _elapsedMs => _controller.value * _timeline.totalMs;

  @override
  Widget build(BuildContext context) {
    final base = const TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: <String>['Menlo', 'Consolas', 'Courier New'],
      fontSize: 14,
      height: 1.7,
    ).merge(widget.textStyle);

    return Directionality(
      textDirection: widget.textDirection,
      child: Semantics(
        label:
            widget.semanticsLabel ??
            [widget.command, ...widget.output].join('\n'),
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: widget.windowColor,
                borderRadius: widget.borderRadius,
                border: Border.all(color: widget.borderColor),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.headerDots.isNotEmpty) _header(),
                  Padding(
                    padding: widget.padding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _commandLine(base),
                        for (var i = 0; i < widget.output.length; i++)
                          _outputLine(i, base),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: widget.borderColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            for (final color in widget.headerDots)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 7),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.square(dimension: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _commandLine(TextStyle base) {
    final command = widget.command;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final typed = _timeline.typedLengthAt(_elapsedMs);
        final done = _controller.isCompleted;
        // The untyped rest is drawn transparent, so the line has its final
        // layout from the start and never re-wraps while typing. The
        // paragraph is laid out again only when a character appears.
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: widget.prompt,
                style: TextStyle(color: widget.promptColor),
              ),
              TextSpan(text: command.substring(0, typed)),
              TextSpan(
                text: widget.cursor,
                style: TextStyle(
                  color: done ? _transparent : widget.cursorColor,
                ),
              ),
              TextSpan(
                text: command.substring(typed),
                style: const TextStyle(color: _transparent),
              ),
            ],
          ),
          style: base.copyWith(color: widget.textColor),
        );
      },
    );
  }

  Widget _outputLine(int i, TextStyle base) {
    final isLast = i == widget.output.length - 1;
    final rise = (base.fontSize ?? 14) * 0.4;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // lineAt is clamped to 0..1, so the spring gets a valid input; its
        // overshoot only moves the line, and the opacity is clamped.
        final t = _lineCurve.transform(_timeline.lineAt(i, _elapsedMs));
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * rise),
            child: child,
          ),
        );
      },
      // Laid out from the first frame (just invisible), so the window never
      // grows while lines print.
      child: Text(
        widget.output[i],
        style: base.copyWith(
          color: isLast ? widget.successColor : widget.outputColor,
        ),
      ),
    );
  }
}

/// When each step of the sequence happens, in milliseconds from the start.
class _Timeline {
  _Timeline._({
    required this.ends,
    required this.charMs,
    required this.outputStartMs,
    required this.lineMs,
    required this.entranceMs,
    required this.totalMs,
  });

  factory _Timeline(TypingTerminal widget, Duration lineEntrance) {
    // UTF-16 end offset after each grapheme, so typing never splits an emoji.
    final ends = <int>[0];
    for (final grapheme in widget.command.characters) {
      ends.add(ends.last + grapheme.length);
    }
    final charMs = _ms(widget.charDuration);
    final typingMs = charMs * (ends.length - 1);
    final lines = widget.output.length;
    final outputStartMs = typingMs + (lines == 0 ? 0 : _ms(widget.outputDelay));
    final lineMs = _ms(widget.lineInterval);
    final entranceMs = _ms(lineEntrance);
    return _Timeline._(
      ends: ends,
      charMs: charMs,
      outputStartMs: outputStartMs,
      lineMs: lineMs,
      entranceMs: entranceMs,
      totalMs: lines == 0
          ? typingMs
          : outputStartMs + lineMs * (lines - 1) + entranceMs,
    );
  }

  static double _ms(Duration duration) => duration.inMicroseconds / 1000;

  final List<int> ends;
  final double charMs;
  final double outputStartMs;
  final double lineMs;
  final double entranceMs;
  final double totalMs;

  Duration get total => Duration(microseconds: (totalMs * 1000).round());

  /// UTF-16 length of the part of the command typed after [ms].
  int typedLengthAt(double ms) {
    final count = ends.length - 1;
    if (charMs <= 0 || ms >= charMs * count) return ends[count];
    if (ms <= 0) return 0;
    return ends[(ms / charMs).floor()];
  }

  /// How far output line [i] has entered after [ms], from 0 to 1.
  double lineAt(int i, double ms) {
    final start = outputStartMs + lineMs * i;
    if (ms >= start + entranceMs) return 1;
    if (ms <= start) return 0;
    return (ms - start) / entranceMs;
  }
}
