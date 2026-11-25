import 'package:arcadelingo/ui/streak_flame.dart';
import 'package:flutter/material.dart';

/// Crossed logs stay planted while the flame and the loose embers lift.
class FlamePainter extends CustomPainter {
  const FlamePainter({
    required this.tier,
    required this.mood,
    required this.scheme,
    this.intensity = 0,
  }) : assert(intensity >= 0 && intensity <= 1);

  final FlameTier tier;
  final FlameMood mood;
  final ColorScheme scheme;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side <= 0) return;
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / 200);
    final paint = Paint()..strokeJoin = StrokeJoin.round;
    final burning = tier != FlameTier.none && mood != FlameMood.unlit;
    if (burning && tier == FlameTier.inferno) {
      const glow = Rect.fromLTWH(0, 0, 200, 180);
      const amber = Color(0xFFFFAA51);
      canvas.drawOval(
        glow,
        Paint()
          ..shader = RadialGradient(
            colors: [
              amber.withValues(alpha: flameHaloAlpha),
              amber.withValues(alpha: 0),
            ],
          ).createShader(glow),
      );
    }

    final small = tier == FlameTier.none || tier == FlameTier.spark;
    final fire = small ? _spark : _blaze;
    final growth = switch (tier) {
      FlameTier.none => 0.78,
      FlameTier.steady => 0.79,
      _ => 1.0,
    };
    canvas.save();
    canvas.translate(100, 153);
    canvas.scale(
      growth * (1 + 0.025 * intensity),
      growth * (1 + 0.065 * intensity),
    );
    canvas.translate(-100 + 1.2 * intensity, -153);
    if (burning) {
      final atRisk = mood == FlameMood.atRisk;
      final edge = flameEdgeColor(scheme, mood, tier: tier);
      canvas.drawPath(fire.silhouette, paint..color = edge);
      canvas.drawPath(
        fire.orange,
        paint
          ..color =
              atRisk
                  ? const Color(0xFFF37769)
                  : small
                  ? const Color(0xFFF9733D)
                  : const Color(0xFFF77845),
      );
      canvas.drawPath(
        fire.gold,
        paint..color = small ? flameSparkCoreColor : const Color(0xFFFFBF58),
      );
      if (fire.core case final core?) {
        canvas.drawPath(core, paint..color = flameCoreColor);
      }
      if (tier == FlameTier.blaze || tier == FlameTier.inferno) {
        canvas.translate(1.5 * intensity, -4 * intensity);
        canvas.drawPath(_leftEmber, paint..color = const Color(0xFFF78346));
        canvas.drawPath(_rightEmber, paint..color = const Color(0xFFFFBD59));
        if (tier == FlameTier.inferno) {
          canvas.drawOval(const Rect.fromLTWH(68, 29, 5, 8), paint);
          canvas.drawOval(const Rect.fromLTWH(163, 61, 5, 7), paint);
        }
      }
    } else {
      canvas.drawPath(
        fire.silhouette,
        paint
          ..color = flameEdgeColor(scheme, FlameMood.unlit)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7,
      );
      paint.style = PaintingStyle.fill;
    }
    canvas.restore();
    _paintLogs(canvas, paint, scheme.brightness == Brightness.dark);
    canvas.restore();
  }

  @override
  bool shouldRepaint(FlamePainter old) =>
      old.tier != tier ||
      old.mood != mood ||
      old.scheme != scheme ||
      old.intensity != intensity;
}

typedef _FlameLayers = ({Path silhouette, Path orange, Path gold, Path? core});

// Paths share the 200-unit artboard of the two approved campfire marks.
final _FlameLayers _spark = (
  silhouette:
      Path()
        ..moveTo(99, 155)
        ..cubicTo(70, 155, 56, 144, 56, 121)
        ..cubicTo(56, 108, 62, 95, 69, 87)
        ..lineTo(75, 97)
        ..cubicTo(81, 85, 100, 75, 104, 52)
        ..cubicTo(118, 63, 123, 79, 118, 96)
        ..lineTo(127, 90)
        ..cubicTo(149, 121, 136, 155, 99, 155)
        ..close(),
  orange:
      Path()
        ..moveTo(99, 153)
        ..cubicTo(75, 153, 66, 144, 67, 126)
        ..cubicTo(68, 116, 73, 107, 78, 102)
        ..lineTo(82, 113)
        ..cubicTo(88, 97, 102, 94, 105, 79)
        ..cubicTo(114, 87, 108, 104, 114, 113)
        ..lineTo(122, 105)
        ..cubicTo(135, 127, 125, 150, 99, 153)
        ..close(),
  gold:
      Path()
        ..moveTo(99, 149)
        ..cubicTo(86, 148, 79, 138, 84, 126)
        ..cubicTo(87, 119, 92, 115, 94, 106)
        ..cubicTo(100, 111, 102, 117, 101, 124)
        ..lineTo(110, 117)
        ..cubicTo(118, 129, 114, 144, 99, 149)
        ..close(),
  core: null,
);

final _FlameLayers _blaze = (
  silhouette:
      Path()
        ..moveTo(98, 155)
        ..cubicTo(65, 155, 40, 149, 35, 129)
        ..cubicTo(32, 117, 34, 105, 30, 96)
        ..cubicTo(38, 97, 43, 103, 50, 110)
        ..cubicTo(47, 86, 64, 73, 60, 52)
        ..cubicTo(70, 56, 76, 62, 80, 78)
        ..cubicTo(84, 62, 80, 50, 94, 35)
        ..cubicTo(102, 27, 109, 22, 110, 13)
        ..cubicTo(128, 27, 131, 47, 119, 71)
        ..cubicTo(129, 62, 131, 55, 131, 47)
        ..cubicTo(147, 59, 159, 74, 149, 97)
        ..lineTo(159, 87)
        ..cubicTo(175, 108, 166, 137, 148, 147)
        ..cubicTo(136, 155, 116, 155, 98, 155)
        ..close(),
  orange:
      Path()
        ..moveTo(101, 153)
        ..cubicTo(69, 153, 48, 142, 45, 116)
        ..lineTo(57, 123)
        ..cubicTo(55, 106, 67, 92, 67, 76)
        ..cubicTo(78, 85, 81, 97, 80, 106)
        ..cubicTo(90, 89, 87, 70, 102, 56)
        ..cubicTo(109, 48, 113, 43, 115, 37)
        ..cubicTo(120, 52, 106, 76, 112, 87)
        ..cubicTo(117, 95, 132, 78, 135, 66)
        ..cubicTo(146, 83, 135, 101, 133, 115)
        ..lineTo(149, 102)
        ..cubicTo(155, 133, 135, 150, 101, 153)
        ..close(),
  gold:
      Path()
        ..moveTo(99, 151)
        ..cubicTo(78, 151, 66, 143, 62, 122)
        ..lineTo(72, 127)
        ..cubicTo(71, 118, 75, 109, 80, 103)
        ..cubicTo(80, 111, 83, 117, 88, 120)
        ..cubicTo(88, 97, 103, 92, 104, 76)
        ..cubicTo(110, 84, 112, 95, 109, 105)
        ..cubicTo(110, 114, 115, 116, 120, 108)
        ..lineTo(129, 96)
        ..cubicTo(129, 107, 128, 120, 124, 130)
        ..lineTo(135, 123)
        ..cubicTo(130, 142, 116, 151, 99, 151)
        ..close(),
  core:
      Path()
        ..moveTo(99, 149)
        ..cubicTo(87, 146, 82, 138, 88, 129)
        ..lineTo(92, 122)
        ..lineTo(96, 128)
        ..cubicTo(95, 120, 100, 116, 102, 110)
        ..cubicTo(107, 115, 108, 121, 107, 126)
        ..lineTo(116, 121)
        ..cubicTo(119, 134, 112, 145, 99, 149)
        ..close(),
);

final _leftEmber =
    Path()
      ..moveTo(44, 80)
      ..quadraticBezierTo(36, 72, 43, 60)
      ..lineTo(47, 53)
      ..quadraticBezierTo(58, 56, 51, 68)
      ..close();
final _rightEmber =
    Path()
      ..moveTo(143, 38)
      ..quadraticBezierTo(136, 34, 143, 21)
      ..quadraticBezierTo(147, 16, 150, 22)
      ..quadraticBezierTo(150, 29, 143, 38)
      ..close();

final _rearLog =
    Path()
      ..moveTo(21, 154)
      ..lineTo(25, 145)
      ..quadraticBezierTo(26, 141, 32, 142)
      ..lineTo(177, 168)
      ..quadraticBezierTo(183, 170, 179, 177)
      ..lineTo(175, 182)
      ..quadraticBezierTo(174, 185, 168, 184)
      ..lineTo(25, 161)
      ..quadraticBezierTo(19, 160, 21, 154)
      ..close();
final _rearBark =
    Path()
      ..moveTo(27, 152)
      ..lineTo(30, 144)
      ..lineTo(169, 169)
      ..lineTo(172, 175)
      ..close();
final _frontLog =
    Path()
      ..moveTo(18, 171)
      ..quadraticBezierTo(20, 165, 26, 165)
      ..lineTo(168, 138)
      ..quadraticBezierTo(173, 137, 175, 144)
      ..lineTo(178, 151)
      ..quadraticBezierTo(179, 156, 173, 159)
      ..lineTo(32, 186)
      ..quadraticBezierTo(24, 188, 20, 181)
      ..quadraticBezierTo(16, 178, 18, 171)
      ..close();
final _frontBark =
    Path()
      ..moveTo(30, 168)
      ..lineTo(165, 142)
      ..lineTo(169, 149)
      ..lineTo(32, 178)
      ..close();
final _cut =
    Path()
      ..moveTo(20, 169)
      ..quadraticBezierTo(25, 162, 31, 169)
      ..quadraticBezierTo(38, 180, 31, 184)
      ..quadraticBezierTo(23, 188, 19, 180)
      ..quadraticBezierTo(15, 174, 20, 169)
      ..close();
final _grain =
    Path()
      ..moveTo(21, 170)
      ..quadraticBezierTo(28, 170, 30, 179)
      ..quadraticBezierTo(24, 178, 21, 170)
      ..close();

void _paintLogs(Canvas canvas, Paint paint, bool dark) {
  final bark = dark ? const Color(0xFF69434B) : const Color(0xFF57373B);
  final edge = dark ? const Color(0xFFAB7863) : const Color(0xFF422D37);
  for (final (log, highlight, shade) in [
    (_rearLog, _rearBark, const Color(0xFFAA6552)),
    (_frontLog, _frontBark, const Color(0xFFAE7053)),
  ]) {
    canvas.drawPath(log, paint..color = bark);
    canvas.drawPath(
      log,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = edge,
    );
    canvas.drawPath(
      highlight,
      paint
        ..style = PaintingStyle.fill
        ..color = shade,
    );
  }
  canvas.drawPath(_cut, paint..color = const Color(0xFFF8BE79));
  canvas.drawPath(_grain, paint..color = const Color(0xFF90644B));
}

/// Outline of the mature campfire flame, fitted to [rect].
Path flamePath(Rect rect) {
  final shape = _blaze.silhouette;
  final bounds = shape.getBounds();
  final sx = rect.width / bounds.width;
  final sy = rect.height / bounds.height;
  final transform = Matrix4.diagonal3Values(sx, sy, 1)..setTranslationRaw(
    rect.left - bounds.left * sx,
    rect.top - bounds.top * sy,
    0,
  );
  return shape.transform(transform.storage);
}
