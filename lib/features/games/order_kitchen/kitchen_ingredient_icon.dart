import 'package:arcadelingo/domain/kitchen/kitchen_shift.dart';
import 'package:flutter/material.dart';

/// Small pantry illustrations with the same ink outline as the café counter.
class KitchenIngredientIcon extends StatelessWidget {
  const KitchenIngredientIcon(this.item, {super.key});

  final KitchenIngredient item;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: const Size(35, 31), painter: _PantryPainter(item)),
  );
}

class _PantryPainter extends CustomPainter {
  const _PantryPainter(this.item);
  final KitchenIngredient item;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 36, size.height / 32);
    const ink = Color(0xFF493842);
    const ivory = Color(0xFFFFEDCE);
    const green = Color(0xFF8DC6A7);
    const gold = Color(0xFFF6C573);
    const amber = Color(0xFFD68A44);
    final fill = Paint();
    final pen =
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 1.5;
    void shape(Path path, Color color) {
      canvas.drawPath(path, fill..color = color);
      canvas.drawPath(path, pen);
    }

    void rounded(Rect rect, double radius, Color color) => shape(
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius))),
      color,
    );
    void line(double x, double y, double endX, double endY) =>
        canvas.drawLine(Offset(x, y), Offset(endX, endY), pen);

    switch (item) {
      case KitchenIngredient.coffee:
        shape(Path()..addOval(const Rect.fromLTWH(2, 21, 31, 6)), ivory);
        shape(Path()..addOval(const Rect.fromLTWH(23, 11, 9, 9)), gold);
        shape(
          Path()
            ..moveTo(6, 10)
            ..lineTo(26, 10)
            ..quadraticBezierTo(25, 24, 16, 24)
            ..quadraticBezierTo(7, 23, 6, 10)
            ..close(),
          gold,
        );
        shape(
          Path()..addOval(const Rect.fromLTWH(6, 8, 20, 5)),
          const Color(0xFF815339),
        );
        canvas.drawArc(
          const Rect.fromLTWH(12, 9, 9, 2),
          0,
          2.7,
          false,
          Paint()
            ..color = ivory
            ..style = PaintingStyle.stroke,
        );
      case KitchenIngredient.tea:
        shape(
          Path()
            ..moveTo(8, 8)
            ..lineTo(22, 8)
            ..lineTo(24, 13)
            ..lineTo(24, 28)
            ..lineTo(6, 28)
            ..lineTo(6, 13)
            ..close(),
          ivory,
        );
        line(12, 12, 18, 12);
        canvas.drawPath(
          Path()
            ..moveTo(15, 8)
            ..quadraticBezierTo(18, -1, 27, 6)
            ..lineTo(29, 10),
          pen,
        );
        rounded(const Rect.fromLTWH(25, 10, 8, 7), 1.5, gold);
        shape(
          Path()
            ..moveTo(10, 23)
            ..quadraticBezierTo(9, 16, 20, 16)
            ..quadraticBezierTo(19, 24, 10, 23)
            ..close(),
          green,
        );
      case KitchenIngredient.milk:
        shape(
          Path()
            ..moveTo(13, 6)
            ..lineTo(23, 6)
            ..lineTo(23, 10)
            ..quadraticBezierTo(27, 14, 27, 17)
            ..lineTo(27, 27)
            ..quadraticBezierTo(27, 29, 25, 29)
            ..lineTo(11, 29)
            ..quadraticBezierTo(9, 29, 9, 27)
            ..lineTo(9, 17)
            ..quadraticBezierTo(9, 14, 13, 10)
            ..close(),
          ivory,
        );
        rounded(
          const Rect.fromLTWH(12, 3, 12, 4),
          1.4,
          const Color(0xFF7DABB9),
        );
        rounded(const Rect.fromLTWH(9, 17, 18, 7), 1, green);
      case KitchenIngredient.sugar:
        shape(
          Path()
            ..moveTo(5, 10)
            ..lineTo(17, 5)
            ..lineTo(30, 10)
            ..lineTo(30, 23)
            ..lineTo(18, 28)
            ..lineTo(5, 23)
            ..close(),
          ivory,
        );
        shape(
          Path()
            ..moveTo(18, 15)
            ..lineTo(30, 10)
            ..lineTo(30, 23)
            ..lineTo(18, 28)
            ..close(),
          const Color(0xFFDDBFAF),
        );
        line(5, 10, 18, 15);
        for (final p in const [
          Offset(11, 16),
          Offset(14, 20),
          Offset(9, 21),
          Offset(23, 18),
        ]) {
          canvas.drawCircle(p, .8, fill..color = ink);
        }
      case KitchenIngredient.lemon:
        shape(
          Path()
            ..moveTo(3, 13)
            ..lineTo(32, 8)
            ..quadraticBezierTo(31, 25, 20, 26)
            ..quadraticBezierTo(9, 29, 3, 13)
            ..close(),
          gold,
        );
        shape(
          Path()
            ..moveTo(7, 14)
            ..lineTo(28, 10)
            ..quadraticBezierTo(26, 21, 19, 23)
            ..quadraticBezierTo(11, 25, 7, 14)
            ..close(),
          const Color(0xFFFFE398),
        );
        line(17, 13, 12, 21);
        line(18, 13, 21, 22);
        line(19, 13, 26, 17);
      case KitchenIngredient.honey:
        rounded(const Rect.fromLTWH(7, 10, 22, 19), 5, amber);
        rounded(const Rect.fromLTWH(8, 5, 20, 6), 2, green);
        rounded(const Rect.fromLTWH(8, 16, 20, 8), 1, ivory);
        shape(
          Path()
            ..moveTo(15, 20)
            ..lineTo(17, 17)
            ..lineTo(20, 17)
            ..lineTo(22, 20)
            ..lineTo(20, 23)
            ..lineTo(17, 23)
            ..close(),
          gold,
        );
    }
  }

  @override
  bool shouldRepaint(_PantryPainter oldDelegate) => item != oldDelegate.item;
}
