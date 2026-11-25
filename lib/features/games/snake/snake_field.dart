import 'dart:math' as math;

import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_field_swipe.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'snake_run.dart';

const _labelPadding = EdgeInsets.symmetric(horizontal: 7, vertical: 3);

TextStyle _appleLabelStyle(BuildContext context, {required double size}) {
  final theme = Theme.of(context);
  return withWeight(
    theme.textTheme.titleSmall!,
    FontWeight.w600,
  ).copyWith(color: theme.colorScheme.onSurface, fontSize: size, height: 1.25);
}

/// Keeps the steering surface free when the words need more room than the grid.
class SnakePlayfield extends StatelessWidget {
  const SnakePlayfield({
    required this.run,
    required this.motion,
    required this.onTurn,
    required this.fieldKey,
    this.overlay,
    super.key,
  });

  final SnakeRun run;
  final ValueListenable<double> motion;
  final ValueChanged<SnakeDirection>? onTurn;
  final Key fieldKey;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) => ArcadePanel(
    padding: const EdgeInsets.all(7),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final apples = run.apples;
        final labels = _placeLabels(
          apples,
          run.rocks,
          constraints.maxWidth,
          _appleLabelStyle(context, size: 14),
          MediaQuery.textScalerOf(context),
          Directionality.of(context),
          Localizations.localeOf(context),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SnakeField(
                  key: fieldKey,
                  run: run,
                  motion: motion,
                  onTurn: onTurn,
                  labels: labels ?? const [],
                ),
                if (overlay case final overlay?)
                  Positioned.fill(child: overlay),
              ],
            ),
            if (labels == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(5, 10, 5, 3),
                child: Column(
                  spacing: 6,
                  children: [
                    for (final (index, apple) in apples.indexed)
                      Row(
                        children: [
                          _AppleBadge(index: index, size: 24),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              apple.word.text,
                              style: _appleLabelStyle(context, size: 16),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
}

class SnakeField extends StatelessWidget {
  const SnakeField({
    required this.run,
    required this.motion,
    required this.onTurn,
    this.labels,
    super.key,
  });

  final SnakeRun run;
  final ValueListenable<double> motion;
  final ValueChanged<SnakeDirection>? onTurn;
  final List<Rect>? labels;

  void _turn(Offset _, Offset delta) {
    final direction =
        delta.dx.abs() >= delta.dy.abs()
            ? (delta.dx > 0 ? SnakeDirection.right : SnakeDirection.left)
            : (delta.dy > 0 ? SnakeDirection.down : SnakeDirection.up);
    onTurn?.call(direction);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        theme.brightness == Brightness.dark
            ? _FieldPalette.night
            : _FieldPalette.paper;
    final apples = run.apples;
    final labelStyle = _appleLabelStyle(context, size: 14);
    final fieldMotion =
        MediaQuery.disableAnimationsOf(context)
            ? const AlwaysStoppedAnimation(1.0)
            : motion;
    final board = ArcadeFieldSwipe(
      distance: 8,
      continuous: true,
      onSwipe: onTurn == null ? null : _turn,
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.maxWidth;
              final labels =
                  this.labels ??
                  _placeLabels(
                    apples,
                    run.rocks,
                    side,
                    labelStyle,
                    MediaQuery.textScalerOf(context),
                    Directionality.of(context),
                    Localizations.localeOf(context),
                  ) ??
                  const [];
              final unit = side / SnakeRun.size;
              return Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _BoardPainter(palette, run.rocks),
                    ),
                  ),
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _SnakePainter(
                        palette: palette,
                        body: run.body,
                        previousBody: run.previousBody,
                        direction: run.direction,
                        motion: fieldMotion,
                      ),
                    ),
                  ),
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _ApplePainter(palette, apples, labels),
                    ),
                  ),
                  for (var i = 0; i < labels.length; i++)
                    Positioned.fromRect(
                      rect: labels[i],
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.label,
                          border: Border.all(color: palette.labelBorder),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: palette.field.withValues(alpha: .54),
                              blurRadius: 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: _labelPadding,
                          child: Text(
                            apples[i].word.text,
                            textAlign: TextAlign.center,
                            textWidthBasis: TextWidthBasis.longestLine,
                            style: labelStyle,
                          ),
                        ),
                      ),
                    ),
                  if (labels.isEmpty)
                    for (final (index, apple) in apples.indexed)
                      Positioned.fromRect(
                        rect: Rect.fromCenter(
                          center: _cellCenter(apple.cell, unit),
                          width: unit * .80,
                          height: unit * .80,
                        ),
                        child: ExcludeSemantics(
                          child: _AppleBadge(
                            key: ValueKey('snake.apple.$index'),
                            index: index,
                            size: unit * .80,
                          ),
                        ),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
    final strings = context.strings;
    final turn = onTurn;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: strings.snakeBoard,
      customSemanticsActions:
          turn == null
              ? null
              : {
                CustomSemanticsAction(label: strings.snakeUp):
                    () => turn(SnakeDirection.up),
                CustomSemanticsAction(label: strings.snakeRight):
                    () => turn(SnakeDirection.right),
                CustomSemanticsAction(label: strings.snakeDown):
                    () => turn(SnakeDirection.down),
                CustomSemanticsAction(label: strings.snakeLeft):
                    () => turn(SnakeDirection.left),
              },
      child: board,
    );
  }
}

Offset _cellCenter(SnakeCell cell, double unit) =>
    Offset((cell.x + .5) * unit, (cell.y + .5) * unit);

List<Rect>? _placeLabels(
  List<SnakeApple> apples,
  Set<SnakeCell> rocks,
  double side,
  TextStyle style,
  TextScaler scaler,
  TextDirection textDirection,
  Locale locale,
) {
  final unit = side / SnakeRun.size;
  final centers = [for (final apple in apples) _cellCenter(apple.cell, unit)];
  final reserved = [
    for (final center in centers)
      Rect.fromCenter(center: center, width: unit * .94, height: unit),
  ];
  final rockRects = [
    for (final rock in rocks)
      Rect.fromCenter(
        center: _cellCenter(rock, unit),
        width: unit * .82,
        height: unit * .82,
      ),
  ];
  final result = <Rect>[];
  for (var i = 0; i < apples.length; i++) {
    final label = apples[i].word.text;
    // Phrases can wrap at spaces. Give single words extra room before
    // Flutter has to break a word across lines at large text sizes.
    final maxWidth = math.max(1.0, side * .55 - _labelPadding.horizontal);
    final measure = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: textDirection,
      textScaler: scaler,
      textWidthBasis: TextWidthBasis.longestLine,
      locale: locale,
    )..layout(maxWidth: maxWidth);
    if (measure.minIntrinsicWidth > maxWidth ||
        measure.computeLineMetrics().length > 2) {
      measure.dispose();
      return null;
    }
    final width = measure.width.ceilToDouble() + _labelPadding.horizontal;
    final height = measure.height.ceilToDouble() + _labelPadding.vertical;
    measure.dispose();
    final center = centers[i];
    final distance = unit * .51 + 2;
    final candidates = [
      Offset(center.dx - width / 2, center.dy + distance),
      Offset(center.dx - width / 2, center.dy - distance - height),
      Offset(center.dx + distance, center.dy - height / 2),
      Offset(center.dx - distance - width, center.dy - height / 2),
      Offset(center.dx - width * .20, center.dy + distance),
      Offset(center.dx - width * .80, center.dy + distance),
      Offset(center.dx - width * .20, center.dy - distance - height),
      Offset(center.dx - width * .80, center.dy - distance - height),
    ];
    Rect? best;
    var leastOverlap = double.infinity;
    for (final candidate in candidates) {
      final rect = Rect.fromLTWH(
        candidate.dx.clamp(3.0, math.max(3.0, side - width - 3)),
        candidate.dy.clamp(3.0, math.max(3.0, side - height - 3)),
        width,
        height,
      );
      if (reserved.any(rect.overlaps)) continue;
      var overlap = 0.0;
      for (final rock in rockRects) {
        final clipped = rect.intersect(rock);
        if (!clipped.isEmpty) overlap += clipped.width * clipped.height * .2;
      }
      if (overlap < leastOverlap) {
        best = rect;
        leastOverlap = overlap;
        if (overlap == 0) break;
      }
    }
    if (best == null) return null;
    result.add(best);
    reserved.add(best.inflate(3));
  }
  return result;
}

class _AppleBadge extends StatelessWidget {
  const _AppleBadge({required this.index, required this.size, super.key});

  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final (color, ink) =
        night
            ? (const Color(0xFFFFAB9E), const Color(0xFF401319))
            : (const Color(0xFF98383D), const Color(0xFFFFFAEE));
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Center(
          child: Text(
            '${index + 1}',
            style: _appleLabelStyle(
              context,
              size: size * .66,
            ).copyWith(color: ink, height: 1),
            textScaler: TextScaler.noScaling,
          ),
        ),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  const _BoardPainter(this.palette, this.rocks);

  final _FieldPalette palette;
  final Set<SnakeCell> rocks;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final unit = size.width / SnakeRun.size;
    final board = Offset.zero & size;
    canvas.drawRect(board, Paint()..color = palette.field);
    canvas.drawRect(
      board,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.12, .14),
          radius: .60,
          colors: [palette.snake.withValues(alpha: .065), Colors.transparent],
        ).createShader(board),
    );
    final grid = Paint()..color = palette.grid;
    for (var i = 1; i < SnakeRun.size; i++) {
      final line = i * unit;
      canvas.drawLine(Offset(line, 0), Offset(line, size.height), grid);
      canvas.drawLine(Offset(0, line), Offset(size.width, line), grid);
    }
    _drawEdgeGuides(canvas, size.width, unit);
    final fill = Paint()..color = palette.rock;
    final bevel = Paint()..color = palette.rockBevel;
    final cutStone =
        Path()
          ..moveTo(.14, .21)
          ..lineTo(.32, .07)
          ..lineTo(.77, .07)
          ..lineTo(.93, .28)
          ..lineTo(.90, .78)
          ..lineTo(.70, .93)
          ..lineTo(.22, .91)
          ..lineTo(.07, .72)
          ..close();
    final facet =
        Path()
          ..moveTo(.14, .21)
          ..lineTo(.32, .07)
          ..lineTo(.77, .07)
          ..lineTo(.62, .28)
          ..lineTo(.31, .33)
          ..lineTo(.07, .72)
          ..close();
    for (final rock in rocks) {
      canvas.save();
      canvas.translate(rock.x * unit, rock.y * unit);
      canvas.scale(unit);
      canvas.drawPath(cutStone, fill);
      canvas.drawPath(facet, bevel);
      canvas.restore();
    }
  }

  void _drawEdgeGuides(Canvas canvas, double side, double unit) {
    final margin = unit * .77;
    final mid = side / 2;
    final gate =
        Paint()
          ..color = palette.guide
          ..strokeWidth = math.max(2, unit * .105)
          ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(mid - margin, 1), Offset(mid + margin, 1), gate);
    canvas.drawLine(
      Offset(mid - margin, side - 1),
      Offset(mid + margin, side - 1),
      gate,
    );
    canvas.drawLine(Offset(1, mid - margin), Offset(1, mid + margin), gate);
    canvas.drawLine(
      Offset(side - 1, mid - margin),
      Offset(side - 1, mid + margin),
      gate,
    );
  }

  @override
  bool shouldRepaint(_BoardPainter oldDelegate) =>
      palette != oldDelegate.palette || rocks != oldDelegate.rocks;
}

class _SnakePainter extends CustomPainter {
  _SnakePainter({
    required this.palette,
    required this.body,
    required this.previousBody,
    required this.direction,
    required this.motion,
  }) : super(repaint: motion);

  final _FieldPalette palette;
  final List<SnakeCell> body;
  final List<SnakeCell> previousBody;
  final SnakeDirection direction;
  final ValueListenable<double> motion;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _drawSnake(canvas, size.width, size.width / SnakeRun.size);
  }

  void _drawSnake(Canvas canvas, double side, double unit) {
    if (body.isEmpty) return;
    final points = <Offset>[];
    final path = Path();
    for (var i = 0; i < body.length; i++) {
      final current = _cellCenter(body[i], unit);
      final previous =
          previousBody.isEmpty
              ? current
              : _cellCenter(
                previousBody[math.min(i, previousBody.length - 1)],
                unit,
              );
      final raw =
          previous + _shortOffset(current - previous, side) * motion.value;
      final point =
          points.isEmpty
              ? raw
              : points.last + _shortOffset(raw - points.last, side);
      points.add(point);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    final bounds = points
        .skip(1)
        .fold<Rect>(
          Rect.fromCircle(center: points.first, radius: 0),
          (rect, point) =>
              rect.expandToInclude(Rect.fromCircle(center: point, radius: 0)),
        )
        .inflate(unit * .64);
    final glow =
        Paint()
          ..color = palette.glow
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * .8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * .12);
    final base =
        Paint()
          ..color = palette.snakeBase
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * .72
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final inner =
        Paint()
          ..color = palette.snake
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * .58
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    for (
      var y = (-bounds.bottom / side).ceil();
      y <= ((side - bounds.top) / side).floor();
      y++
    ) {
      for (
        var x = (-bounds.right / side).ceil();
        x <= ((side - bounds.left) / side).floor();
        x++
      ) {
        canvas.save();
        canvas.translate(x * side, y * side);
        canvas.drawPath(path, glow);
        canvas.drawPath(path, base);
        canvas.drawPath(path, inner);
        for (final point in points.skip(1)) {
          canvas.drawCircle(
            point - Offset(unit * .075, unit * .075),
            unit * .045,
            Paint()..color = palette.head.withValues(alpha: .74),
          );
        }
        _drawHead(canvas, points.first, unit);
        canvas.restore();
      }
    }
  }

  void _drawHead(Canvas canvas, Offset center, double unit) {
    final heading = math.atan2(direction.dy, direction.dx);
    final previousHeading =
        _shortOffset(
          _cellCenter(previousBody[0], unit) -
              _cellCenter(previousBody[1], unit),
          SnakeRun.size * unit,
        ).direction;
    final turn =
        (heading - previousHeading + math.pi) % (2 * math.pi) - math.pi;
    final progress = Curves.easeOut.transform((motion.value * 3).clamp(0, 1));
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(previousHeading + turn * progress);
    final bulb = Rect.fromCenter(
      center: Offset(unit * .055, 0),
      width: unit * .91,
      height: unit * .77,
    );
    canvas.drawOval(
      bulb,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.head, palette.snake],
        ).createShader(bulb),
    );
    for (final eye in const [-.15, .15]) {
      final point = Offset(unit * .18, unit * eye);
      canvas.drawCircle(point, unit * .060, Paint()..color = palette.eye);
      canvas.drawCircle(
        point - Offset(unit * .011, unit * .018),
        unit * .019,
        Paint()..color = palette.head,
      );
    }
    canvas.restore();
  }

  Offset _shortOffset(Offset offset, double side) {
    double wrap(double value) => (value + side / 2) % side - side / 2;
    return Offset(wrap(offset.dx), wrap(offset.dy));
  }

  @override
  bool shouldRepaint(_SnakePainter oldDelegate) =>
      palette != oldDelegate.palette ||
      body != oldDelegate.body ||
      previousBody != oldDelegate.previousBody ||
      direction != oldDelegate.direction ||
      motion != oldDelegate.motion;
}

class _ApplePainter extends CustomPainter {
  const _ApplePainter(this.palette, this.apples, this.labels);

  final _FieldPalette palette;
  final List<SnakeApple> apples;
  final List<Rect> labels;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final unit = size.width / SnakeRun.size;
    for (var i = 0; i < apples.length; i++) {
      final center = _cellCenter(apples[i].cell, unit);
      if (labels.isNotEmpty) {
        canvas.drawLine(
          center,
          labels[i].center,
          Paint()
            ..color = palette.labelBorder
            ..strokeWidth = 1.3,
        );
      }
      _drawApple(canvas, center, unit);
    }
  }

  void _drawApple(Canvas canvas, Offset center, double unit) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(unit, unit);
    final apple =
        Path()
          ..moveTo(0, -.26)
          ..cubicTo(-.49, -.48, -.47, .17, -.24, .33)
          ..cubicTo(-.13, .40, -.02, .36, 0, .36)
          ..cubicTo(.19, .47, .37, .24, .39, .02)
          ..cubicTo(.41, -.20, .26, -.42, 0, -.26)
          ..close();
    canvas.drawPath(
      apple,
      Paint()
        ..color = palette.fruitTop.withValues(alpha: .30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .12),
    );
    canvas.drawPath(
      apple,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.fruitTop, palette.fruitBase],
        ).createShader(apple.getBounds()),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-.27, -.24, .20, .10),
      Paint()..color = const Color(0x76FFF0D6),
    );
    canvas.drawLine(
      const Offset(-.015, -.24),
      const Offset(-.055, -.49),
      Paint()
        ..color = palette.stem
        ..strokeWidth = .065
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, -.29)
        ..quadraticBezierTo(.025, -.52, .285, -.52)
        ..quadraticBezierTo(.228, -.342, 0, -.29),
      Paint()..color = palette.leaf,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ApplePainter oldDelegate) =>
      palette != oldDelegate.palette ||
      apples != oldDelegate.apples ||
      !listEquals(labels, oldDelegate.labels);
}

class _FieldPalette {
  const _FieldPalette({
    required this.field,
    required this.grid,
    required this.guide,
    required this.glow,
    required this.snake,
    required this.snakeBase,
    required this.head,
    required this.eye,
    required this.fruitTop,
    required this.fruitBase,
    required this.leaf,
    required this.stem,
    required this.label,
    required this.labelBorder,
    required this.rock,
    required this.rockBevel,
  });

  static const night = _FieldPalette(
    field: Color(0xFF120E1C),
    grid: Color(0xFF272239),
    guide: Color(0xA63A9F7A),
    glow: Color(0x8048E9AA),
    snake: Color(0xFF48E9AA),
    snakeBase: Color(0xFF167F64),
    head: Color(0xFF9CFFD3),
    eye: Color(0xFF062C23),
    fruitTop: Color(0xFFFFAD88),
    fruitBase: Color(0xFFBA3659),
    leaf: Color(0xFFA2FAB7),
    stem: Color(0xFFDCA65C),
    label: Color(0xFF2C223A),
    labelBorder: Color(0xFF665472),
    rock: Color(0xFF715767),
    rockBevel: Color(0xFFAB8993),
  );

  static const paper = _FieldPalette(
    field: Color(0xFFF9ECDA),
    grid: Color(0xFFE3CDB2),
    guide: Color(0x9659805C),
    glow: Color(0x3D2C6549),
    snake: Color(0xFF4E9867),
    snakeBase: Color(0xFF2C6549),
    head: Color(0xFF79BE85),
    eye: Color(0xFF113B25),
    fruitTop: Color(0xFFFFAA77),
    fruitBase: Color(0xFFB83E2D),
    leaf: Color(0xFF567744),
    stem: Color(0xFF754412),
    label: Color(0xFFFFFCF4),
    labelBorder: Color(0xFFC6AA8D),
    rock: Color(0xFF9A7966),
    rockBevel: Color(0xFFC4A58A),
  );

  final Color field;
  final Color grid;
  final Color guide;
  final Color glow;
  final Color snake;
  final Color snakeBase;
  final Color head;
  final Color eye;
  final Color fruitTop;
  final Color fruitBase;
  final Color leaf;
  final Color stem;
  final Color label;
  final Color labelBorder;
  final Color rock;
  final Color rockBevel;
}
