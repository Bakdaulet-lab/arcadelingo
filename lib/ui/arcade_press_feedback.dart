import 'package:flutter/material.dart';

/// Animates the press state of an existing Material control while leaving
/// gesture recognition, keyboard activation and semantics with that control.
class ArcadePressFeedback extends StatefulWidget {
  const ArcadePressFeedback({
    required this.builder,
    this.enabled = true,
    super.key,
  });

  final Widget Function(WidgetStatesController states) builder;
  final bool enabled;

  @override
  State<ArcadePressFeedback> createState() => _ArcadePressFeedbackState();
}

class _ArcadePressFeedbackState extends State<ArcadePressFeedback>
    with SingleTickerProviderStateMixin {
  final _states = WidgetStatesController();
  late final _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 150),
  )..addStatusListener(_onStatus);
  late final _curve = CurvedAnimation(
    parent: _press,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final _scale = Tween<double>(begin: 1, end: .98).animate(_curve);
  bool _held = false;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _states.addListener(_onControlState);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) _press.reset();
  }

  void _onControlState() {
    final pressed = _states.value.contains(WidgetState.pressed);
    if (_held == pressed) return;
    _held = pressed;
    if (_reducedMotion || !widget.enabled) return;
    if (pressed) {
      _press.forward();
    } else if (_press.isCompleted) {
      _press.reverse();
    }
  }

  @override
  void didUpdateWidget(ArcadePressFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) _press.reset();
  }

  void _onStatus(AnimationStatus status) {
    // A quick tap can press and release between frames. Complete its small
    // dip before returning, without delaying the control's action.
    if (status == AnimationStatus.completed && !_held) _press.reverse();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.builder(_states));

  @override
  void dispose() {
    _states.dispose();
    _curve.dispose();
    _press.dispose();
    super.dispose();
  }
}
