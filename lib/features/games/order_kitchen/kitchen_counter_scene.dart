import 'dart:math' as math;

import 'package:arcadelingo/domain/kitchen/kitchen_shift.dart';
import 'package:flutter/material.dart';

/// A café diorama. The set is painted once; only the guest and the drink move.
class KitchenCounterScene extends StatefulWidget {
  const KitchenCounterScene({
    super.key,
    required this.selected,
    required this.guestIndex,
    required this.served,
    required this.mistake,
  });

  final Set<KitchenIngredient> selected;
  final int guestIndex;
  final bool served;
  final bool mistake;

  @override
  State<KitchenCounterScene> createState() => _KitchenCounterSceneState();
}

class _KitchenCounterSceneState extends State<KitchenCounterScene>
    with TickerProviderStateMixin {
  late final _blend = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );
  late final _ambience = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  );
  late final _arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    value: 1,
  );
  late final _repaint = Listenable.merge([_blend, _ambience, _arrival]);

  late List<double> _to = _ingredients(widget.selected);
  late List<double> _from = List.of(_to);
  late int _oldGuest = widget.guestIndex;
  bool? _animate;

  List<double> _ingredients(Set<KitchenIngredient> value) => [
    for (final ingredient in KitchenIngredient.values)
      value.contains(ingredient) ? 1.0 : 0.0,
    widget.served ? 1.0 : 0.0,
    widget.mistake ? 1.0 : 0.0,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate =
        !MediaQuery.disableAnimationsOf(context) && TickerMode.of(context);
    if (animate == _animate) return;
    _animate = animate;
    if (animate) {
      _ambience.forward(from: 0);
    } else {
      _blend.value = 1;
      _arrival.value = 1;
      _ambience.value = 1;
    }
  }

  @override
  void didUpdateWidget(KitchenCounterScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _ingredients(widget.selected);
    final guestChanged = oldWidget.guestIndex != widget.guestIndex;
    final changed = next.indexed.any((entry) => entry.$2 != _to[entry.$1]);
    if (guestChanged) {
      _oldGuest = oldWidget.guestIndex;
      if (_animate == true) _arrival.forward(from: 0);
    }
    if (changed) {
      final t = Curves.easeOutCubic.transform(_blend.value);
      _from = List.generate(
        next.length,
        (i) => _from[i] + (_to[i] - _from[i]) * t,
      );
      _to = next;
      if (_animate == true) _blend.forward(from: 0);
    }
    // Steam and blinking settle between gestures, leaving an idle counter
    // entirely still when someone wants time to read.
    if ((changed || guestChanged) && _animate == true) {
      _ambience.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _blend.dispose();
    _ambience.dispose();
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 2,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(child: CustomPaint(painter: _CafeSet(night))),
              RepaintBoundary(
                child: CustomPaint(
                  painter: _CafeAction(
                    night: night,
                    from: _from,
                    to: _to,
                    guest: widget.guestIndex,
                    oldGuest: _oldGuest,
                    blend: _blend,
                    ambience: _ambience,
                    arrival: _arrival,
                    repaint: _repaint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _ink = Color(0xff302a33);
const _cream = Color(0xffffefd2);
const _gold = Color(0xffffc677);
const _mint = Color(0xff8fdbbc);
const _coral = Color(0xffe88871);
const _wood = Color(0xffae7259);
const _espresso = Color(0xff50362f);

Paint _paint(Color color) => Paint()..color = color;
Paint _stroke(Color color, double width) =>
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

void _line(
  Canvas c,
  double x1,
  double y1,
  double x2,
  double y2,
  Color ink,
  double width,
) => c.drawLine(Offset(x1, y1), Offset(x2, y2), _stroke(ink, width));
void _box(Canvas c, Rect rect, Color color, [double radius = 0]) => c.drawRRect(
  RRect.fromRectAndRadius(rect, Radius.circular(radius)),
  _paint(color),
);
void _oval(Canvas c, double x, double y, double w, double h, Color color) =>
    c.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: w, height: h),
      _paint(color),
    );
void _shape(Canvas c, Path path, Color fill, [Color? edge]) {
  c.drawPath(path, _paint(fill));
  if (edge != null) c.drawPath(path, _stroke(edge, 1.8));
}

void _star(Canvas c, double x, double y, double r, Color color) {
  final path =
      Path()
        ..moveTo(x, y - r)
        ..quadraticBezierTo(x + r * .15, y - r * .14, x + r * .75, y)
        ..quadraticBezierTo(x + r * .15, y + r * .14, x, y + r)
        ..quadraticBezierTo(x - r * .15, y + r * .14, x - r * .75, y)
        ..quadraticBezierTo(x - r * .15, y - r * .14, x, y - r)
        ..close();
  c.drawPath(path, _paint(color));
}

class _CafeSet extends CustomPainter {
  const _CafeSet(this.night);
  final bool night;

  @override
  void paint(Canvas canvas, Size size) {
    final c = canvas;
    c.save();
    c.scale(size.width / 400, size.height / 200);
    final wall = night ? const Color(0xff343249) : const Color(0xffead2ab);
    final tile = night ? const Color(0xff484456) : const Color(0xffdcc49f);
    _box(c, const Rect.fromLTWH(0, 0, 400, 200), wall);
    for (var column = 0; column <= 14; column++) {
      final x = column * 30.0;
      _line(c, x, 50, x, 128, tile, .9);
    }
    for (var i = 0; i < 3; i++) {
      _line(c, 0, 55 + i * 24, 400, 55 + i * 24, tile, .9);
    }
    _window(c);
    _lamp(c, 213, 12);
    _espressoMachine(c);

    // A broad terrazzo counter anchors the cup. The line work is static.
    final counter = night ? const Color(0xff577168) : const Color(0xffe7bb8a);
    _box(c, const Rect.fromLTWH(0, 128, 400, 72), counter);
    _line(c, 0, 128, 400, 128, _ink, 2.6);
    _line(c, 0, 132, 400, 132, night ? const Color(0xff8b9c85) : _cream, 1);
    for (var n = 0; n < 36; n++) {
      final x = ((n * 89 + 7) % 400).toDouble();
      final y = ((n * 13 + 2) % 44).toDouble() + 138;
      _line(
        c,
        x,
        y,
        x + 2 + n % 4,
        y - .5,
        counter.withLightness(n.isEven ? .08 : -.08),
        1.3,
      );
    }
    final apron = night ? const Color(0xff294946) : const Color(0xff985d4e);
    _box(c, const Rect.fromLTWH(0, 185, 400, 15), apron);
    _line(c, 0, 185, 400, 185, _ink, 2.2);
    _line(
      c,
      0,
      190,
      400,
      190,
      night ? const Color(0xff7ea090) : const Color(0xffedbd8c),
      1,
    );
    _bell(c);
    c.restore();
  }

  void _window(Canvas c) {
    const rect = Rect.fromLTWH(-19, -22, 181, 139);
    final arch = RRect.fromRectAndRadius(rect, const Radius.circular(45));
    c.drawRRect(arch, _paint(_ink));
    final glass = RRect.fromRectAndRadius(
      rect.deflate(5),
      const Radius.circular(40),
    );
    c.save();
    c.clipRRect(glass);
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors:
              night
                  ? const [Color(0xff222d49), Color(0xff68738e)]
                  : const [Color(0xff8cc2bb), Color(0xffffdfb1)],
        ).createShader(rect),
    );
    _oval(c, 35, 35, 21, 21, night ? _cream : const Color(0xffffe6ae));
    if (night) {
      _oval(c, 39, 31, 18, 18, const Color(0xff303c55));
      for (final p in const [
        Offset(59, 22),
        Offset(103, 36),
        Offset(17, 53),
        Offset(75, 12),
      ]) {
        _star(c, p.dx, p.dy, 2.2, _cream);
      }
    } else {
      _oval(c, 113, 33, 36, 4, const Color(0xffffe4bc));
      _oval(c, 123, 31, 19, 5, const Color(0xffffe4bc));
    }
    for (var n = 0; n < 8; n++) {
      final x = n * 24.0 - 12;
      final y = 73.0 - (n * 17) % 21;
      final silhouette =
          night ? const Color(0xff45536a) : const Color(0xffa8b7a1);
      _box(c, Rect.fromLTWH(x, y, 22, 50), silhouette);
      _line(c, x - 1, y, x + 23, y, silhouette, 2);
      for (var k = 0; k < 2; k++) {
        _box(
          c,
          Rect.fromLTWH(x + 4 + k * 9, y + 6, 3, 6),
          night ? const Color(0xffbca68e) : const Color(0xffc0c2a8),
        );
      }
    }
    final mullion = night ? const Color(0xff657165) : const Color(0xff8e8371);
    _line(c, 70, 0, 70, 118, mullion, 3);
    _line(c, 0, 52, 165, 52, mullion, 2.4);
    c.restore();
    _box(c, const Rect.fromLTWH(0, 115, 163, 4), _wood, 2);
  }

  void _lamp(Canvas c, double x, double shift) {
    c.save();
    c.translate(x, shift);
    _line(c, 0, -14, 0, 6, _ink, 2);
    final glow = Rect.fromCenter(
      center: const Offset(0, 21),
      width: 96,
      height: 90,
    );
    c.drawOval(
      glow,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _gold.withValues(alpha: night ? .22 : .17),
            _gold.withValues(alpha: 0),
          ],
        ).createShader(glow),
    );
    _shape(
      c,
      Path()
        ..moveTo(-17, 22)
        ..quadraticBezierTo(-13, 12, -4, 9)
        ..lineTo(-3, 6)
        ..lineTo(3, 6)
        ..lineTo(4, 9)
        ..quadraticBezierTo(13, 12, 17, 22)
        ..close(),
      night ? _mint : const Color(0xff777f68),
      _ink,
    );
    _oval(c, 0, 22, 31, 4, _gold);
    c.restore();
  }

  void _espressoMachine(Canvas c) {
    final enamel = night ? const Color(0xff849d95) : const Color(0xff9cafa2);
    _box(c, const Rect.fromLTWH(285, 54, 125, 4), _wood, 2);
    // A pair of upside-down cups and saucers on the warming shelf.
    for (var n = 0; n < 2; n++) {
      final x = 314.0 + n * 35;
      final glaze = n == 0 ? _cream : _coral;
      c.drawOval(Rect.fromLTWH(x + 11, 44, 9, 7), _stroke(glaze, 2.5));
      _box(c, Rect.fromLTWH(x, 40, 15, 12), glaze, 4);
      _line(c, x - 3, 52, x + 18, 52, glaze, 1.5);
    }
    _box(c, const Rect.fromLTWH(303, 66, 81, 60), _ink, 6);
    _box(c, const Rect.fromLTWH(305, 68, 77, 54), enamel, 5);
    _box(
      c,
      const Rect.fromLTWH(308, 92, 71, 28),
      night ? const Color(0xff404349) : const Color(0xff685c55),
      3,
    );
    _line(c, 307, 88, 380, 88, _ink, 1.4);
    _oval(c, 320, 78, 12, 12, _ink);
    _oval(c, 320, 78, 9, 9, _cream);
    _line(c, 320, 78, 322, 75, _ink, 1);
    _oval(c, 365, 77, 5, 5, _coral);
    _oval(c, 374, 77, 5, 5, _gold);
    _box(c, const Rect.fromLTWH(333, 91, 15, 5), _ink, 1.5);
    _line(c, 343, 95, 354, 97, _ink, 3);
    _box(c, const Rect.fromLTWH(333, 106, 15, 13), _cream, 3);
    c.drawOval(const Rect.fromLTWH(345, 108, 8, 7), _stroke(_cream, 2));
    _box(c, const Rect.fromLTWH(301, 120, 85, 7), _ink, 2);
    _line(c, 305, 123, 382, 123, enamel, 1.5);
  }

  void _bell(Canvas c) {
    _oval(c, 358, 157, 36, 6, _ink.withValues(alpha: .16));
    _box(c, const Rect.fromLTWH(340, 152, 33, 4), _ink, 2);
    _shape(
      c,
      Path()
        ..moveTo(343, 151)
        ..quadraticBezierTo(344, 140, 356, 140)
        ..quadraticBezierTo(368, 140, 370, 151)
        ..close(),
      _gold,
      _ink,
    );
    _line(c, 356.5, 140, 356.5, 137, _ink, 2.1);
    _line(c, 354, 137, 359, 137, _ink, 2);
    _line(c, 346, 148, 350, 144, _cream, 1.7);
  }

  @override
  bool shouldRepaint(_CafeSet oldDelegate) => oldDelegate.night != night;
}

extension on Color {
  Color withLightness(double delta) {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness + delta).clamp(0, 1)).toColor();
  }
}

typedef _GuestPalette = ({Color skin, Color hair, Color shirt});
const _guests = <_GuestPalette>[
  (skin: Color(0xffd89770), hair: Color(0xff4a3445), shirt: Color(0xff88c8b1)),
  (skin: Color(0xfff0b58d), hair: Color(0xff665257), shirt: Color(0xffc2a1d0)),
  (skin: Color(0xffa66b53), hair: Color(0xff392e38), shirt: Color(0xffe7ae69)),
  (skin: Color(0xfff2bd9b), hair: Color(0xff9a5544), shirt: Color(0xff74afbd)),
  (skin: Color(0xffbd8061), hair: Color(0xff4e4055), shirt: Color(0xffe38975)),
];

class _CafeAction extends CustomPainter {
  _CafeAction({
    required this.night,
    required this.from,
    required this.to,
    required this.guest,
    required this.oldGuest,
    required this.blend,
    required this.ambience,
    required this.arrival,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final bool night;
  final List<double> from, to;
  final int guest, oldGuest;
  final Animation<double> blend, ambience, arrival;

  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 400, size.height / 200);
    final t = Curves.easeOutCubic.transform(blend.value);
    double mix(int i) => from[i] + (to[i] - from[i]) * t;
    final served = mix(KitchenIngredient.values.length);
    final mistake = mix(KitchenIngredient.values.length + 1);
    final time = ambience.value;
    final ease = Curves.easeInOutCubic.transform(arrival.value);
    // The queue moves left to right behind the counter; it ends at the machine.
    c.save();
    c.clipRect(const Rect.fromLTRB(0, 0, 236, 128));
    if (ease < 1 && oldGuest != guest) {
      _person(c, oldGuest, 109 + ease * 175, 75.0 - ease * 2, 0, 0, 1);
    }
    _person(
      c,
      guest,
      109 - (1 - ease) * 174,
      75 + served * 2,
      mistake,
      served,
      time,
    );
    c.restore();
    _cup(c, mix, served, time);
    if (served > 0) _thanks(c, served, time);
    c.restore();
  }

  void _person(
    Canvas c,
    int n,
    double x,
    double y,
    double mistake,
    double served,
    double time,
  ) {
    final style = n % _guests.length;
    final palette = _guests[style];
    final skin = palette.skin, hair = palette.hair, shirt = palette.shirt;
    c.save();
    c.translate(x, y);
    // Coat, striped collar and neck are behind the face.
    final shoulders =
        Path()
          ..moveTo(-45, 62)
          ..quadraticBezierTo(-44, 39, -28, 31)
          ..lineTo(-12, 25)
          ..lineTo(12, 25)
          ..lineTo(30, 32)
          ..quadraticBezierTo(42, 38, 47, 62)
          ..close();
    _shape(c, shoulders, shirt, _ink);
    c.save();
    c.clipPath(shoulders);
    if (style.isEven) {
      for (var i = 0; i < 3; i++) {
        _line(
          c,
          -44,
          42 + i * 7,
          47,
          49 + i * 7,
          shirt.withLightness(-.11),
          2.4,
        );
      }
    } else {
      _line(c, -22, 32, -16, 56, shirt.withLightness(-.15), 3.3);
      _line(c, 24, 32, 13, 56, shirt.withLightness(-.15), 3.3);
      _line(c, -16, 53, 13, 53, shirt.withLightness(-.15), 3.3);
    }
    c.restore();
    _shape(
      c,
      Path()
        ..moveTo(-11, 15)
        ..lineTo(-11, 27)
        ..quadraticBezierTo(-8, 39, 3, 38)
        ..quadraticBezierTo(12, 35, 13, 26)
        ..lineTo(10, 14)
        ..close(),
      skin,
      _ink,
    );
    c.save();
    c.translate(
      served * 1.4,
      math.sin(time * math.pi * 2) * 1.1 + served * 1.6,
    );
    c.rotate(-.045 + mistake * -.085 + served * .075);
    if (style == 1 || style == 3) {
      _oval(c, -16, -19, 39, 49, hair);
      _oval(c, 18, -14, 27, 46, hair);
    }
    _oval(c, -22, 0, 13, 17, _ink);
    _oval(c, -21.6, 0, 10.6, 14, skin);
    _shape(
      c,
      Path()
        ..moveTo(-21, -22)
        ..quadraticBezierTo(-9, -38, 8, -32)
        ..quadraticBezierTo(27, -28, 24, -8)
        ..lineTo(23, 9)
        ..quadraticBezierTo(21, 27, 6, 29)
        ..quadraticBezierTo(-10, 30, -18, 16)
        ..quadraticBezierTo(-24, 6, -21, -22)
        ..close(),
      skin,
      _ink,
    );
    _hair(c, style, hair);

    final brow = _stroke(hair, 2);
    c.drawPath(
      Path()
        ..moveTo(-10, -5 - mistake * 2)
        ..quadraticBezierTo(-6, -8 - mistake * 3, -2, -6),
      brow,
    );
    c.drawPath(
      Path()
        ..moveTo(12, -7)
        ..quadraticBezierTo(16, -9 + mistake * 2, 19, -7 + mistake * 2),
      brow,
    );
    final blink = (1 - (time - .51).abs() * 26).clamp(0.0, 1.0);
    final eyeH = (4.3 * (1 - blink) * (1 - served)).clamp(.95, 4.3);
    if (served > .55) {
      c.drawPath(
        Path()
          ..moveTo(-9, 2)
          ..quadraticBezierTo(-6, -2, -3, 2),
        _stroke(_ink, 1.8),
      );
      c.drawPath(
        Path()
          ..moveTo(13, 0)
          ..quadraticBezierTo(16, -4, 19, 0),
        _stroke(_ink, 1.8),
      );
    } else {
      _oval(c, -5.5, 1, 2.9, eyeH, _ink);
      _oval(c, 16, -1, 2.9, eyeH, _ink);
    }
    if (style == 1 || style == 4) {
      for (final eye in const [Offset(-6, 1), Offset(15, -1)]) {
        c.drawOval(
          Rect.fromCenter(center: eye, width: 15, height: 12),
          _stroke(_ink, 1.5),
        );
      }
      _line(c, 1, 0, 7, -1, _ink, 1.3);
      _line(c, -14, 0, -21, -2, _ink, 1.3);
    }
    c.drawPath(
      Path()
        ..moveTo(7, 1)
        ..lineTo(9, 6)
        ..quadraticBezierTo(8, 8, 5, 7),
      _stroke(skin.withLightness(-.19), 1.4),
    );
    _oval(c, -12, 9, 8, 3.3, _coral.withValues(alpha: .68));
    c.drawPath(
      Path()
        ..moveTo(0, 14)
        ..quadraticBezierTo(
          6,
          19 + served * 4 - mistake * 7,
          13,
          12 + mistake * 2,
        ),
      _stroke(_ink, 1.8),
    );
    if (style == 0 || style == 3) {
      c.drawCircle(const Offset(-21, 8), 2.1, _paint(_gold));
    }
    c.restore();
    c.restore();
  }

  void _hair(Canvas c, int style, Color hair) {
    switch (style) {
      case 0:
        // Swept fringe and felt beret.
        _shape(
          c,
          Path()
            ..moveTo(-24, 2)
            ..quadraticBezierTo(-34, -27, -13, -36)
            ..quadraticBezierTo(18, -45, 26, -17)
            ..quadraticBezierTo(19, -23, 13, -23)
            ..quadraticBezierTo(3, -9, -14, -12)
            ..lineTo(-18, 0)
            ..close(),
          hair,
          _ink,
        );
        _shape(
          c,
          Path()
            ..moveTo(-29, -20)
            ..cubicTo(-39, -31, -21, -43, -7, -44)
            ..cubicTo(8, -47, 27, -38, 25, -31)
            ..lineTo(16, -27)
            ..quadraticBezierTo(-8, -32, -24, -18)
            ..close(),
          _coral,
          _ink,
        );
        _line(c, -6, -44, -5, -48, _ink, 2.6);
      case 1:
        _oval(c, -18, -36, 28, 26, _ink);
        _oval(c, -18, -36, 25, 23, hair);
        _shape(
          c,
          Path()
            ..moveTo(-23, 0)
            ..cubicTo(-33, -28, -13, -40, 4, -37)
            ..quadraticBezierTo(23, -36, 26, -13)
            ..quadraticBezierTo(15, -13, 6, -25)
            ..quadraticBezierTo(-4, -12, -16, -12)
            ..lineTo(-20, 0)
            ..close(),
          hair,
          _ink,
        );
        c.drawPath(
          Path()
            ..moveTo(-20, -18)
            ..quadraticBezierTo(-12, -23, -7, -31),
          _stroke(const Color(0xffb0a0a0), 1.8),
        );
      case 2:
        _shape(
          c,
          Path()
            ..moveTo(-25, 2)
            ..quadraticBezierTo(-32, -11, -27, -26)
            ..quadraticBezierTo(-20, -38, 0, -39)
            ..quadraticBezierTo(23, -39, 25, -16)
            ..lineTo(17, -13)
            ..quadraticBezierTo(1, -19, -14, -9)
            ..lineTo(-19, 1)
            ..close(),
          hair,
          _ink,
        );
        for (final p in const [
          Offset(-23, -23),
          Offset(-16, -33),
          Offset(-3, -36),
          Offset(11, -33),
          Offset(20, -24),
        ]) {
          c.drawCircle(p, 9, _paint(hair));
        }
      case 3:
        _shape(
          c,
          Path()
            ..moveTo(-22, -30)
            ..quadraticBezierTo(3, -48, 22, -25)
            ..lineTo(23, -13)
            ..quadraticBezierTo(15, -13, 6, -22)
            ..quadraticBezierTo(-7, -10, -18, -11)
            ..lineTo(-22, 0)
            ..close(),
          hair,
          _ink,
        );
        _shape(
          c,
          Path()
            ..moveTo(-26, -24)
            ..quadraticBezierTo(-25, -45, -8, -48)
            ..quadraticBezierTo(12, -51, 21, -33)
            ..lineTo(21, -28)
            ..quadraticBezierTo(-1, -35, -26, -19)
            ..close(),
          _gold,
          _ink,
        );
        c.drawPath(
          Path()
            ..moveTo(-25, -22)
            ..quadraticBezierTo(-1, -37, 21, -30),
          _stroke(_espresso, 2.4),
        );
      default:
        _shape(
          c,
          Path()
            ..moveTo(-24, 1)
            ..cubicTo(-34, -21, -18, -36, -3, -37)
            ..cubicTo(6, -39, 22, -48, 26, -37)
            ..quadraticBezierTo(30, -21, 12, -19)
            ..quadraticBezierTo(0, -16, -15, -14)
            ..lineTo(-20, 1)
            ..close(),
          hair,
          _ink,
        );
        c.drawPath(
          Path()
            ..moveTo(-20, -22)
            ..quadraticBezierTo(-12, -29, -2, -29),
          _stroke(_wood, 1.7),
        );
    }
  }

  void _cup(Canvas c, double Function(int) mix, double served, double time) {
    double part(KitchenIngredient ingredient) => mix(ingredient.index);
    final coffee = part(KitchenIngredient.coffee),
        tea = part(KitchenIngredient.tea);
    final milk = part(KitchenIngredient.milk),
        lemon = part(KitchenIngredient.lemon);
    final sugar = part(KitchenIngredient.sugar),
        honey = part(KitchenIngredient.honey);
    final base = math.max(coffee, tea);
    final amount = (base * .72 + milk * .22 + sugar * .04 + honey * .08).clamp(
      0.0,
      .98,
    );
    final slide = Curves.easeInOut.transform(served);
    c.save();
    c.translate(243 - 48 * slide, 150 - 14 * slide);
    c.scale(1 - .09 * slide);
    _oval(c, 2, 22, 101, 12, _ink.withValues(alpha: night ? .38 : .19));
    _oval(c, 0, 18, 102, 13, _ink);
    _oval(c, 0, 16.8, 101, 12, _cream);
    _oval(
      c,
      0,
      16.2,
      80,
      7,
      night ? const Color(0xffa8c5b2) : const Color(0xffdbb99c),
    );
    final glass = night ? const Color(0xffc5dac9) : const Color(0xfff6e3c4);
    final handle =
        Path()
          ..moveTo(27, -19)
          ..cubicTo(53, -30, 57, -2, 32, 2);
    c.drawPath(handle, _stroke(_ink, 8.8));
    c.drawPath(handle, _stroke(glass, 5.2));
    final body =
        Path()
          ..moveTo(-32, -24)
          ..quadraticBezierTo(-31, 5, -20, 12)
          ..quadraticBezierTo(-1, 20, 20, 12)
          ..quadraticBezierTo(30, 5, 32, -24)
          ..quadraticBezierTo(0, -31, -32, -24)
          ..close();
    _shape(c, body, glass, _ink);
    c.save();
    c.clipPath(body);
    final top = 12 - amount * 39;
    var drink = Color.lerp(const Color(0xffd98334), _espresso, coffee)!;
    drink =
        Color.lerp(
          drink,
          const Color(0xffffdeb1),
          milk * (base > .01 ? .68 : 1),
        )!;
    drink =
        Color.lerp(
          drink,
          const Color(0xffbd792c),
          honey * (1 - milk * .75) * .35,
        )!;
    if (amount > .001) {
      _box(c, Rect.fromLTRB(-33, top, 33, 17), drink);
      _oval(c, 0, top, 66, 7, Color.lerp(drink, _gold, .26)!);
      if (milk > .05 && base > .05) {
        c.drawPath(
          Path()
            ..moveTo(-14, top)
            ..cubicTo(-6, top - 3, 13, top - 1, 6, top + 1)
            ..quadraticBezierTo(0, top + 2, -1, top + 1),
          _stroke(_cream.withValues(alpha: milk * .94), 1.8),
        );
      }
    }
    c.drawPath(
      Path()
        ..moveTo(-26, -19)
        ..quadraticBezierTo(-25, -4, -21, 2),
      _stroke(Colors.white.withValues(alpha: .64), 2.8),
    );
    _line(c, 21, -11, 20, -6, Colors.white.withValues(alpha: .51), 1.5);
    c.restore();
    c.drawOval(const Rect.fromLTWH(-32, -28, 64, 8), _stroke(_ink, 1.6));
    c.drawArc(
      const Rect.fromLTWH(-31, -27, 62, 7),
      0,
      math.pi,
      false,
      _stroke(_cream, 2.3),
    );
    if (tea > .01) {
      c.drawPath(
        Path()
          ..moveTo(16, -25)
          ..quadraticBezierTo(24, -26, 23, -11),
        _stroke(_espresso.withValues(alpha: tea), 1.1),
      );
      c.save();
      c.translate(23, -8);
      c.rotate(-.12);
      _box(
        c,
        const Rect.fromLTWH(-4, -4, 8, 8),
        _mint.withValues(alpha: tea),
        1,
      );
      _line(c, -1.5, 0, 1.5, 0, _ink.withValues(alpha: tea), 1);
      c.restore();
    }
    if (lemon > .01) {
      c.save();
      c.translate(-22, -25);
      c.scale(lemon);
      c.rotate(-.55);
      const rect = Rect.fromLTWH(-11, -11, 22, 22);
      c.drawArc(rect, math.pi, math.pi, true, _paint(_gold));
      c.drawArc(rect, math.pi, math.pi, true, _stroke(_espresso, 1.1));
      for (final angle in const [-2.6, -1.6, -.6]) {
        _line(c, 0, -1, math.cos(angle) * 8, math.sin(angle) * 8, _cream, 1.2);
      }
      c.restore();
    }
    if (sugar > .01) {
      _box(
        c,
        const Rect.fromLTWH(-40, 9, 7, 6),
        _cream.withValues(alpha: sugar),
        1.2,
      );
      _line(c, -39, 10, -35, 10, Colors.white.withValues(alpha: sugar), 1.3);
    }
    if (honey > .01) {
      c.save();
      c.rotate(-.25);
      _line(c, 12, -26, 25, -42, _wood.withValues(alpha: honey), 2.2);
      _oval(c, 26, -43, 9, 7, _gold.withValues(alpha: honey));
      _line(c, 24, -45, 27, -41, _wood.withValues(alpha: honey), 1.2);
      c.restore();
    }
    if (base > .01) {
      final ink = (night ? _cream : _espresso).withValues(
        alpha: base * (night ? .59 : .43),
      );
      for (var i = 0; i < 2; i++) {
        final x = -8 + i * 14.0;
        final wave = math.sin(2 * math.pi * time + i * .8) * 2.8;
        c.drawPath(
          Path()
            ..moveTo(x, -31)
            ..cubicTo(
              x - 6 + wave,
              -37,
              x + 6 + wave,
              -40,
              x + wave,
              -46 - i * 4,
            ),
          _stroke(ink, 1.6),
        );
      }
    }
    c.restore();
  }

  void _thanks(Canvas c, double amount, double time) {
    c.save();
    c.translate(151, 48 - 4 * amount - 2 * math.sin(time * math.pi));
    c.scale(Curves.easeOutBack.transform(amount));
    final heart =
        Path()
          ..moveTo(0, 6)
          ..cubicTo(-15, -3, -7, -12, 0, -6)
          ..cubicTo(7, -14, 16, -6, 0, 6)
          ..close();
    _shape(c, heart, _coral, _ink);
    _star(c, 12, 1, 3.4, _gold);
    c.restore();
  }

  @override
  bool shouldRepaint(_CafeAction old) =>
      old.night != night ||
      old.guest != guest ||
      old.oldGuest != oldGuest ||
      old.from != from ||
      old.to != to;
}
