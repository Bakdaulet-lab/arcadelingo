import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'space_flight.dart';

class SpaceLabels {
  SpaceLabels(
    List<String> labels,
    this.size,
    this.scaler,
    this.direction,
    this.locale,
    this.style,
  ) : words = List.unmodifiable(labels) {
    final sx = size.width / SpaceFlight.worldSize.width;
    final sy = size.height / SpaceFlight.worldSize.height;
    final unit = math.min(sx, sy);
    final lane = (size.width - 8) / math.max(1, labels.length);
    final maxWidth = 318 * sx;
    final fontSize = (18 * unit).clamp(14.0, 19.0);
    for (final word in labels) {
      final painter = TextPainter(
        text: TextSpan(text: word, style: style.copyWith(fontSize: fontSize)),
        textScaler: scaler,
        textDirection: direction,
        locale: locale,
        textAlign: TextAlign.center,
      )..layout();
      final pad = 12.0 * unit;
      final natural = painter.maxIntrinsicWidth + 1;
      final wholeWord = painter.minIntrinsicWidth + 1;
      final narrow = math.max(8.0, lane * .88 - pad);
      painter.layout(maxWidth: narrow);
      if (wholeWord > narrow || painter.computeLineMetrics().length > 2) {
        final width = math.max(wholeWord, math.min(natural, maxWidth * .78));
        painter.layout(
          maxWidth: math.max(8.0, math.min(width, maxWidth - pad - 6 * unit)),
        );
      }
      // Very large accessibility settings still keep the entire caption inside
      // the flight field. Normal cards keep the preferred reading size.
      final textScale = math.min(
        1.0,
        math.max(1.0, 145 * sy - 12 * unit) / math.max(1.0, painter.height),
      );
      final plaque = Size(
        painter.width * textScale + pad,
        painter.height * textScale + 7 * unit,
      );
      final body = Size(
        math.max(94 * unit, plaque.width + 6 * unit),
        math.max(42 * unit, plaque.height + 7 * unit),
      );
      tags.add((painter: painter, scale: textScale, plaque: plaque));
      hitSizes.add(Size(body.width / sx, body.height / sy));
    }
  }

  final List<String> words;
  final Size size;
  final TextScaler scaler;
  final TextDirection direction;
  final Locale? locale;
  final TextStyle style;
  final tags = <({TextPainter painter, double scale, Size plaque})>[];
  final hitSizes = <Size>[];

  void dispose() {
    for (final tag in tags) {
      tag.painter.dispose();
    }
  }
}

class SpaceBackdrop extends CustomPainter {
  SpaceBackdrop(this.sheet, this.day);
  final ui.Image? sheet;
  final bool day;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()..color = day ? const Color(0xfffaeace) : const Color(0xff141c33),
    );
    final atlas = sheet;
    if (atlas != null) {
      final crop =
          applyBoxFit(BoxFit.cover, SpaceFlight.worldSize, size).source;
      final source = Alignment.center.inscribe(
        crop,
        Offset.zero & SpaceFlight.worldSize,
      );
      canvas.drawImageRect(
        atlas,
        source.scaleBy(atlas.width / 360),
        bounds,
        Paint()..filterQuality = FilterQuality.low,
      );
    }
    final frame =
        Paint()
          ..color = day ? const Color(0x77795667) : const Color(0x77ffead2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .9;
    for (final corner in [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ]) {
      final p = corner.withinRect(bounds.deflate(9));
      final path =
          Path()
            ..moveTo(p.dx - 10 * corner.x, p.dy)
            ..lineTo(p.dx, p.dy)
            ..lineTo(p.dx, p.dy - 10 * corner.y);
      canvas.drawPath(path, frame);
    }
  }

  @override
  bool shouldRepaint(SpaceBackdrop old) => old.sheet != sheet || old.day != day;
}

extension on Rect {
  Rect scaleBy(double by) =>
      Rect.fromLTRB(left * by, top * by, right * by, bottom * by);
}

class SpaceSprites extends CustomPainter {
  SpaceSprites({
    required this.flight,
    required this.sheet,
    required this.labels,
    required this.day,
    required this.reduced,
    required Listenable repaint,
  }) : super(repaint: repaint);
  final SpaceFlight flight;
  final ui.Image? sheet;
  final SpaceLabels labels;
  final bool day, reduced;
  final _bitmap = Paint()..filterQuality = FilterQuality.low;
  final _fill = Paint();
  final _line =
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

  static const _hull = Rect.fromLTWH(0, 422, 80, 92);
  static const _craft = Rect.fromLTWH(0, 516, 108, 48);
  static const _ore = [
    Rect.fromLTWH(80, 422, 80, 70),
    Rect.fromLTWH(160, 422, 80, 70),
    Rect.fromLTWH(240, 422, 80, 70),
  ];

  void _sprite(
    Canvas canvas,
    Rect source,
    Offset p,
    Size size, {
    double angle = 0,
  }) {
    final atlas = sheet;
    if (atlas == null) return;
    final rect = Rect.fromCenter(
      center: angle == 0 ? p : Offset.zero,
      width: size.width,
      height: size.height,
    );
    if (angle != 0) {
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(angle);
    }
    canvas.drawImageRect(
      atlas,
      source.scaleBy(atlas.width / 360),
      rect,
      _bitmap,
    );
    if (angle != 0) canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / SpaceFlight.worldSize.width,
        sy = size.height / SpaceFlight.worldSize.height;
    final unit = math.min(sx, sy);
    final cool = day ? const Color(0xff176961) : const Color(0xff9dffe0);
    final trim = day ? const Color(0xff886e72) : const Color(0xffc4aeaa);
    Offset local(Offset p) => Offset(p.dx * sx, p.dy * sy);
    if (!reduced) {
      _line
        ..color = day ? const Color(0x427b586a) : const Color(0x5bffefd0)
        ..strokeWidth = .8;
      for (var i = 0; i < 18; i++) {
        final y = ((i * 83.0 + flight.time * (15 + i % 4 * 6)) % 420) * sy;
        final x = ((i * 137 + 21) % 360) * sx;
        canvas.drawLine(
          Offset(x, y),
          Offset(x, y + unit * (1.3 + i % 3)),
          _line,
        );
      }
    }
    for (final h in flight.rocks) {
      final p = local(h.position), r = h.radius * unit;
      if (sheet == null) {
        canvas.drawCircle(p, r, _fill..color = const Color(0xff987b96));
      } else {
        _sprite(
          canvas,
          _ore[h.id % 3],
          p,
          Size(3.3 * r, 3 * r),
          angle: reduced ? 0 : h.angle,
        );
      }
    }
    for (final b in flight.bolts) {
      final p = local(b.position);
      final end = p + Offset(0, 12 * unit);
      canvas.drawLine(
        p,
        end,
        _line
          ..strokeWidth = 6 * unit
          ..color = cool.withValues(alpha: .28),
      );
      canvas.drawLine(
        p,
        end,
        _line
          ..strokeWidth = 2.6 * unit
          ..color = cool,
      );
    }
    for (final d in flight.drones) {
      if (!d.visible || d.index >= labels.tags.length) continue;
      final p = local(d.position), tag = labels.tags[d.index];
      _sprite(canvas, _craft, p, Size(d.width * sx, d.height * sy));
      final rect = Rect.fromCenter(
        center: p,
        width: tag.plaque.width,
        height: tag.plaque.height,
      );
      final plaque = RRect.fromRectAndRadius(rect, Radius.circular(4 * unit));
      canvas.drawRRect(
        plaque,
        _fill..color = day ? const Color(0xfffff8e9) : const Color(0xff242237),
      );
      canvas.drawRRect(
        plaque,
        _line
          ..strokeWidth = 1
          ..color = trim,
      );
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.scale(tag.scale);
      tag.painter.paint(
        canvas,
        Offset(-tag.painter.width / 2, -tag.painter.height / 2),
      );
      canvas.restore();
    }
    final ship = local(flight.ship);
    if (sheet == null) {
      canvas.drawPath(
        Path()
          ..moveTo(ship.dx, ship.dy - 20 * unit)
          ..relativeLineTo(13 * unit, 35 * unit)
          ..relativeLineTo(-26 * unit, 0)
          ..close(),
        _fill..color = cool,
      );
    } else {
      _sprite(
        canvas,
        _hull,
        ship,
        Size(52 * unit, 60 * unit),
        angle: reduced ? 0 : flight.bank,
      );
    }
    if (flight.immunity > 0) {
      canvas.drawOval(
        Rect.fromCenter(center: ship, width: 57 * unit, height: 65 * unit),
        _line
          ..strokeWidth = 1.4 * unit
          ..color = cool.withValues(alpha: flight.immunity.clamp(0.0, .9)),
      );
    }
    for (final b in flight.bursts) {
      final color = switch (b.kind) {
        SpaceBurstKind.correct => cool,
        SpaceBurstKind.wrong => const Color(0xffeb8962),
        SpaceBurstKind.rock =>
          day ? const Color(0xff9a613e) : const Color(0xfff3c6a1),
        SpaceBurstKind.shield =>
          day ? const Color(0xffa14f31) : const Color(0xffffc18f),
      };
      final p = local(b.position), t = b.progress.clamp(0.0, 1.0);
      _line
        ..color = color.withValues(alpha: 1 - t)
        ..strokeWidth = 1.5 * unit;
      canvas.drawCircle(p, (4 + t * (reduced ? 5 : 19)) * unit, _line);
      if (!reduced) {
        for (var k = 0; k < 7; k++) {
          final angle = k * (2 * math.pi / 7);
          final ray = Offset(math.cos(angle), math.sin(angle)) * unit;
          canvas.drawLine(
            p + ray * (8 + 23 * t),
            p + ray * (12 + 24 * t),
            _line,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(SpaceSprites old) =>
      old.flight != flight ||
      old.sheet != sheet ||
      old.labels != labels ||
      old.reduced != reduced ||
      old.day != day;
}
