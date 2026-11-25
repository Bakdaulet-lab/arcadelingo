/// Artwork for the «Словомат» launcher, in the approved 512-unit view box.
library;

import 'dart:ui';

const cabinetBackdrop = Color(0xFF191B3B);

void paintCabinet(
  Canvas canvas,
  double size, {
  required bool opaque,
  required bool monochrome,
}) {
  const full = Rect.fromLTWH(0, 0, 512, 512);
  canvas.save();
  canvas.scale(size / 512);
  if (opaque) {
    canvas.drawRect(
      full,
      Paint()
        ..shader = Gradient.radial(
          const Offset(228, 200),
          418,
          const [Color(0xFF1E2046), cabinetBackdrop, Color(0xFF12132C)],
          const [0, 0.50, 1],
        ),
    );
    canvas.drawOval(
      const Rect.fromLTWH(145, 379, 255, 28),
      Paint()
        ..color = const Color(0x80101528)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  } else {
    // Android shows the central 72 dp of a 108 dp foreground.
    canvas.translate(256, 256);
    canvas.scale(72 / 108);
    canvas.translate(-256, -256);
  }
  final art = _Cabinet(canvas);
  if (monochrome) {
    canvas.saveLayer(full, Paint());
    art.themed();
    canvas.restore();
  } else {
    art.color();
  }
  canvas.restore();
}

class _Cabinet {
  _Cabinet(this.canvas);
  final Canvas canvas;

  static Path get _silhouette =>
      Path()
        ..moveTo(132, 141)
        ..lineTo(141, 120)
        ..quadraticBezierTo(142, 116, 146, 113)
        ..lineTo(171, 96)
        ..quadraticBezierTo(178, 91, 185, 91)
        ..lineTo(350, 78)
        ..quadraticBezierTo(356, 75, 360, 80)
        ..lineTo(373, 95)
        ..quadraticBezierTo(376, 98, 375, 104)
        ..lineTo(362, 240)
        ..lineTo(384, 267)
        ..quadraticBezierTo(387, 271, 385, 279)
        ..lineTo(381, 292)
        ..lineTo(370, 297)
        ..lineTo(368, 363)
        ..quadraticBezierTo(368, 370, 363, 373)
        ..lineTo(335, 391)
        ..quadraticBezierTo(329, 395, 325, 395)
        ..lineTo(152, 408)
        ..quadraticBezierTo(142, 409, 140, 398)
        ..lineTo(128, 331)
        ..lineTo(122, 310)
        ..quadraticBezierTo(121, 307, 124, 302)
        ..lineTo(139, 274)
        ..quadraticBezierTo(141, 269, 146, 269)
        ..lineTo(132, 151)
        ..quadraticBezierTo(131, 145, 132, 141)
        ..close();

  static Path get _display =>
      Path()
        ..moveTo(154, 146)
        ..lineTo(322, 133)
        ..quadraticBezierTo(332, 132, 331, 142)
        ..lineTo(321, 242)
        ..quadraticBezierTo(320, 249, 314, 250)
        ..lineTo(168, 261)
        ..quadraticBezierTo(161, 262, 160, 255)
        ..lineTo(147, 157)
        ..quadraticBezierTo(146, 148, 154, 146)
        ..close();

  static Path get _letter =>
      Path()
        ..fillType = PathFillType.evenOdd
        ..moveTo(189, 237)
        ..lineTo(217, 169)
        ..lineTo(225, 161)
        ..lineTo(254, 159)
        ..lineTo(261, 165)
        ..lineTo(289.5, 230)
        ..lineTo(264, 231.5)
        ..lineTo(258, 218.5)
        ..lineTo(219, 221)
        ..lineTo(213.5, 235.5)
        ..close()
        ..moveTo(230, 203.5)
        ..lineTo(251.5, 202)
        ..lineTo(241, 176)
        ..close();

  static Path get _coinSlot =>
      Path()
        ..moveTo(224, 353)
        ..lineTo(250, 351)
        ..quadraticBezierTo(254, 351, 252, 357)
        ..lineTo(224, 359)
        ..quadraticBezierTo(221, 359, 222, 355)
        ..quadraticBezierTo(222, 354, 224, 353)
        ..close();

  void _shape(Path path, int rgb) =>
      canvas.drawPath(path, Paint()..color = Color(0xFF000000 | rgb));

  void _face(int rgb, List<Offset> corners) {
    _shape(Path()..addPolygon(corners, true), rgb);
  }

  void _oval(Rect rect, int rgb) =>
      canvas.drawOval(rect, Paint()..color = Color(0xFF000000 | rgb));

  void color() {
    _shape(_silhouette, 0x1a8c8d);
    _face(0x126569, const [
      Offset(344, 131),
      Offset(366, 115),
      Offset(356, 237),
      Offset(339, 254),
    ]);
    _face(0x69e0c6, const [
      Offset(353, 79),
      Offset(373, 98),
      Offset(371, 115),
      Offset(343, 133),
      Offset(329, 101),
    ]);
    _face(0xc7ffe8, const [
      Offset(143, 116),
      Offset(175, 94),
      Offset(184, 92),
      Offset(351, 79),
      Offset(329, 102),
    ]);
    _face(0xa0ffe0, const [
      Offset(135, 135),
      Offset(142, 118),
      Offset(147, 113),
      Offset(329, 100),
      Offset(333, 104),
      Offset(342, 119),
    ]);
    _face(0x43baa9, const [
      Offset(132, 146),
      Offset(135, 134),
      Offset(342, 119),
      Offset(340, 132),
      Offset(137, 149),
    ]);
    _face(0x73f3c9, const [
      Offset(132, 145),
      Offset(137, 148),
      Offset(340, 132),
      Offset(344, 129),
      Offset(334, 256),
      Offset(147, 272),
    ]);
    _shape(_display, 0x104650);
    _shape(
      Path()
        ..moveTo(159, 154)
        ..lineTo(320, 142)
        ..quadraticBezierTo(324, 142, 323, 149)
        ..lineTo(313, 237)
        ..quadraticBezierTo(313, 241, 308, 242)
        ..lineTo(173, 252)
        ..quadraticBezierTo(168, 252, 168, 247)
        ..lineTo(156, 160)
        ..quadraticBezierTo(155, 155, 159, 154)
        ..close(),
      0x122336,
    );
    _face(0x193347, const [
      Offset(160, 155),
      Offset(214, 151),
      Offset(169, 205),
    ]);
    _shape(_letter, 0xedfff3);

    _shape(
      Path()
        ..moveTo(128, 327)
        ..lineTo(349, 307)
        ..lineTo(337, 385)
        ..quadraticBezierTo(336, 393, 328, 395)
        ..lineTo(152, 408)
        ..quadraticBezierTo(142, 409, 140, 398)
        ..close(),
      0x32beac,
    );
    _shape(
      Path()
        ..moveTo(146, 341)
        ..lineTo(327.5, 327)
        ..lineTo(320, 380)
        ..quadraticBezierTo(319, 384, 315, 385)
        ..lineTo(160, 395.5)
        ..quadraticBezierTo(154, 396, 154, 391)
        ..close(),
      0x229f96,
    );
    _face(0x22a99a, const [
      Offset(350, 314),
      Offset(365, 305),
      Offset(363, 360),
      Offset(349, 369),
    ]);
    _shape(
      Path()
        ..moveTo(221, 351)
        ..lineTo(254, 348.5)
        ..quadraticBezierTo(261, 348, 260, 356)
        ..quadraticBezierTo(260, 362, 254, 362.5)
        ..lineTo(220, 365)
        ..quadraticBezierTo(214, 365, 214, 359)
        ..quadraticBezierTo(214, 352, 221, 351)
        ..close(),
      0x137473,
    );
    _shape(_coinSlot, 0x104e55);
    _face(0x13817e, const [
      Offset(125, 321),
      Offset(350, 303),
      Offset(344, 320),
      Offset(129, 336),
    ]);
    _face(0x5fdcc1, const [
      Offset(122, 309),
      Offset(353, 291),
      Offset(348, 307),
      Offset(126, 324),
    ]);
    _face(0x177a7d, const [
      Offset(353, 289),
      Offset(379, 274),
      Offset(376, 291),
      Offset(349, 308),
    ]);
    _face(0x43c7b3, const [
      Offset(341, 255),
      Offset(360, 242),
      Offset(380, 268),
      Offset(353, 287),
    ]);
    _shape(
      Path()
        ..moveTo(146, 269)
        ..lineTo(334, 255)
        ..lineTo(352, 289)
        ..lineTo(350, 294)
        ..lineTo(123, 311)
        ..quadraticBezierTo(120, 309, 124, 302)
        ..lineTo(139, 273)
        ..quadraticBezierTo(141, 269, 146, 269)
        ..close(),
      0xa7ffe0,
    );
    _oval(const Rect.fromLTRB(164, 283, 205, 296), 0x43b49e);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(181, 266, 188.5, 289),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF19485B),
    );
    _oval(const Rect.fromLTRB(171, 251, 195.5, 276), 0xff897b);
    _oval(const Rect.fromLTRB(175, 257, 185, 264.5), 0xffd3a5);
    _oval(const Rect.fromLTRB(266, 274, 292.5, 288.5), 0x177a7d);
    _oval(const Rect.fromLTRB(267, 271.5, 292, 286), 0xff897b);
    _oval(const Rect.fromLTRB(295.5, 267.5, 312.5, 277.5), 0x177a7d);
    _oval(const Rect.fromLTRB(295.5, 266, 312.5, 275.5), 0xffbe9a);
  }

  void themed() {
    _shape(_silhouette, 0xffffff);
    final clear = Paint()..blendMode = BlendMode.clear;
    canvas.drawPath(_display, clear);
    _shape(_letter, 0xffffff);
    // Keep the stick and control shelf readable after the launcher tints the mask.
    canvas.drawOval(const Rect.fromLTRB(166, 251, 195, 279), clear);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(176, 270, 185, 293),
        const Radius.circular(4),
      ),
      clear,
    );
    canvas.drawOval(const Rect.fromLTRB(262, 270, 290, 286), clear);
    const shelf = [
      Offset(136, 314),
      Offset(347, 298),
      Offset(345, 308),
      Offset(138, 325),
    ];
    const slot = [
      Offset(213, 352),
      Offset(262, 348),
      Offset(260, 362),
      Offset(215, 365),
    ];
    canvas.drawPath(Path()..addPolygon(shelf, true), clear);
    canvas.drawPath(Path()..addPolygon(slot, true), clear);
  }
}
