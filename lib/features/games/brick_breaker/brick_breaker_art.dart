part of 'brick_breaker_field.dart';

class _BrickFieldArtwork extends StatelessWidget {
  const _BrickFieldArtwork(
    this.run,
    this.colors, {
    required this.paper,
    required this.effects,
  });

  final BrickBreakerRun run;
  final ColorScheme colors;
  final bool paper;
  final bool effects;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(
        child: CustomPaint(painter: _BackdropPainter(run, colors, paper)),
      ),
      CustomPaint(
        painter: _FieldPainter(run, colors, paper: paper, effects: effects),
      ),
    ],
  );
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.run, this.colors, this.paper)
    : brickCount = run.bricks.length,
      field = run.field;

  // The simulation mutates in place. Snapshot the wall revision so it only
  // repaints after a brick breaks or the next field opens.
  final BrickBreakerRun run;
  final int brickCount;
  final int field;
  final bool paper;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / BrickBreakerRun.width);
    const bounds = Rect.fromLTWH(
      0,
      0,
      BrickBreakerRun.width,
      BrickBreakerRun.height,
    );
    final paint =
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, -.72),
            radius: .88,
            colors: [colors.surfaceContainerHighest, colors.surface],
          ).createShader(bounds);
    canvas.drawRect(bounds, paint);
    paint
      ..shader = null
      ..color = colors.outline.withValues(alpha: .29);
    for (var x = 10.0; x < bounds.right; x += 14) {
      for (var y = 10.0; y < bounds.bottom; y += 14) {
        canvas.drawCircle(Offset(x, y), .65, paint);
      }
    }
    paint
      ..color = colors.outline.withValues(alpha: .25)
      ..strokeWidth = 1;
    for (final side in [5.0, bounds.right - 5]) {
      for (var y = 119.0; y < bounds.bottom - 36; y += 34) {
        canvas.drawLine(Offset(side, y), Offset(side, y + 5), paint);
      }
    }
    for (final brick in run.bricks) {
      _brick(canvas, paint, brick);
    }
  }

  void _brick(Canvas canvas, Paint paint, ArcadeBrick brick) {
    final box = brick.bounds;
    final fill = _brickFill(brick, colors, paper);
    _rounded(
      canvas,
      paint,
      box.shift(const Offset(0, 2)),
      Color.lerp(fill, colors.shadow, .48)!,
      3.5,
    );
    _rounded(canvas, paint, box, fill, 3.5);
    _rounded(
      canvas,
      paint,
      Rect.fromLTWH(box.left + 2, box.top + 1.2, box.width - 4, 1.5),
      Colors.white.withValues(alpha: brick.gold ? .74 : .40),
      1,
    );
    if (brick.gold) {
      final p = box.center;
      final diamond =
          Path()
            ..moveTo(p.dx, p.dy - 4)
            ..lineTo(p.dx + 5, p.dy)
            ..lineTo(p.dx, p.dy + 4)
            ..lineTo(p.dx - 5, p.dy)
            ..close();
      canvas.drawPath(diamond, paint..color = const Color(0xFF6C4419));
      canvas.drawCircle(p, 1.55, paint..color = const Color(0xFFFBE7B6));
      for (final sign in [-1, 1]) {
        canvas.drawLine(
          p + Offset(sign * 8.0, 0),
          p + Offset(sign * 12.0, 0),
          paint
            ..color = const Color(0xFFA77025)
            ..strokeWidth = 1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) =>
      oldDelegate.colors != colors ||
      oldDelegate.paper != paper ||
      oldDelegate.run != run ||
      oldDelegate.brickCount != brickCount ||
      oldDelegate.field != field;
}

class _FieldPainter extends CustomPainter {
  _FieldPainter(
    this.run,
    this.colors, {
    required this.paper,
    required this.effects,
  });
  final BrickBreakerRun run;
  final ColorScheme colors;
  final bool paper;
  final bool effects;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / BrickBreakerRun.width);
    final paint = Paint();
    if (effects) {
      for (final impact in run.impacts) {
        _shatter(canvas, paint, impact);
      }
    }
    if (run.phase == BrickPhase.bonus) {
      for (var i = 0; i < run.choices.length; i++) {
        final selected = i == run.catchLane;
        final x = run.laneCenter(i);
        _rounded(
          canvas,
          paint,
          Rect.fromCenter(
            center: Offset(x, BrickBreakerRun.paddleY + 18),
            width: selected ? 26 : 15,
            height: selected ? 3 : 2,
          ),
          selected ? colors.primary : colors.outline,
          2,
        );
      }
    }
    _paddle(canvas, paint);
    if (run.phase == BrickPhase.feedback) {
      _catch(canvas, paint);
    } else if (run.phase != BrickPhase.bonus) {
      for (final ball in run.balls) {
        _ball(canvas, paint, ball);
      }
    }
  }

  void _shatter(Canvas canvas, Paint paint, BrickImpact impact) {
    final brick = impact.brick;
    final t = run.impactProgress(impact).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(t);
    final fade = 1 - t;
    final center = brick.bounds.center;
    final tint = _brickFill(brick, colors, paper);
    if (brick.gold) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: 12 + 60 * eased,
          height: 7 + 36 * eased,
        ),
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * fade + .4
          ..color = tint.withValues(alpha: .67 * fade),
      );
      paint.style = PaintingStyle.fill;
    }
    final count = brick.gold ? 8 : 5;
    for (var i = 0; i < count; i++) {
      final angle = i * 2 * pi / count + brick.row * .32 + .24;
      final radius = (i.isEven ? 25.0 : 16.0) * eased;
      final dx = cos(angle);
      final point =
          center +
          Offset(
            dx * (5 + radius),
            sin(angle) * (2 + radius) - 7 * eased + 13 * t * t,
          );
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(angle + t * (i.isEven ? 2.7 : -2));
      final shard = Rect.fromCenter(
        center: Offset.zero,
        width: (i.isEven ? 7 : 4) * fade + 1,
        height: 2.3 * fade + .7,
      );
      _rounded(
        canvas,
        paint,
        shard,
        (i % 3 == 0 ? Color.lerp(tint, Colors.white, .42)! : tint).withValues(
          alpha: fade,
        ),
        .7,
      );
      canvas.restore();
    }
  }

  void _paddle(Canvas canvas, Paint paint) {
    const y = BrickBreakerRun.paddleY;
    const half = BrickBreakerRun.paddleHalfWidth;
    final body = Rect.fromLTWH(run.paddle - half, y, half * 2, 9);
    final rim = Color.lerp(colors.primary, colors.shadow, .40)!;
    _rounded(canvas, paint, body.shift(const Offset(0, 2.5)), rim, 5);
    _rounded(canvas, paint, body, colors.primary, 5);
    _rounded(
      canvas,
      paint,
      Rect.fromLTWH(body.left + 4, y + 1, body.width - 8, 1.8),
      Colors.white.withValues(alpha: .57),
      1,
    );
    _rounded(
      canvas,
      paint,
      Rect.fromCenter(
        center: Offset(run.paddle, y + 5.0),
        width: 14,
        height: 2,
      ),
      colors.onPrimary.withValues(alpha: .56),
      1,
    );
    for (final x in [body.left + 5, body.right - 5]) {
      canvas.drawCircle(Offset(x, y + 5), 1.25, paint..color = rim);
    }
    if (!effects) return;
    final t = run.paddleContactProgress;
    final point = run.paddleContact?.point;
    if (point == null || t == null || run.phase != BrickPhase.flying) return;
    final spread = Curves.easeOutCubic.transform(t);
    final oval = Rect.fromCenter(
      center: point,
      width: 9 + 39 * spread,
      height: 3 + 18 * spread,
    );
    canvas.drawArc(
      oval,
      pi,
      pi,
      false,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 - t
        ..color = colors.primary.withValues(alpha: (1 - t) * .86),
    );
    paint.style = PaintingStyle.fill;
  }

  void _ball(Canvas canvas, Paint paint, BrickBall ball) {
    final position = run.displayedBallPosition(ball);
    const radius = BrickBreakerRun.ballRadius;
    if (effects &&
        run.phase == BrickPhase.flying &&
        ball.velocity.distance > 0) {
      final direction = ball.velocity / ball.velocity.distance;
      for (var i = 3; i > 0; i--) {
        canvas.drawCircle(
          position - direction * (3.7 * i),
          radius * (1 - i * .20),
          paint..color = colors.primary.withValues(alpha: (4 - i) * .085),
        );
      }
    }
    canvas.drawCircle(
      position,
      radius + 1.8,
      paint..color = colors.primary.withValues(alpha: .25),
    );
    canvas.drawCircle(
      position,
      radius,
      paint..color = paper ? colors.primary : colors.onSurface,
    );
    canvas.drawCircle(
      position + const Offset(-1.1, -1.5),
      1.65,
      paint..color = paper ? const Color(0xFFFFDFBB) : Colors.white,
    );
  }

  void _catch(Canvas canvas, Paint paint) {
    final x = run.caughtX;
    if (x == null) return;
    final t = effects ? run.catchProgress : 0.0;
    if (t >= 1) return;
    final eased = Curves.easeOutCubic.transform(t);
    final fade = effects ? (1 - t * t) : 1.0;
    final good = run.caughtCorrect;
    final ink = good ? colors.primary : colors.error;
    final anchor = Offset(x, BrickBreakerRun.paddleY - 4);
    if (effects) {
      final radius = 7 + 25 * eased;
      canvas.drawArc(
        Rect.fromCenter(
          center: anchor,
          width: 2 * radius,
          height: radius * 1.2,
        ),
        pi,
        pi,
        false,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7
          ..color = ink.withValues(alpha: .57 * fade),
      );
      paint.style = PaintingStyle.fill;
    }
    if (good) {
      // The three rising beads preview the three balls on the next serve.
      for (var i = -1; i <= 1; i++) {
        final rise = i == 0 ? 22.0 : 14.0;
        final position =
            anchor +
            Offset(i * (8 + 13 * eased), -10 - rise * eased - (i == 0 ? 5 : 0));
        canvas.drawCircle(
          position,
          4.2,
          paint..color = ink.withValues(alpha: fade),
        );
        canvas.drawCircle(
          position + const Offset(-.8, -1.0),
          1.4,
          paint..color = colors.surface.withValues(alpha: fade),
        );
      }
    } else {
      final mark = anchor + Offset(0, -10 - 7 * eased);
      paint
        ..color = ink.withValues(alpha: fade)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        mark + const Offset(-4, -4),
        mark + const Offset(4, 4),
        paint,
      );
      canvas.drawLine(
        mark + const Offset(-4, 4),
        mark + const Offset(4, -4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_FieldPainter oldDelegate) => true;
}

const _warmBricks = [
  Color(0xFF8E6C91),
  Color(0xFFB57F97),
  Color(0xFF62967C),
  Color(0xFFCC8B70),
  Color(0xFF789D94),
];
const _nightBricks = [
  Color(0xFF796195),
  Color(0xFFA889D1),
  Color(0xFF65CFAC),
  Color(0xFFCB8B9C),
  Color(0xFF9EBFCA),
];

Color _brickFill(ArcadeBrick brick, ColorScheme colors, bool paper) =>
    brick.gold
        ? (paper ? const Color(0xFFE8AF56) : colors.tertiary)
        : (paper ? _warmBricks : _nightBricks)[brick.row];

void _rounded(
  Canvas canvas,
  Paint paint,
  Rect rect,
  Color color,
  double radius,
) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(radius)),
    paint..color = color,
  );
}
