import 'dart:math';

import 'package:flutter/material.dart';

import 'brick_breaker_run.dart';

/// Cards in separate lanes can share a row. Wide translations borrow space
/// from adjacent lanes and get their own row, while the catch points stay put.
class BrickAnswerLayout {
  BrickAnswerLayout({
    required BrickBreakerRun run,
    required this.width,
    required this.style,
    required TextScaler scaler,
    required TextDirection direction,
    required Locale locale,
  }) {
    if (run.phase != BrickPhase.bonus && run.phase != BrickPhase.feedback) {
      return;
    }
    final scale = width / BrickBreakerRun.width;
    final maxWidth = max(1.0, width - 2 * _inset);
    final laneWidth = min(maxWidth, max(1.0, run.laneSpacing * scale - _gap));
    final bands = <List<Rect>>[];
    final heights = <double>[];
    final rows = <int>[];
    final painter = TextPainter(
      textDirection: direction,
      textScaler: scaler,
      locale: locale,
      textAlign: TextAlign.center,
    );
    try {
      for (final (index, choice) in run.choices.indexed) {
        painter.text = TextSpan(text: choice, style: style);
        painter.layout();
        final natural =
            (painter.maxIntrinsicWidth + _padX * 2 + 1).ceilToDouble();
        final wholeWordWidth =
            (painter.minIntrinsicWidth + _padX * 2 + 1).ceilToDouble();
        final center = run.laneCenter(index) * scale;
        final centeredWidth = 2 * (min(center, width - center) - _inset);
        // A player can steer toward the actual word. Borrow extra width only
        // when a whole word needs it; allow phrases to wrap at word breaks.
        final aimedWidth =
            centeredWidth + BrickBreakerRun.paddleHalfWidth * scale;
        final narrow = max(1.0, laneWidth - 2 * _padX);
        final canWrap = painter.minIntrinsicWidth <= narrow;
        painter.layout(maxWidth: narrow);
        final short = canWrap && painter.computeLineMetrics().length <= 2;
        final cardWidth = min(
          short ? laneWidth : min(maxWidth, max(aimedWidth, wholeWordWidth)),
          max(40.0, natural),
        );
        painter.layout(maxWidth: max(1.0, cardWidth - 2 * _padX));
        final cardHeight = painter.height.ceilToDouble() + 2 * _padY;
        // A single long word can use the side gutter too. Keep its printed
        // center as close as possible to the physical lane under it.
        final edge = cardWidth > centeredWidth ? 2.0 : _inset;
        final left = (center - cardWidth / 2).clamp(
          edge,
          max(edge, width - edge - cardWidth),
        );
        final card = Rect.fromLTWH(left.toDouble(), 0, cardWidth, cardHeight);
        var row = bands.indexWhere(
          (band) => band.every(
            (other) =>
                card.right + _gap <= other.left ||
                card.left >= other.right + _gap,
          ),
        );
        if (row < 0) {
          row = bands.length;
          bands.add([]);
          heights.add(0);
        }
        bands[row].add(card);
        heights[row] = max(heights[row], cardHeight);
        rows.add(row);
        cards.add(card);
        centers.add(center);
      }
    } finally {
      painter.dispose();
    }
    // Stack from left to right with short, disjoint labels on the same shelf.
    final bases = <double>[];
    for (final height in heights) {
      rackHeight += height;
      bases.add(rackHeight);
      rackHeight += _gap;
    }
    for (var i = 0; i < cards.length; i++) {
      cards[i] = cards[i].shift(Offset(0, bases[rows[i]] - cards[i].height));
    }
    rackHeight += 5;
    // Reserve some travel even for several lines at accessibility text sizes.
    extraHeight = max(
      0,
      rackHeight + _inset + 96 * scale - BrickBreakerRun.paddleY * scale,
    );
  }

  static const _inset = 6.0;
  static const _gap = 5.0;
  static const _padX = 6.0;
  static const _padY = 5.0;
  final double width;
  final TextStyle style;
  final cards = <Rect>[];
  final centers = <double>[];
  double rackHeight = 0;
  double extraHeight = 0;

  double top(BrickBreakerRun run) {
    final scale = width / BrickBreakerRun.width;
    final start = max(_inset, BrickBreakerRun.dropStart * scale - rackHeight);
    final end = BrickBreakerRun.paddleY * scale + extraHeight - rackHeight;
    final progress =
        (run.dropY - BrickBreakerRun.dropStart) /
        (BrickBreakerRun.paddleY - BrickBreakerRun.dropStart);
    return start + (end - start) * progress;
  }

  double? touchedLane(Offset point, BrickBreakerRun run) {
    final local = point - Offset(0, top(run));
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].contains(local)) return run.laneCenter(i);
    }
    return null;
  }
}

class BrickBreakerAnswers extends StatelessWidget {
  const BrickBreakerAnswers({
    required this.choices,
    required this.selected,
    required this.layout,
    super.key,
  });

  final List<String> choices;
  final int? selected;
  final BrickAnswerLayout layout;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final paper = Theme.of(context).brightness == Brightness.light;
    final tints =
        paper
            ? const [Color(0xff496e63), Color(0xff985223), Color(0xff755081)]
            : const [Color(0xff83e4c6), Color(0xffffca7c), Color(0xffd6b4f6)];
    return CustomPaint(
      painter: _CatchPoints(layout, tints, selected),
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final (i, bounds) in layout.cards.indexed)
            Positioned.fromRect(
              rect: bounds,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    tints[i].withValues(alpha: selected == i ? .16 : .06),
                    colors.surface,
                  ),
                  border: Border.all(
                    color: tints[i].withValues(alpha: selected == i ? 1 : .75),
                    width: selected == i ? 1.8 : 1,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BrickAnswerLayout._padX,
                  ),
                  child: Center(
                    child: Text(
                      choices[i],
                      textAlign: TextAlign.center,
                      style: layout.style.copyWith(color: colors.onSurface),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CatchPoints extends CustomPainter {
  const _CatchPoints(this.layout, this.tints, this.selected);
  final BrickAnswerLayout layout;
  final List<Color> tints;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < layout.cards.length; i++) {
      final x = layout.centers[i];
      final start = Offset(x, layout.cards[i].bottom + 1.5);
      final end = Offset(x, size.height - 3.5);
      final tint = tints[i];
      paint
        ..strokeWidth = selected == i ? 2 : 1.2
        ..color = tint.withValues(alpha: selected == i ? .95 : .65);
      canvas.drawLine(start, end, paint);
      paint.color = tint;
      _marker(canvas, paint, start, i);
      _marker(canvas, paint, end, i);
    }
  }

  // The same shape at both ends identifies the lane without relying on color.
  void _marker(Canvas canvas, Paint paint, Offset p, int lane) {
    switch (lane) {
      case 0:
        canvas.drawCircle(p, 3, paint);
      case 1:
        canvas.drawPath(
          Path()
            ..moveTo(p.dx, p.dy - 3.5)
            ..lineTo(p.dx + 3.5, p.dy)
            ..lineTo(p.dx, p.dy + 3.5)
            ..lineTo(p.dx - 3.5, p.dy)
            ..close(),
          paint,
        );
      default:
        canvas.drawPath(
          Path()
            ..moveTo(p.dx - 4, p.dy - 2.5)
            ..lineTo(p.dx + 4, p.dy - 2.5)
            ..lineTo(p.dx, p.dy + 3.5)
            ..close(),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_CatchPoints oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.tints != tints ||
      oldDelegate.selected != selected;
}
