part of 'match_three_field.dart';

/// Unit-space cuts and their facet paths are shared by every gem of a kind.
/// They stay on their own paint layer when a piece moves or turns to sparks.
class _GemCut {
  _GemCut(this.rim, {required double tableWidth, required double tableHeight}) {
    final inner = [
      for (final p in rim)
        Offset(48 + (p.dx - 50) * tableWidth, 44 + (p.dy - 50) * tableHeight),
    ];
    outline = Path()..addPolygon(rim, true);
    table = Path()..addPolygon(inner, true);
    for (var i = 0; i < rim.length; i++) {
      final next = (i + 1) % rim.length;
      final corners = [rim[i], rim[next], inner[next], inner[i]];
      facets.add(Path()..addPolygon(corners, true));
    }
  }

  final List<Offset> rim;
  late final Path outline;
  late final Path table;
  final facets = <Path>[];
}

List<Offset> _roseCut() => [
  for (var i = 0; i < 12; i++)
    Offset(
      50 + 45 * cos(i * pi / 6 - pi / 2),
      49 + 45 * sin(i * pi / 6 - pi / 2),
    ),
];

final _cuts = <MatchGem, _GemCut>{
  MatchGem.aqua: _GemCut(
    const [Offset(50, 2), Offset(98, 49), Offset(50, 96), Offset(2, 49)],
    tableWidth: .58,
    tableHeight: .57,
  ),
  MatchGem.rose: _GemCut(_roseCut(), tableWidth: .70, tableHeight: .67),
  MatchGem.amber: _GemCut(
    const [
      Offset(29, 7),
      Offset(72, 7),
      Offset(97, 46),
      Offset(74, 88),
      Offset(26, 88),
      Offset(3, 46),
    ],
    tableWidth: .63,
    tableHeight: .54,
  ),
  MatchGem.plum: _GemCut(
    const [
      Offset(47, 1),
      Offset(78, 16),
      Offset(94, 45),
      Offset(78, 77),
      Offset(48, 96),
      Offset(18, 77),
      Offset(6, 46),
      Offset(20, 20),
    ],
    tableWidth: .42,
    tableHeight: .69,
  ),
  MatchGem.mint: _GemCut(
    const [
      Offset(22, 6),
      Offset(76, 6),
      Offset(94, 25),
      Offset(94, 73),
      Offset(76, 91),
      Offset(22, 91),
      Offset(6, 74),
      Offset(6, 24),
    ],
    tableWidth: .67,
    tableHeight: .65,
  ),
  MatchGem.sapphire: _GemCut(
    const [
      Offset(49, 2),
      Offset(94, 64),
      Offset(82, 86),
      Offset(18, 86),
      Offset(6, 65),
    ],
    tableWidth: .56,
    tableHeight: .50,
  ),
  MatchGem.charged: _GemCut(
    [
      for (var i = 0; i < 16; i++)
        const Offset(50, 49) +
            Offset(cos(i * pi / 8 - pi / 2), sin(i * pi / 8 - pi / 2)) *
                (i.isEven ? (i % 4 == 0 ? 48 : 39) : 24),
    ],
    tableWidth: .52,
    tableHeight: .52,
  ),
};

typedef _GemColors = ({Color shine, Color middle, Color shade});

const _jewels = <MatchGem, _GemColors>{
  MatchGem.aqua: (
    shine: Color(0xffc4ffff),
    middle: Color(0xff20cfe5),
    shade: Color(0xff08718b),
  ),
  MatchGem.rose: (
    shine: Color(0xffffd4e3),
    middle: Color(0xfff55a99),
    shade: Color(0xff9a275a),
  ),
  MatchGem.amber: (
    shine: Color(0xffffe8a9),
    middle: Color(0xffffab38),
    shade: Color(0xffa75219),
  ),
  MatchGem.plum: (
    shine: Color(0xffead9ff),
    middle: Color(0xffaa76f5),
    shade: Color(0xff5d3a98),
  ),
  MatchGem.mint: (
    shine: Color(0xffc8ffca),
    middle: Color(0xff46d897),
    shade: Color(0xff167250),
  ),
  MatchGem.sapphire: (
    shine: Color(0xffcfddff),
    middle: Color(0xff6697fa),
    shade: Color(0xff334b97),
  ),
  MatchGem.charged: (
    shine: Color(0xfffffff0),
    middle: Color(0xffffcc53),
    shade: Color(0xffb96818),
  ),
};

class _GemPainter extends CustomPainter {
  const _GemPainter(this.gem, {required this.paper, required this.cross});

  final MatchGem gem;
  final bool paper;
  final bool cross;

  @override
  void paint(Canvas canvas, Size size) {
    final cut = _cuts[gem]!;
    final colors = _jewels[gem]!;
    final paint = Paint()..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    canvas.drawOval(
      const Rect.fromLTWH(10, 82, 80, 13),
      paint..color = paper ? const Color(0x24804b23) : const Color(0x55221c37),
    );
    canvas.save();
    canvas.translate(0, 3);
    canvas.drawPath(cut.outline, paint..color = colors.shade);
    canvas.restore();
    canvas.drawPath(cut.outline, paint..color = colors.middle);
    final faces = <Color>[
      colors.shine,
      Color.lerp(colors.middle, colors.shine, .39)!,
      Color.lerp(colors.middle, colors.shade, .18)!,
      colors.shade,
      Color.lerp(colors.middle, colors.shade, .72)!,
      Color.lerp(colors.middle, colors.shine, .2)!,
    ];
    for (var i = 0; i < cut.facets.length; i++) {
      final normal = (i + .5) / cut.facets.length;
      final face =
          faces[((normal + .19) * faces.length).floor() % faces.length];
      canvas.drawPath(cut.facets[i], paint..color = face);
    }
    const area = Rect.fromLTWH(13, 11, 76, 75);
    canvas.drawPath(
      cut.table,
      paint
        ..color = Colors.white
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(colors.shine, colors.middle, .36)!,
            colors.middle,
            Color.lerp(colors.middle, colors.shade, .27)!,
          ],
        ).createShader(area),
    );
    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = paper ? 2.2 : 1.5
      ..color =
          Color.lerp(
            colors.shade,
            paper ? const Color(0xff4d3022) : colors.shine,
            paper ? .43 : .48,
          )!;
    canvas.drawPath(cut.outline, paint);
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: .8);
    if (gem == MatchGem.charged) {
      final ink =
          paint
            ..color = const Color(0xff854426)
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 5;
      canvas.drawLine(const Offset(35, 48), const Offset(65, 48), ink);
      if (cross) {
        canvas.drawLine(const Offset(50, 33), const Offset(50, 63), ink);
      }
      canvas.drawCircle(const Offset(50, 48), 3, paint..color = colors.shine);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(32, 27, 12, 3),
          const Radius.circular(2),
        ),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GemPainter old) =>
      gem != old.gem || paper != old.paper || cross != old.cross;
}
