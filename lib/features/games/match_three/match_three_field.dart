import 'dart:math';

import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_field_swipe.dart';
import 'package:flutter/material.dart';

import 'match_three_run.dart';

part 'match_three_effects.dart';
part 'match_three_gems.dart';

abstract final class MatchThreeKeys {
  static const field = Key('match_three.field');
  static const word = Key('match_three.word');
  static const summary = Key('match_three.summary');
  static Key cell(int index) => ValueKey('match_three.cell.$index');
  static Key piece(int index) => ValueKey('match_three.piece.$index');
}

class MatchThreeField extends StatefulWidget {
  const MatchThreeField({
    required this.run,
    required this.motion,
    required this.selected,
    required this.onTap,
    required this.onSwap,
    super.key,
  });

  final MatchThreeRun run;
  final Animation<double> motion;
  final int? selected;
  final ValueChanged<int> onTap;
  final void Function(int from, int to) onSwap;

  @override
  State<MatchThreeField> createState() => _MatchThreeFieldState();
}

class _MatchThreeFieldState extends State<MatchThreeField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drag;
  int? _pointer;
  Offset _origin = Offset.zero;
  Offset _last = Offset.zero;
  int? _from;
  int? _to;
  double _handoff = 0;
  bool _committed = false;

  bool get _ready => widget.run.phase == MatchThreePhase.ready;

  @override
  void initState() {
    super.initState();
    _drag = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MatchThreeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.run.phase != MatchThreePhase.swapping && !_ready) {
      _pointer = null;
      _drag.value = 0;
      _from = null;
      _to = null;
      _handoff = 0;
    }
  }

  int? _cell(Offset position, double step) {
    final x = (position.dx / step).floor(), y = (position.dy / step).floor();
    if (x < 0 || x >= MatchThreeRun.size || y < 0 || y >= MatchThreeRun.size) {
      return null;
    }
    return y * MatchThreeRun.size + x;
  }

  int? _neighbor(int from, Offset delta) {
    if (delta == Offset.zero) return null;
    final direction =
        delta.dx.abs() > delta.dy.abs()
            ? delta.dx.sign.toInt()
            : delta.dy.sign.toInt() * MatchThreeRun.size;
    final target = from + direction;
    return MatchThreeRun.adjacent(from, target) ? target : null;
  }

  void _down(PointerDownEvent e, double step) {
    if (!_ready || _pointer != null || e.buttons != 1) return;
    _pointer = e.pointer;
    _origin = _last = e.localPosition;
    _committed = false;
    _handoff = 0;
    _drag.value = 0;
    _from = _cell(_origin, step);
    _to = null;
  }

  void _move(PointerMoveEvent e, double step) {
    if (!_ready || _committed || e.pointer != _pointer || _from == null) return;
    _last = e.localPosition;
    final delta = _last - _origin;
    final target = _neighbor(_from!, delta);
    if (_to != target) setState(() => _to = target);
    _drag.value = target == null ? 0 : _fraction(delta, step);
  }

  double _fraction(Offset delta, double step) =>
      (max(delta.dx.abs(), delta.dy.abs()) / step).clamp(0.0, .60).toDouble();

  void _release(int pointer) {
    if (_pointer != pointer) return;
    _pointer = null;
    if (!_committed && _drag.value > 0) {
      _drag.animateBack(
        0,
        duration: const Duration(milliseconds: 105),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _swipe(Offset from, Offset delta, double step) {
    if (!_ready || _committed || _pointer == null || _from == null) return;
    // Only the finger that started this segment can exchange its two gems.
    if ((from - _origin).distanceSquared > 4) return;
    final primary = _last - _origin;
    if (max(primary.dx.abs(), primary.dy.abs()) < step * .22) return;
    final target = _neighbor(_from!, primary);
    if (target == null) return;
    _committed = true;
    _to = target;
    _handoff = _fraction(primary, step);
    widget.onSwap(_from!, target);
    if (_ready) {
      // Equal neighbours cannot exchange. Ease the preview back into its slot.
      _committed = false;
      _handoff = 0;
      _drag.animateBack(
        0,
        duration: const Duration(milliseconds: 105),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final paper = colors.brightness == Brightness.light;
    final effects = !MediaQuery.disableAnimationsOf(context);
    final run = widget.run;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              paper
                  ? const [
                    Color(0xffddc6a4),
                    Color(0xfff1e1c4),
                    Color(0xffbd9979),
                  ]
                  : const [
                    Color(0xff55516b),
                    Color(0xff282436),
                    Color(0xff423752),
                  ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: paper ? const Color(0xffc9ac87) : const Color(0xff554760),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final step = constraints.maxWidth / MatchThreeRun.size;
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color:
                      paper ? const Color(0xffcdb693) : const Color(0xff201e30),
                  child: Listener(
                    onPointerDown: (e) => _down(e, step),
                    onPointerMove: (e) => _move(e, step),
                    onPointerUp: (e) => _release(e.pointer),
                    onPointerCancel: (e) => _release(e.pointer),
                    child: ArcadeFieldSwipe(
                      distance: step * .22,
                      onSwipe:
                          _ready
                              ? (from, delta) => _swipe(from, delta, step)
                              : null,
                      child: RepaintBoundary(
                        child: Stack(
                          children: [
                            for (var i = 0; i < run.cells.length; i++)
                              _tile(context, i, step, colors, paper),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Stack(
                                  children: [
                                    for (final (index, gem)
                                        in run.cells.indexed)
                                      if (gem != null)
                                        _sprite(
                                          index,
                                          gem,
                                          step,
                                          paper,
                                          effects,
                                        ),
                                    if (effects &&
                                        run.phase == MatchThreePhase.clearing)
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _BurstPainter(
                                            motion: widget.motion,
                                            gems: run.cells,
                                            cells: run.clearing,
                                            origin: run.blastOrigin,
                                            cross:
                                                run.chargeKind ==
                                                MatchChargeKind.cross,
                                            chain: run.cascadeDepth,
                                            paper: paper,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    int i,
    double step,
    ColorScheme colors,
    bool paper,
  ) {
    final run = widget.run;
    final gem = run.cells[i];
    final row = MatchThreeRun.row(i), column = MatchThreeRun.column(i);
    final selected = widget.selected == i;
    final start = run.showGuide && i == MatchThreeRun.guideFrom;
    final end = run.showGuide && i == MatchThreeRun.guideTo;
    final charged = gem == MatchGem.charged;
    final accent =
        selected || start || end
            ? colors.primary
            : charged
            ? colors.tertiary
            : null;
    final even = (row + column).isEven;
    final base =
        paper
            ? (even ? const Color(0xfff5e9d2) : const Color(0xffedddc1))
            : (even ? const Color(0xff302c42) : const Color(0xff292636));
    return Positioned(
      left: column * step,
      top: row * step,
      width: step,
      height: step,
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Semantics(
          key: MatchThreeKeys.cell(i),
          selected: selected,
          label: context.strings.matchGem(
            gem?.index ?? -1,
            row + 1,
            column + 1,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _ready ? () => widget.onTap(i) : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color:
                    accent == null
                        ? base
                        : Color.lerp(base, accent, selected ? .22 : .12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      accent?.withValues(alpha: start || selected ? 1 : .66) ??
                      (paper
                          ? const Color(0xffdcc7a7)
                          : const Color(0xff3c364c)),
                  width: selected || start ? 1.8 : 1,
                ),
              ),
              child:
                  start
                      ? Align(
                        alignment: Alignment.bottomRight,
                        child: Icon(
                          Icons.south_rounded,
                          color: colors.primary,
                          size: 12,
                        ),
                      )
                      : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sprite(
    int index,
    MatchGem gem,
    double step,
    bool paper,
    bool effects,
  ) {
    final run = widget.run, phase = run.phase;
    final drawing = RepaintBoundary(
      child: CustomPaint(
        key: MatchThreeKeys.piece(index),
        painter: _GemPainter(
          gem,
          paper: paper,
          cross:
              gem == MatchGem.charged &&
              run.chargeKind == MatchChargeKind.cross,
        ),
      ),
    );
    final side = step * .76, inset = (step - side) / 2;
    final preview =
        effects && _ready && _to != null && (index == _from || index == _to);
    final travel = effects ? run.travel[index] : null;
    final clearing =
        effects &&
        phase == MatchThreePhase.clearing &&
        run.clearing.contains(index);
    Widget art = drawing;
    if (preview) {
      final other = index == _from ? _to! : _from!;
      final delta = Offset(
        (MatchThreeRun.column(other) - MatchThreeRun.column(index)) * step,
        (MatchThreeRun.row(other) - MatchThreeRun.row(index)) * step,
      );
      art = AnimatedBuilder(
        animation: _drag,
        child: drawing,
        builder:
            (context, child) =>
                Transform.translate(offset: delta * _drag.value, child: child),
      );
    } else if (clearing || travel != null) {
      art = AnimatedBuilder(
        animation: widget.motion,
        child: drawing,
        builder: (context, child) {
          final t = widget.motion.value;
          if (clearing) {
            final p = _clearProgress(t, index, run.blastOrigin);
            final size =
                p < .24
                    ? 1 + .12 * Curves.easeOut.transform(p / .24)
                    : 1.12 *
                        (1 -
                            Curves.easeInCubic.transform(
                              _unit((p - .24) / .76),
                            ));
            return Transform.scale(scale: size, child: child);
          }
          final delta = Offset(travel!.columns * step, travel.rows * step);
          if (phase == MatchThreePhase.falling) {
            final delay = (MatchThreeRun.column(index) % 3) * .022;
            final p = _unit((t - delay) / (1 - delay));
            final drop = Curves.easeInQuad.transform(_unit(p / .76));
            final landing = _unit((p - .76) / .24);
            final recoil = sin(landing * pi);
            return Transform.translate(
              offset: delta * (1 - drop) - Offset(0, step * .039 * recoil),
              child: Transform.scale(
                scaleX: 1 + .075 * recoil,
                scaleY: 1 - .085 * recoil,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            );
          }
          final remaining =
              phase == MatchThreePhase.swapping ? 1 - _handoff : 1.0;
          final curve =
              phase == MatchThreePhase.reverting
                  ? Curves.easeOutCubic
                  : _handoff > 0
                  ? Curves.easeOutQuad
                  : Curves.easeInOutCubic;
          return Transform.translate(
            offset: delta * (remaining * (1 - curve.transform(t))),
            child: child,
          );
        },
      );
    }
    return Positioned(
      left: MatchThreeRun.column(index) * step + inset,
      top: MatchThreeRun.row(index) * step + inset,
      width: side,
      height: side,
      child: art,
    );
  }
}
