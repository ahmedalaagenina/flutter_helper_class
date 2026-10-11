import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

// Relative on purpose: the motion/ folder is copied into apps as one unit.
// ignore: always_use_package_imports
import 'spring_offset.dart';
// ignore: always_use_package_imports
import 'springs.dart';

/// Counts how many interactive widgets the mouse is over, so the cursor
/// ring knows when to grow. You rarely use it directly: [CursorTarget] and
/// `Pressable` call it for you.
///
/// A counter (not a bool) keeps nested targets from cancelling each other.
class CursorController extends ChangeNotifier {
  int _targets = 0;

  /// True while the mouse is over at least one target.
  bool get overTarget => _targets > 0;

  void enter() {
    _targets++;
    if (_targets == 1) notifyListeners();
  }

  void exit() {
    if (_targets == 0) return;
    _targets--;
    if (_targets == 0) notifyListeners();
  }
}

/// Makes a [CursorController] available to the widgets below it.
///
/// It never rebuilds its dependents: widgets only *call* the controller, so
/// hovering a button repaints the ring and nothing else.
class CursorScope extends InheritedWidget {
  const CursorScope({super.key, required this.controller, required super.child});

  final CursorController controller;

  /// The nearest controller, or null when there is no [CursorFollower].
  static CursorController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CursorScope>()?.controller;

  @override
  bool updateShouldNotify(CursorScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Wrap any widget with this to make the cursor ring grow while the mouse
/// is over it (links, cards, custom buttons).
///
/// ```dart
/// CursorTarget(child: GestureDetector(onTap: open, child: ProjectCard()));
/// ```
class CursorTarget extends StatefulWidget {
  const CursorTarget({super.key, required this.child});

  final Widget child;

  @override
  State<CursorTarget> createState() => _CursorTargetState();
}

class _CursorTargetState extends State<CursorTarget> {
  CursorController? _controller;
  bool _hovered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = CursorScope.maybeOf(context);
  }

  @override
  void dispose() {
    if (_hovered) _controller?.exit();
    super.dispose();
  }

  void _set(bool hovered) {
    if (_hovered == hovered) return;
    _hovered = hovered;
    hovered ? _controller?.enter() : _controller?.exit();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    opaque: false,
    onEnter: (_) => _set(true),
    onExit: (_) => _set(false),
    child: widget.child,
  );
}

/// A soft ring that trails the mouse and grows over interactive widgets.
///
/// Put it once around your app (e.g. in `MaterialApp.builder`). It shows up
/// on the first mouse movement and hides on touch, so phones never see it.
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => CursorFollower(child: child!),
/// );
/// ```
///
/// * The system cursor stays visible: the ring is decoration, never a
///   replacement for a precise pointer.
/// * Painted in its own layer by a spring that only ticks while moving, so
///   following the mouse never repaints the page.
/// * Off with reduced motion (the scope still works, so targets don't care).
class CursorFollower extends StatefulWidget {
  const CursorFollower({
    super.key,
    required this.child,
    this.idleColor,
    this.activeColor,
    this.idleRadius = 10,
    this.activeRadius = 24,
    this.strokeWidth = 1.5,
  });

  final Widget child;

  /// Ring color when not over a target. Defaults to the ambient text color
  /// at half opacity.
  final Color? idleColor;

  /// Ring color over a target. Defaults to the ambient text color; pass
  /// your brand color here.
  final Color? activeColor;
  final double idleRadius;
  final double activeRadius;
  final double strokeWidth;

  @override
  State<CursorFollower> createState() => _CursorFollowerState();
}

class _CursorFollowerState extends State<CursorFollower>
    with TickerProviderStateMixin {
  final _controller = CursorController();
  late final _position = SpringOffset(vsync: this, spring: Springs.follow);
  late final _grow = AnimationController.unbounded(vsync: this);
  final _visible = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTargetChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _position.dispose();
    _grow.dispose();
    _visible.dispose();
    super.dispose();
  }

  void _onTargetChanged() {
    _grow.animateWith(
      SpringSimulation(
        Springs.snappy,
        _grow.value,
        _controller.overTarget ? 1 : 0,
        _grow.velocity,
      ),
    );
  }

  void _onPointer(PointerEvent event) {
    if (event.kind != PointerDeviceKind.mouse) {
      _visible.value = false;
      return;
    }
    if (!_visible.value) {
      _position.jumpTo(event.position);
      _visible.value = true;
    } else {
      _position.animateTo(event.position);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scoped = CursorScope(controller: _controller, child: widget.child);
    if (MediaQuery.disableAnimationsOf(context)) return scoped;

    final colors = _ThemeColors.of(context);
    return Listener(
      onPointerHover: _onPointer,
      onPointerMove: _onPointer,
      onPointerDown: _onPointer,
      child: MouseRegion(
        opaque: false,
        onExit: (_) => _visible.value = false,
        child: Stack(
          children: [
            scoped,
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _RingPainter(
                      position: _position,
                      grow: _grow,
                      visible: _visible,
                      idle: widget.idleColor ?? colors.idle,
                      active: widget.activeColor ?? colors.active,
                      idleRadius: widget.idleRadius,
                      activeRadius: widget.activeRadius,
                      strokeWidth: widget.strokeWidth,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Default ring colors without depending on Material: falls back to the
/// ambient text color when there is no Material theme above.
class _ThemeColors {
  const _ThemeColors(this.idle, this.active);

  factory _ThemeColors.of(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.color ??
        const Color(0xFF8A94A8);
    return _ThemeColors(base.withValues(alpha: 0.5), base);
  }

  final Color idle;
  final Color active;
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.position,
    required this.grow,
    required this.visible,
    required this.idle,
    required this.active,
    required this.idleRadius,
    required this.activeRadius,
    required this.strokeWidth,
  }) : super(repaint: Listenable.merge([position, grow, visible]));

  final SpringOffset position;
  final Animation<double> grow;
  final ValueListenable<bool> visible;
  final Color idle;
  final Color active;
  final double idleRadius;
  final double activeRadius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible.value) return;
    // The spring may overshoot a little: clamp before mixing colors, allow
    // the radius a small bounce.
    final g = grow.value.clamp(0.0, 1.2);
    final mix = g.clamp(0.0, 1.0);
    final radius = idleRadius + (activeRadius - idleRadius) * g;
    final center = position.value;
    canvas
      ..drawCircle(
        center,
        radius,
        Paint()..color = active.withValues(alpha: active.a * 0.12 * mix),
      )
      ..drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = Color.lerp(idle, active, mix)!,
      );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.idle != idle ||
      old.active != active ||
      old.idleRadius != idleRadius ||
      old.activeRadius != activeRadius ||
      old.strokeWidth != strokeWidth;
}
