import 'dart:math';

import 'package:arcadelingo/ui/app_strings.dart';
import 'package:flutter/material.dart';

import 'match_three_run.dart';

abstract final class MatchThreeKeys {
  static const field = Key('match_three.field');
  static const word = Key('match_three.word');
  static const summary = Key('match_three.summary');
  static Key cell(int index) => ValueKey('match_three.cell.$index');
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

class _MatchThreeFieldState extends State<MatchThreeField> {
  Offset? _origin;
  Offset _latest = Offset.zero;

  void _finishSwipe(double step) {
    final origin = _origin;
    _origin = null;
    if (origin == null) return;
    final delta = _latest - origin;
    if (max(delta.dx.abs(), delta.dy.abs()) < step * .27) return;
    final x = (origin.dx / step).floor();
    final y = (origin.dy / step).floor();
    if (x < 0 || x >= MatchThreeRun.size || y < 0 || y >= MatchThreeRun.size) {
      return;
    }
    final index = y * MatchThreeRun.size + x;
    final direction =
        delta.dx.abs() > delta.dy.abs()
            ? delta.dx.sign.toInt()
            : delta.dy.sign.toInt() * MatchThreeRun.size;
    if (MatchThreeRun.adjacent(index, index + direction)) {
      widget.onSwap(index, index + direction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ready = widget.run.phase == MatchThreePhase.ready;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final step = constraints.maxWidth / MatchThreeRun.size;
              return ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown:
                      ready
                          ? (details) {
                            _origin = details.localPosition;
                            _latest = details.localPosition;
                          }
                          : null,
                  onPanUpdate:
                      ready
                          ? (details) => _latest = details.localPosition
                          : null,
                  onPanEnd: ready ? (_) => _finishSwipe(step) : null,
                  onPanCancel: ready ? () => _origin = null : null,
                  child: RepaintBoundary(
                    child: Stack(
                      children: List.generate(
                        widget.run.cells.length,
                        (index) => _tile(context, index, step, colors, ready),
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
    int index,
    double step,
    ColorScheme colors,
    bool ready,
  ) {
    final run = widget.run;
    final gem = run.cells[index];
    final row = MatchThreeRun.row(index);
    final column = MatchThreeRun.column(index);
    final guide = run.showGuide;
    final isSelected = widget.selected == index;
    final isStart = guide && index == MatchThreeRun.guideFrom;
    final isTarget = guide && index == MatchThreeRun.guideTo;
    final charged = gem == MatchGem.charged;
    final offset = run.travel[index];
    final effects = !MediaQuery.disableAnimationsOf(context);
    final canMove =
        effects &&
        (run.phase == MatchThreePhase.swapping ||
            run.phase == MatchThreePhase.reverting ||
            run.phase == MatchThreePhase.falling);
    final fade =
        effects &&
        run.phase == MatchThreePhase.clearing &&
        run.clearing.contains(index);
    final tint =
        isSelected || isStart || isTarget
            ? colors.primary
            : charged
            ? colors.tertiary
            : Colors.transparent;

    return Positioned(
      top: row * step,
      left: column * step,
      width: step,
      height: step,
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: Semantics(
          key: MatchThreeKeys.cell(index),
          selected: isSelected,
          label: context.strings.matchGem(
            gem?.index ?? -1,
            row + 1,
            column + 1,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: ready ? () => widget.onTap(index) : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(
                  colors.surface,
                  colors.surfaceContainerHighest,
                  (row + column).isEven ? .48 : .73,
                ),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: tint,
                  width: isSelected || isStart ? 1.6 : 1,
                ),
              ),
              child: Stack(
                children: [
                  if (gem != null)
                    Align(
                      child: FractionallySizedBox(
                        widthFactor: .72,
                        heightFactor: .72,
                        child: _gem(
                          gem,
                          canMove && offset != null
                              ? Offset(
                                offset.columns * step,
                                offset.rows * step,
                              )
                              : Offset.zero,
                          fade,
                        ),
                      ),
                    ),
                  if (isStart)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Icon(
                        Icons.south_rounded,
                        color: colors.primary,
                        size: 11,
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

  Widget _gem(MatchGem gem, Offset distance, bool fade) {
    final piece = CustomPaint(painter: _GemPainter(gem));
    if (!fade && distance == Offset.zero) return piece;
    return AnimatedBuilder(
      animation: widget.motion,
      child: piece,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(widget.motion.value);
        if (fade) {
          return Opacity(
            opacity: 1 - progress,
            child: Transform.scale(scale: 1 - .88 * progress, child: child),
          );
        }
        return Transform.translate(
          offset: distance * (1 - progress),
          child: child,
        );
      },
    );
  }
}

class _GemPainter extends CustomPainter {
  const _GemPainter(this.gem);

  final MatchGem gem;

  @override
  void paint(Canvas canvas, Size size) {
    final (light, body, dark) = switch (gem) {
      MatchGem.aqua => (
        const Color(0xffa5fffa),
        const Color(0xff31d7eb),
        const Color(0xff11748e),
      ),
      MatchGem.rose => (
        const Color(0xffffbbdf),
        const Color(0xfff477b9),
        const Color(0xffa63774),
      ),
      MatchGem.amber => (
        const Color(0xffffdea0),
        const Color(0xfff7af48),
        const Color(0xffb96526),
      ),
      MatchGem.plum => (
        const Color(0xffe0c3ff),
        const Color(0xffaa81f3),
        const Color(0xff684cb5),
      ),
      MatchGem.mint => (
        const Color(0xffaeffcf),
        const Color(0xff53dfa4),
        const Color(0xff207f5f),
      ),
      MatchGem.sapphire => (
        const Color(0xffa6bbff),
        const Color(0xff658ef8),
        const Color(0xff374cbd),
      ),
      MatchGem.charged => (
        const Color(0xfffff7ca),
        const Color(0xffffc65b),
        const Color(0xffe47c27),
      ),
    };
    final rect = Offset.zero & size;
    final path = switch (gem) {
      MatchGem.aqua => _polygon(size, const [
        Offset(.5, 0),
        Offset(1, .5),
        Offset(.5, 1),
        Offset(0, .5),
      ]),
      MatchGem.rose => Path()..addOval(rect.deflate(1)),
      MatchGem.amber => _polygon(size, const [
        Offset(.25, .05),
        Offset(.75, .05),
        Offset(1, .5),
        Offset(.75, .95),
        Offset(.25, .95),
        Offset(0, .5),
      ]),
      MatchGem.plum => _polygon(size, const [
        Offset(.44, 0),
        Offset(.82, .14),
        Offset(1, .48),
        Offset(.83, .8),
        Offset(.46, 1),
        Offset(.12, .76),
        Offset(0, .4),
        Offset(.14, .15),
      ]),
      MatchGem.mint => _polygon(size, const [
        Offset(.2, .05),
        Offset(.8, .05),
        Offset(.95, .2),
        Offset(.95, .8),
        Offset(.8, .95),
        Offset(.2, .95),
        Offset(.05, .8),
        Offset(.05, .2),
      ]),
      MatchGem.sapphire => _polygon(size, const [
        Offset(.5, 0),
        Offset(.97, .71),
        Offset(.77, .96),
        Offset(.23, .96),
        Offset(.03, .71),
      ]),
      MatchGem.charged => _polygon(size, [
        for (var i = 0; i < 16; i++)
          const Offset(.5, .5) +
              Offset(cos(i * pi / 8 - pi / 2), sin(i * pi / 8 - pi / 2)) *
                  (i.isEven ? .5 : .28),
      ]),
    };
    canvas.drawShadow(path, const Color(0x850d0914), 2, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, body, dark],
          stops: const [0, .52, 1],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      _polygon(size, const [
        Offset(.02, .02),
        Offset(.79, .12),
        Offset(.6, .36),
        Offset(.27, .67),
        Offset(0, .87),
      ]),
      Paint()..color = const Color(0x50ffffff),
    );
    canvas.drawPath(
      _polygon(size, const [
        Offset(1, .05),
        Offset(.98, 1),
        Offset(.21, 1),
        Offset(.57, .68),
        Offset(.65, .37),
      ]),
      Paint()..color = const Color(0x30301b52),
    );
    canvas.restore();
  }

  Path _polygon(Size size, List<Offset> normalized) {
    final points = [
      for (final p in normalized) Offset(p.dx * size.width, p.dy * size.height),
    ];
    return Path()..addPolygon(points, true);
  }

  @override
  bool shouldRepaint(covariant _GemPainter oldDelegate) =>
      oldDelegate.gem != gem;
}
