import 'package:flutter/material.dart';

/// Лёгкая разлиновка игрового поля в светлой теме.
class PaperRules extends StatelessWidget {
  const PaperRules({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _RulesPainter(
          Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .62),
        ),
      ),
    ),
  );
}

class _RulesPainter extends CustomPainter {
  const _RulesPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = color;
    for (var y = 38.0; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), ink);
    }
  }

  @override
  bool shouldRepaint(_RulesPainter oldDelegate) => color != oldDelegate.color;
}
