import 'package:flutter/material.dart';

import 'brick_breaker_run.dart';

/// A touch on the paddle keeps the grab point. Elsewhere, one tap aims directly.
class BrickPaddleInput extends StatefulWidget {
  const BrickPaddleInput({
    required this.run,
    required this.scale,
    required this.onMove,
    required this.child,
    this.tappedLane,
    this.fieldTop = 0,
    super.key,
  });

  final BrickBreakerRun run;
  final double scale;
  final ValueChanged<double> onMove;
  final double? Function(Offset localPosition)? tappedLane;
  final double fieldTop;
  final Widget child;

  @override
  State<BrickPaddleInput> createState() => _BrickPaddleInputState();
}

class _BrickPaddleInputState extends State<BrickPaddleInput> {
  int? _pointer;
  double _grabOffset = 0;

  void _down(PointerDownEvent event) {
    if (_pointer != null || event.buttons != 1) return;
    _pointer = event.pointer;
    final point =
        (event.localPosition - Offset(0, widget.fieldTop)) / widget.scale;
    final lane = widget.tappedLane?.call(event.localPosition);
    final onPaddle =
        (point.dy - BrickBreakerRun.paddleY).abs() <= 22 &&
        (point.dx - widget.run.paddle).abs() <= BrickBreakerRun.paddleHalfWidth;
    final target = lane ?? (onPaddle ? widget.run.paddle : point.dx);
    _grabOffset = point.dx - target;
    widget.onMove(target);
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer == _pointer) {
      widget.onMove(event.localPosition.dx / widget.scale - _grabOffset);
    }
  }

  void _release(int pointer) {
    if (_pointer == pointer) _pointer = null;
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: (event) => _release(event.pointer),
    onPointerCancel: (event) => _release(event.pointer),
    child: widget.child,
  );
}
