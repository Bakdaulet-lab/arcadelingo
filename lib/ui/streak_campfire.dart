import 'dart:async';

import 'package:arcadelingo/ui/campfire_painter.dart';
import 'package:arcadelingo/ui/streak_flame.dart';
import 'package:flutter/material.dart';

/// Короткая вспышка при продлении серии. Сохранённая серия при открытии
/// экрана сразу видна в своём обычном состоянии.
class StreakCampfire extends StatefulWidget {
  const StreakCampfire({
    required this.days,
    required this.tier,
    required this.mood,
    super.key,
    this.size = Size.zero,
    this.child,
  });

  final int days;
  final FlameTier tier;
  final FlameMood mood;
  final Size size;
  final Widget? child;

  @override
  State<StreakCampfire> createState() => _StreakCampfireState();
}

class _StreakCampfireState extends State<StreakCampfire>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _progress;
  bool _visible = false;
  bool _reduced = false;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
      value: 1,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _visible =
        TickerMode.of(context) && (ModalRoute.isCurrentOf(context) ?? true);
    _updateMotion();
  }

  @override
  void didUpdateWidget(StreakCampfire oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mood != FlameMood.lit) {
      _pending = false;
      _settle();
    } else if (widget.days > oldWidget.days) {
      _pending = true;
      _updateMotion();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _pending = false;
      _settle();
    }
  }

  void _updateMotion() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (_reduced ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed)) {
      _pending = false;
      _settle();
    } else if (!_visible) {
      // День могли засчитать, пока игровая страница закрывает главную.
      _settle();
    } else if (_pending) {
      _pending = false;
      unawaited(_progress.forward(from: 0));
    }
  }

  void _settle() {
    if (!_progress.isCompleted) _progress.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      builder: (context, child) {
        final t = _progress.value;
        final intensity =
            t <= .3
                ? Curves.easeOutCubic.transform(t / .3)
                : 1 - Curves.easeInOut.transform((t - .3) / .7);
        return CustomPaint(
          size: widget.size,
          painter: FlamePainter(
            tier: widget.tier,
            mood: widget.mood,
            scheme: scheme,
            intensity: intensity,
          ),
          child: child,
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progress.dispose();
    super.dispose();
  }
}
