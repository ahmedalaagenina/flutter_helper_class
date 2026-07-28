import 'dart:async';

import 'package:flutter/material.dart';

/// Types, holds, and deletes each phrase in a loop, with a blinking caret.
class TypewriterText extends StatefulWidget {
  final List<String> phrases;
  final TextStyle? style;

  const TypewriterText({super.key, required this.phrases, this.style});

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  static const _typeSpeed = Duration(milliseconds: 65);
  static const _deleteSpeed = Duration(milliseconds: 32);
  static const _holdTime = Duration(milliseconds: 1600);

  Timer? _timer;
  int _phraseIndex = 0;
  int _charCount = 0;
  bool _deleting = false;
  bool _caretOn = true;
  Timer? _caretTimer;

  @override
  void initState() {
    super.initState();
    _tick();
    _caretTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _caretOn = !_caretOn);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _caretTimer?.cancel();
    super.dispose();
  }

  void _tick() {
    final phrase = widget.phrases[_phraseIndex];
    Duration next;

    if (!_deleting) {
      if (_charCount < phrase.length) {
        _charCount++;
        next = _typeSpeed;
      } else {
        _deleting = true;
        next = _holdTime;
      }
    } else {
      if (_charCount > 0) {
        _charCount--;
        next = _deleteSpeed;
      } else {
        _deleting = false;
        _phraseIndex = (_phraseIndex + 1) % widget.phrases.length;
        next = _typeSpeed;
      }
    }

    if (mounted) setState(() {});
    _timer = Timer(next, _tick);
  }

  @override
  Widget build(BuildContext context) {
    final phrase = widget.phrases[_phraseIndex];
    final visible = phrase.substring(0, _charCount);
    return Text.rich(
      TextSpan(
        text: visible,
        children: [
          TextSpan(
            text: '|',
            style: TextStyle(
              color: _caretOn
                  ? widget.style?.color
                  : Colors.transparent,
            ),
          ),
        ],
      ),
      style: widget.style,
    );
  }
}
