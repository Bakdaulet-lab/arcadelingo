part of 'match_three_field.dart';

double _unit(double value) => value.clamp(0.0, 1.0).toDouble();

/// Delays each clearing piece until the beam has reached its cell.
double _clearProgress(double time, int index, int? origin) {
  if (origin == null) return time;
  final distance =
      (MatchThreeRun.row(index) - MatchThreeRun.row(origin)).abs() +
      (MatchThreeRun.column(index) - MatchThreeRun.column(origin)).abs();
  return _unit((time - distance * .060) / .69);
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.motion,
    required this.gems,
    required this.cells,
    required this.origin,
    required this.cross,
    required this.chain,
    required this.paper,
  }) : super(repaint: motion);

  final Animation<double> motion;
  final List<MatchGem?> gems;
  final Set<int> cells;
  final int? origin;
  final bool cross;
  final int chain;
  final bool paper;

  @override
  void paint(Canvas canvas, Size size) {
    final p = motion.value;
    if (p <= 0 || p >= 1 || cells.length < 3) return;
    final step = size.width / MatchThreeRun.size;
    final pen = Paint()..strokeCap = StrokeCap.round;
    Offset center(int index) => Offset(
      (MatchThreeRun.column(index) + .5) * step,
      (MatchThreeRun.row(index) + .5) * step,
    );
    if (origin case final source?) {
      final sourceCenter = center(source);
      final radius = size.width * Curves.easeOutCubic.transform(_unit(p / .68));
      final opacity = 1 - _unit((p - .50) / .5);
      final glow = paper ? const Color(0xffd9771c) : const Color(0xffffcf60);
      final core = paper ? const Color(0xfffff8cf) : const Color(0xfffff5c9);
      for (final axis in [const Offset(1, 0), if (cross) const Offset(0, 1)]) {
        final spread = axis * radius;
        canvas.drawLine(
          sourceCenter - spread,
          sourceCenter + spread,
          pen
            ..strokeWidth = step * (.22 - .09 * p)
            ..color = glow.withValues(alpha: opacity * .52),
        );
        canvas.drawLine(
          sourceCenter - spread,
          sourceCenter + spread,
          pen
            ..strokeWidth = step * .055
            ..color = core.withValues(alpha: opacity),
        );
      }
    }
    for (final index in cells) {
      final t = _clearProgress(p, index, origin);
      if (t <= .11 || t >= 1) continue;
      final flight = (t - .11) / .89;
      final from = center(index);
      final color = _jewels[gems[index] ?? MatchGem.charged]!;
      final bright = Color.lerp(color.middle, color.shine, paper ? .18 : .55)!;
      final fade = sin(pi * flight).clamp(0.0, 1.0).toDouble();
      if (origin == null) {
        canvas.drawCircle(
          from,
          step * (.17 + .31 * flight),
          pen
            ..style = PaintingStyle.stroke
            ..strokeWidth = step * .026
            ..color = bright.withValues(alpha: .64 * fade),
        );
        pen.style = PaintingStyle.fill;
      }
      final count = chain > 1 ? 5 : 4;
      for (var k = 0; k < count; k++) {
        final angle = index * 1.79 + k * 2 * pi / count;
        final dir = Offset(cos(angle), sin(angle));
        final head =
            from +
            dir * (step * (.18 + .42 * Curves.easeOutQuad.transform(flight)));
        canvas.drawLine(
          head - dir * (step * (.07 - .045 * flight)),
          head,
          pen
            ..strokeWidth = step * (.045 - .024 * flight)
            ..color = bright.withValues(alpha: fade),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.motion != motion ||
      old.cells != cells ||
      old.origin != origin ||
      old.cross != cross ||
      old.chain != chain ||
      old.paper != paper;
}
