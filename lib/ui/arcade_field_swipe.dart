import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Resolves a swipe on a game board using both axes of the same pointer.
/// Each callback receives the start of the segment and its displacement.
class ArcadeFieldSwipe extends StatefulWidget {
  const ArcadeFieldSwipe({
    required this.distance,
    required this.onSwipe,
    required this.child,
    this.continuous = false,
    super.key,
  });

  final double distance;
  final void Function(Offset origin, Offset delta)? onSwipe;
  final bool continuous;
  final Widget child;

  @override
  State<ArcadeFieldSwipe> createState() => _ArcadeFieldSwipeState();
}

class _ArcadeFieldSwipeState extends State<ArcadeFieldSwipe> {
  Offset? _origin;

  void _update(DragUpdateDetails details) {
    final origin = _origin;
    if (origin == null) return;
    final delta = details.localPosition - origin;
    if (math.max(delta.dx.abs(), delta.dy.abs()) < widget.distance) return;
    _origin = widget.continuous ? details.localPosition : null;
    widget.onSwipe?.call(origin, delta);
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    behavior: HitTestBehavior.opaque,
    excludeFromSemantics: true,
    gestures: {
      if (widget.onSwipe != null)
        PanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
              () => PanGestureRecognizer(debugOwner: this),
              (pan) {
                // Flutter's pan slop is twice the configured touch slop.
                pan.gestureSettings = DeviceGestureSettings(
                  touchSlop: widget.distance / 2,
                );
                pan.dragStartBehavior = DragStartBehavior.down;
                pan.onStart = (details) => _origin = details.localPosition;
                pan.onUpdate = _update;
                pan.onEnd = (_) => _origin = null;
                pan.onCancel = () => _origin = null;
              },
            ),
    },
    child: widget.child,
  );
}
