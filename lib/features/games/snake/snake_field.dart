import 'dart:math' as math;

import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'snake_run.dart';

const _labelPadding = EdgeInsets.symmetric(horizontal: 7, vertical: 3);

class SnakeField extends StatefulWidget {
  const SnakeField({
    required this.run,
    required this.motion,
    required this.onTurn,
    super.key,
  });

  final SnakeRun run;
  final Animation<double> motion;
  final ValueChanged<SnakeDirection>? onTurn;

  @override
  State<SnakeField> createState() => _SnakeFieldState();
}

class _SnakeFieldState extends State<SnakeField> {
  Offset? _horizontalTouch;
  Offset? _verticalTouch;

  void _dragUpdate(DragUpdateDetails details, {required bool horizontal}) {
    final from = horizontal ? _horizontalTouch : _verticalTouch;
    if (from == null) return;
    final delta = details.localPosition - from;
    if ((horizontal ? delta.dx : delta.dy).abs() < 16) return;
    _horizontalTouch = _verticalTouch = null;
    final direction =
        horizontal
            ? (delta.dx > 0 ? SnakeDirection.right : SnakeDirection.left)
            : (delta.dy > 0 ? SnakeDirection.down : SnakeDirection.up);
    widget.onTurn?.call(direction);
  }

  void _cancelHorizontal() => _horizontalTouch = null;

  void _cancelVertical() => _verticalTouch = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        theme.brightness == Brightness.dark
            ? _FieldPalette.night
            : _FieldPalette.paper;
    final apples = widget.run.apples;
    final labelStyle = withWeight(
      theme.textTheme.labelMedium!,
      FontWeight.w600,
    ).copyWith(color: theme.colorScheme.onSurface, height: 1.1);
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4);
    final textDirection = Directionality.of(context);
    final turnEnabled = widget.onTurn != null;
    final motion =
        MediaQuery.disableAnimationsOf(context)
            ? const AlwaysStoppedAnimation(1.0)
            : widget.motion;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onHorizontalDragDown:
          turnEnabled
              ? (details) => _horizontalTouch = details.localPosition
              : null,
      onHorizontalDragUpdate:
          turnEnabled
              ? (details) => _dragUpdate(details, horizontal: true)
              : null,
      onHorizontalDragEnd: turnEnabled ? (_) => _cancelHorizontal() : null,
      onHorizontalDragCancel: turnEnabled ? _cancelHorizontal : null,
      onVerticalDragDown:
          turnEnabled
              ? (details) => _verticalTouch = details.localPosition
              : null,
      onVerticalDragUpdate:
          turnEnabled
              ? (details) => _dragUpdate(details, horizontal: false)
              : null,
      onVerticalDragEnd: turnEnabled ? (_) => _cancelVertical() : null,
      onVerticalDragCancel: turnEnabled ? _cancelVertical : null,
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.maxWidth;
              final labels = _placeLabels(
                apples,
                side,
                labelStyle,
                scaler,
                textDirection,
              );
              return Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _SnakePainter(
                        palette: palette,
                        body: widget.run.body,
                        previousBody: widget.run.previousBody,
                        direction: widget.run.direction,
                        apples: apples,
                        labels: labels,
                        motion: motion,
                      ),
                    ),
                  ),
                  for (var i = 0; i < apples.length; i++)
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
                            textScaler: scaler,
                            style: labelStyle,
                          ),
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
  }
}

Offset _cellCenter(SnakeCell cell, double unit) =>
    Offset((cell.x + .5) * unit, (cell.y + .5) * unit);

List<Rect> _placeLabels(
  List<SnakeApple> apples,
  double side,
  TextStyle style,
  TextScaler scaler,
  TextDirection textDirection,
) {
  final unit = side / SnakeRun.size;
  final centers = [for (final apple in apples) _cellCenter(apple.cell, unit)];
  final reserved = [
    for (final center in centers)
      Rect.fromCenter(center: center, width: unit * .94, height: unit),
  ];
  final result = <Rect>[];
  for (var i = 0; i < apples.length; i++) {
    final label = apples[i].word.text;
    // Phrases can wrap at spaces. Give single words extra room before
    // Flutter has to break a word across lines at large text sizes.
    final widthFraction = label.contains(' ') ? .55 : .68;
    final measure = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: textDirection,
      textScaler: scaler,
    )..layout(
      maxWidth: math.max(1, side * widthFraction - _labelPadding.horizontal),
    );
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
      var overlap = 0.0;
      for (final obstacle in reserved) {
        final clipped = rect.intersect(obstacle);
        if (!clipped.isEmpty) overlap += clipped.width * clipped.height;
      }
      if (overlap < leastOverlap) {
        best = rect;
        leastOverlap = overlap;
        if (overlap == 0) break;
      }
    }
    result.add(best!);
    reserved.add(best.inflate(3));
  }
  return result;
}

class _SnakePainter extends CustomPainter {
  _SnakePainter({
    required this.palette,
    required this.body,
    required this.previousBody,
    required this.direction,
    required this.apples,
    required this.labels,
    required this.motion,
  }) : super(repaint: motion);

  final _FieldPalette palette;
  final List<SnakeCell> body;
  final List<SnakeCell> previousBody;
  final SnakeDirection direction;
  final List<SnakeApple> apples;
  final List<Rect> labels;
  final Animation<double> motion;

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
    _drawSnake(canvas, size.width, unit);
    for (var i = 0; i < apples.length; i++) {
      final center = _cellCenter(apples[i].cell, unit);
      canvas.drawLine(
        center,
        labels[i].center,
        Paint()
          ..color = palette.labelBorder
          ..strokeWidth = 1.3,
      );
      _drawApple(canvas, center, unit);
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
    final angle = switch (direction) {
      SnakeDirection.right => 0.0,
      SnakeDirection.down => math.pi / 2,
      SnakeDirection.left => math.pi,
      SnakeDirection.up => -math.pi / 2,
    };
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
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
      apples != oldDelegate.apples ||
      labels != oldDelegate.labels ||
      motion != oldDelegate.motion;
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
}
