import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Wraps your app and, when switched on, outlines every widget on screen,
/// like Flutter's "debug paint" but working in release builds too.
///
/// A fun easter egg for portfolios and a handy layout check for QA builds.
/// Two built-in ways to switch it on:
/// * the Konami code on a keyboard (↑ ↑ ↓ ↓ ← → ← → B A),
/// * N quick taps on something (Android developer-options style): call
///   `DebugPaintScope.maybeOf(context)?.registerTap()` from a logo's onTap.
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => DebugPaintScope(
///     onToggled: (on) => showToast(on ? l10n.debugOn : l10n.debugOff),
///     onTapsRemaining: (n) => showToast(l10n.stepsAway(n)),
///     child: child!,
///   ),
/// );
/// ```
///
/// * No built-in text: show your own messages from [onToggled] and
///   [onTapsRemaining].
/// * The overlay exists only while enabled. It walks the render tree once
///   per frame, accumulating each child's paint transform (O(n)), and caps
///   the number of boxes it draws.
/// * Keys are never swallowed: arrows keep scrolling while you type the code.
class DebugPaintScope extends StatefulWidget {
  const DebugPaintScope({
    super.key,
    required this.child,
    this.onToggled,
    this.onTapsRemaining,
    this.tapsNeeded = 7,
    this.enableKonamiCode = true,
    this.boxColor = const Color(0xFF00E5FF),
    this.textColor = const Color(0xFF7CFC00),
    this.paddingColor = const Color(0x1F00E5FF),
    this.maxBoxes = 1800,
  });

  final Widget child;

  /// Called when the overlay turns on or off.
  final ValueChanged<bool>? onToggled;

  /// Called on each counted tap with how many taps are left (only while
  /// the overlay is off and 4 or fewer taps remain, like Android does).
  final ValueChanged<int>? onTapsRemaining;

  /// Quick taps needed to toggle via [DebugPaintController.registerTap].
  final int tapsNeeded;
  final bool enableKonamiCode;

  /// Outline color of ordinary boxes.
  final Color boxColor;

  /// Outline color of text paragraphs.
  final Color textColor;

  /// Fill color of padding areas.
  final Color paddingColor;

  /// Upper bound on outlined boxes per frame.
  final int maxBoxes;

  /// The controller of the nearest scope, if any.
  static DebugPaintController? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<_DebugPaintInherited>()
      ?.controller;

  @override
  State<DebugPaintScope> createState() => _DebugPaintScopeState();
}

/// What widgets below a [DebugPaintScope] can do with it.
abstract interface class DebugPaintController {
  /// Whether the overlay is currently shown.
  bool get enabled;

  /// Turns the overlay on or off.
  void toggle();

  /// Counts one quick tap; toggles after `tapsNeeded` taps in a row.
  void registerTap();
}

class _DebugPaintScopeState extends State<DebugPaintScope>
    implements DebugPaintController {
  static const _konami = [
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.keyB,
    LogicalKeyboardKey.keyA,
  ];

  final _rootKey = GlobalKey();
  bool _enabled = false;
  int _konamiIndex = 0;
  int _taps = 0;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  bool get enabled => _enabled;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (!widget.enableKonamiCode || event is! KeyDownEvent) return false;
    if (event.logicalKey == _konami[_konamiIndex]) {
      _konamiIndex++;
      if (_konamiIndex == _konami.length) {
        _konamiIndex = 0;
        toggle();
      }
    } else {
      _konamiIndex = event.logicalKey == _konami.first ? 1 : 0;
    }
    return false;
  }

  @override
  void toggle() {
    if (!mounted) return;
    setState(() => _enabled = !_enabled);
    widget.onToggled?.call(_enabled);
  }

  @override
  void registerTap() {
    final now = DateTime.now();
    if (now.difference(_lastTap) > const Duration(milliseconds: 1500)) {
      _taps = 0;
    }
    _lastTap = now;
    _taps++;
    final left = widget.tapsNeeded - _taps;
    if (left <= 0) {
      _taps = 0;
      toggle();
    } else if (left <= 4 && !_enabled) {
      widget.onTapsRemaining?.call(left);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DebugPaintInherited(
      controller: this,
      child: Stack(
        textDirection: TextDirection.ltr,
        children: [
          KeyedSubtree(key: _rootKey, child: widget.child),
          if (_enabled)
            Positioned.fill(
              child: IgnorePointer(
                child: _DebugOverlay(
                  rootKey: _rootKey,
                  boxColor: widget.boxColor,
                  textColor: widget.textColor,
                  paddingColor: widget.paddingColor,
                  maxBoxes: widget.maxBoxes,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DebugPaintInherited extends InheritedWidget {
  const _DebugPaintInherited({required this.controller, required super.child});

  final DebugPaintController controller;

  @override
  bool updateShouldNotify(_DebugPaintInherited old) => false;
}

/// Repaints every frame while it exists (the page may scroll or animate).
class _DebugOverlay extends StatefulWidget {
  const _DebugOverlay({
    required this.rootKey,
    required this.boxColor,
    required this.textColor,
    required this.paddingColor,
    required this.maxBoxes,
  });

  final GlobalKey rootKey;
  final Color boxColor;
  final Color textColor;
  final Color paddingColor;
  final int maxBoxes;

  @override
  State<_DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<_DebugOverlay>
    with SingleTickerProviderStateMixin {
  final _frame = ValueNotifier(0);
  late final Ticker _ticker = createTicker((_) => _frame.value++)..start();

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _BoxesPainter(
        rootKey: widget.rootKey,
        repaint: _frame,
        box: widget.boxColor,
        text: widget.textColor,
        padding: widget.paddingColor,
        maxBoxes: widget.maxBoxes,
      ),
    ),
  );
}

class _BoxesPainter extends CustomPainter {
  _BoxesPainter({
    required this.rootKey,
    required Listenable repaint,
    required Color box,
    required Color text,
    required Color padding,
    required this.maxBoxes,
  }) : _box = Paint()
         ..style = PaintingStyle.stroke
         ..strokeWidth = 1
         ..color = box,
       _text = Paint()
         ..style = PaintingStyle.stroke
         ..strokeWidth = 1
         ..color = text,
       _padding = Paint()..color = padding,
       super(repaint: repaint);

  final GlobalKey rootKey;
  final int maxBoxes;
  final Paint _box;
  final Paint _text;
  final Paint _padding;

  @override
  void paint(Canvas canvas, Size size) {
    final root = rootKey.currentContext?.findRenderObject();
    if (root == null) return;
    final screen = Offset.zero & size;
    var count = 0;

    // Walk down the tree, accumulating each child's paint transform, so
    // every box is placed in O(1) instead of re-walking up to the root.
    void visit(RenderObject node, Matrix4 toRoot) {
      if (count >= maxBoxes) return;
      if (node is RenderBox && node.hasSize) {
        final rect = MatrixUtils.transformRect(toRoot, Offset.zero & node.size);
        if (rect.width >= 2 && rect.height >= 2 && rect.overlaps(screen)) {
          count++;
          if (node is RenderPadding) {
            final inner = node.padding
                .resolve(TextDirection.ltr)
                .deflateRect(rect);
            canvas.drawPath(
              Path()
                ..fillType = PathFillType.evenOdd
                ..addRect(rect)
                ..addRect(inner),
              _padding,
            );
          }
          canvas.drawRect(
            rect.deflate(0.5),
            node is RenderParagraph ? _text : _box,
          );
        }
      }
      node.visitChildren((child) {
        final m = toRoot.clone();
        node.applyPaintTransform(child, m);
        visit(child, m);
      });
    }

    visit(root, Matrix4.identity());
  }

  @override
  bool shouldRepaint(_BoxesPainter old) => false;
}
