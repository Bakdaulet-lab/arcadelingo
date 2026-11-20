import 'dart:math';

import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

import 'brick_breaker_run.dart';

class BrickBreakerField extends StatelessWidget {
  const BrickBreakerField({required this.run, required this.onMove, super.key});

  final BrickBreakerRun run;
  final ValueChanged<double> onMove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AspectRatio(
      aspectRatio: BrickBreakerRun.width / BrickBreakerRun.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / BrickBreakerRun.width;
          final laneWidth = run.laneSpacing * scale;
          final catchLane = run.catchLane;
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => onMove(e.localPosition.dx / scale),
            onPointerMove: (e) => onMove(e.localPosition.dx / scale),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _FieldPainter(
                      run,
                      colors,
                      paper: theme.brightness == Brightness.light,
                      effects: !MediaQuery.disableAnimationsOf(context),
                    ),
                  ),
                  if (run.phase == BrickPhase.bonus)
                    for (final (index, choice) in run.choices.indexed)
                      Positioned(
                        left: run.laneCenter(index) * scale - laneWidth / 2 + 4,
                        width: laneWidth - 8,
                        top: (run.dropY * scale - 66).clamp(0, double.infinity),
                        height: 66,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    index == catchLane
                                        ? colors.primary
                                        : colors.tertiary,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.tertiary.withValues(alpha: .25),
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 8,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: (laneWidth - 22).clamp(1, 180),
                                  ),
                                  child: Text(
                                    choice,
                                    textAlign: TextAlign.center,
                                    style: withWeight(
                                      theme.textTheme.titleMedium!,
                                      FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
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
    const bounds = Rect.fromLTWH(
      0,
      0,
      BrickBreakerRun.width,
      BrickBreakerRun.height,
    );
    final paint = Paint();
    canvas.drawRect(
      bounds,
      paint
        ..shader = RadialGradient(
          center: const Alignment(0, -.72),
          radius: .78,
          colors: [colors.surfaceContainerHighest, colors.surface],
        ).createShader(bounds),
    );
    paint.shader = null;
    paint.color = colors.outline.withValues(alpha: .36);
    for (var x = 10.0; x < bounds.right; x += 12) {
      for (var y = 10.0; y < bounds.bottom; y += 12) {
        canvas.drawCircle(Offset(x, y), .65, paint);
      }
    }

    final palette =
        paper
            ? const [
              Color(0xFF866189),
              Color(0xFFAE7D9B),
              Color(0xFF5F9A81),
              Color(0xFFCB8A72),
              Color(0xFF76948B),
            ]
            : const [
              Color(0xFF665181),
              Color(0xFF9277BE),
              Color(0xFF64D4B0),
              Color(0xFFC18D98),
              Color(0xFFB8CBCA),
            ];
    for (final brick in run.bricks) {
      final fill =
          brick.gold
              ? (paper ? const Color(0xFFE2A945) : colors.tertiary)
              : palette[brick.row];
      _rounded(
        canvas,
        paint,
        brick.bounds.shift(const Offset(0, 2)),
        colors.outline,
        3,
      );
      _rounded(canvas, paint, brick.bounds, fill, 3);
      _rounded(
        canvas,
        paint,
        Rect.fromLTWH(
          brick.bounds.left + 3,
          brick.bounds.top + 2,
          brick.bounds.width - 6,
          1.5,
        ),
        Colors.white.withValues(alpha: .42),
        1,
      );
      if (brick.gold) {
        final center = brick.bounds.center;
        canvas.drawPath(
          Path()
            ..moveTo(center.dx, center.dy - 4)
            ..lineTo(center.dx + 4, center.dy)
            ..lineTo(center.dx, center.dy + 4)
            ..lineTo(center.dx - 4, center.dy)
            ..close(),
          paint..color = const Color(0xFF633715),
        );
      }
    }

    if (effects) {
      for (final impact in run.impacts) {
        final progress = run.impactProgress(impact).clamp(0.0, 1.0);
        final tint =
            impact.brick.gold ? colors.tertiary : palette[impact.brick.row];
        paint.color = tint.withValues(alpha: (1 - progress) * .9);
        final center = impact.brick.bounds.center;
        final count = impact.brick.gold ? 9 : 5;
        for (var i = 0; i < count; i++) {
          final angle = i * 2 * pi / count + .43;
          final reach = 8 + progress * (i.isEven ? 24 : 16);
          final point = center + Offset(cos(angle), sin(angle)) * reach;
          canvas.drawCircle(point, 1.4 + (1 - progress) * 1.5, paint);
        }
      }
    }

    if (run.phase == BrickPhase.bonus) {
      for (var i = 0; i < run.choices.length; i++) {
        final x = run.laneCenter(i);
        final selected = i == run.catchLane;
        _rounded(
          canvas,
          paint,
          Rect.fromLTWH(x - 10, BrickBreakerRun.paddleY + 16, 20, 3),
          selected ? colors.primary : colors.outline,
          2,
        );
      }
    }

    const half = BrickBreakerRun.paddleHalfWidth;
    final paddle = Rect.fromLTWH(
      run.paddle - half,
      BrickBreakerRun.paddleY,
      half * 2,
      9,
    );
    _rounded(
      canvas,
      paint,
      paddle.shift(const Offset(0, 3)),
      colors.outline,
      5,
    );
    _rounded(canvas, paint, paddle, colors.primary, 5);
    _rounded(
      canvas,
      paint,
      paddle.deflate(4),
      colors.onPrimary.withValues(alpha: .45),
      1,
    );
    if (run.phase == BrickPhase.bonus || run.phase == BrickPhase.feedback) {
      return;
    }
    for (final ball in run.balls) {
      final position = ball.position;
      if (effects && run.phase == BrickPhase.flying) {
        paint
          ..color = colors.primary.withValues(alpha: .25)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(position - ball.velocity * .04, position, paint);
      }
      canvas.drawCircle(
        position,
        BrickBreakerRun.ballRadius + 2,
        paint..color = colors.primary.withValues(alpha: .24),
      );
      canvas.drawCircle(
        position,
        BrickBreakerRun.ballRadius,
        paint..color = paper ? colors.primary : colors.onSurface,
      );
    }
  }

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

  @override
  bool shouldRepaint(covariant _FieldPainter oldDelegate) => true;
}
