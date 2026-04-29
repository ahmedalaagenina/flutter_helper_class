import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:idara_driver/core/widgets/app_snack_bars.dart';

class SOSButton extends StatefulWidget {
  final VoidCallback onActivated;

  const SOSButton({super.key, required this.onActivated});

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(seconds: 3);

  late AnimationController _progressController;
  Timer? _hapticTimer;
  OverlayEntry? _hintOverlay;
  bool _isHolding = false;
  bool _holdCompleted = false;

  @override
  void initState() {
    super.initState();
    _progressController =
        AnimationController(vsync: this, duration: _holdDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _onHoldCompleted();
            }
          });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _hapticTimer?.cancel();
    _hintOverlay?.remove();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    AppSnackBars.warning('Hold for 3 seconds to send SOS');
  }

  void _onLongPressStart(LongPressStartDetails _) {
    // Dismiss hint if visible
    _hintOverlay?.remove();
    _hintOverlay = null;

    _holdCompleted = false;
    setState(() => _isHolding = true);
    _progressController.forward(from: 0);

    // Vibrate at t=0, 1s, 2s
    HapticFeedback.heavyImpact();
    _hapticTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (t.tick <= 3) HapticFeedback.heavyImpact();
    });
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    if (_holdCompleted) {
      _holdCompleted = false;
      return;
    }
    _cancelHold();
  }

  void _onLongPressCancel() => _cancelHold();

  void _cancelHold() {
    _hapticTimer?.cancel();
    _progressController.reverse();
    AppSnackBars.warning('SOS cancelled');
    _holdCompleted = false;
    setState(() => _isHolding = false);
  }

  void _onHoldCompleted() {
    _hapticTimer?.cancel();
    HapticFeedback.heavyImpact();
    _holdCompleted = true;
    setState(() => _isHolding = false);
    widget.onActivated();
    _progressController.reset();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressCancel,
      child: AnimatedBuilder(
        animation: _progressController,
        builder: (context, child) {
          return SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Circular progress ring
                if (_isHolding || _progressController.value > 0)
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: _progressController.value,
                      strokeWidth: 3.5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: const Color(
                        0xFFF9606F,
                      ).withValues(alpha: 0.25),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFF9606F),
                      ),
                    ),
                  ),

                // FAB core
                AnimatedScale(
                  scale: _isHolding ? 0.88 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: child,
                ),
              ],
            ),
          );
        },
        child: _SOSCore(),
      ),
    );
  }
}

// ─── Core button appearance ──────────────────────────────────────────────────

class _SOSCore extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF9606F),
      shape: const CircleBorder(),
      elevation: 4,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Center(
          child: Text(
            'SOS',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
