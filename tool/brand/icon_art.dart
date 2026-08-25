/// Рисунок иконки лаунчера. Только геометрия — файлы пишет
/// `tool/brand/render_icons.dart`.
///
/// Цвета берутся из `lib/ui/theme.dart`, а не переписываются сюда числами.
/// Иконка и экран обязаны быть одного цвета, а вторая копия `#0D0A12`
/// разъехалась бы с первой молча: иконку никто не пересматривает при смене
/// палитры.
///
/// Три варианта — три способа сказать «падает», а не три оттенка одного:
/// блок с вырезанной буквой, стробоскопический след, луч-градиент. Общего у
/// них ровно одно — мятная полоса пола внизу: у падения в игре пола пока нет
/// (задача Р3), а в иконке он есть намеренно, потому что без пола падение
/// читается как «висит».
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

/// Фон: тот же `surface`, что у экрана игры.
final Color brandSurface = wordarcadeColors.surface;

/// Акцент: тот же `primary`.
final Color brandMint = wordarcadeColors.primary;

/// Буква марки. Одна, потому что иконка размером 48 dp — это силуэт.
const String brandGlyph = 'A';

/// Вес по оси `wght`. На Rubik обычный `fontWeight` не работает
/// (см. `withWeight` в теме), поэтому ось задаётся явно.
const double brandWeight = 800;

/// Варианты на выбор автора.
enum BrandIcon {
  /// Мятная плашка с вырезанной буквой, две «линии скорости» сверху.
  block,

  /// Буква и два её затухающих следа выше — стробоскоп.
  trail,

  /// Буква в мятном луче-градиенте: цитата комбо-тона из SPEC.
  beam,
}

/// Слой, для которого рисуем. От него зависит и масштаб, и прозрачность.
enum IconLayer {
  /// Весь квадрат: `mipmap/ic_launcher.png` и все иконки iOS.
  ///
  /// Кропа нет, поэтому рисунок занимает 86% — запас под скругление, которое
  /// лаунчер накладывает сам.
  legacy(artScale: 0.86, opaque: true),

  /// Передний слой адаптивной иконки: холст 108 dp, гарантированно видна
  /// внутренняя окружность 66 dp. 66/108 = 0.61; берём 0.66 — ровно
  /// внутренний квадрат 72 dp, обычный компромисс между запасом и мелкотой.
  foreground(artScale: 0.66, opaque: false),

  /// Монохром для тем Android 13: система смотрит только на альфу и красит
  /// сама. Ужат сильнее — поверх него система накладывает свой отступ.
  monochrome(artScale: 0.62, opaque: false);

  const IconLayer({required this.artScale, required this.opaque});

  final double artScale;
  final bool opaque;
}

/// Границы чернил глифа в долях кегля.
///
/// Метрики шрифта тут не годятся: `TextPainter` отдаёт строчный бокс с
/// подъёмом и свесом, а буква `A` не достаёт ни до верха, ни до низа. Класть
/// рисунок по строчному боксу — значит промахнуться на несколько процентов
/// холста, и на 48 px это видно. Поэтому чернила меряются, а не берутся из
/// таблиц: [measure] рисует букву и сканирует альфу.
class GlyphInk {
  const GlyphInk(this.bounds);

  /// Прямоугольник чернил в единицах кегля, отсчитанный от точки, куда
  /// `TextPainter.paint` кладёт левый верх строчного бокса.
  final Rect bounds;

  static Future<GlyphInk> measure(String glyph) async {
    const em = 128.0;
    const canvasSize = 384;
    final painter = _painter(glyph, em, const Color(0xFFFFFFFF));
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(canvasSize, canvasSize);
    picture.dispose();
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    image.dispose();
    if (data == null) throw StateError('не удалось прочитать пиксели глифа');
    final pixels = data.buffer.asUint8List();

    var minX = canvasSize, minY = canvasSize, maxX = -1, maxY = -1;
    for (var y = 0; y < canvasSize; y++) {
      for (var x = 0; x < canvasSize; x++) {
        if (pixels[(y * canvasSize + x) * 4 + 3] == 0) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (maxX < 0) {
      throw StateError(
        'Глиф «$glyph» не оставил ни одного пикселя. Скорее всего не приехал '
        'шрифт Rubik: без него иконка вышла бы пустой, а генератор — зелёным.',
      );
    }
    return GlyphInk(
      Rect.fromLTRB(minX / em, minY / em, (maxX + 1) / em, (maxY + 1) / em),
    );
  }
}

TextPainter _painter(String glyph, double size, Color color) => TextPainter(
  text: TextSpan(
    text: glyph,
    style: TextStyle(
      fontFamily: wordarcadeFont,
      fontSize: size,
      color: color,
      height: 1,
      fontVariations: const [FontVariation('wght', brandWeight)],
    ),
  ),
  textDirection: TextDirection.ltr,
)..layout();

/// Рисует иконку [variant] слоя [layer] на холсте [size]×[size].
void paintIcon(
  Canvas canvas,
  double size,
  BrandIcon variant,
  IconLayer layer,
  GlyphInk ink,
) {
  final full = Rect.fromLTWH(0, 0, size, size);
  if (layer.opaque) {
    canvas.drawRect(full, Paint()..color = brandSurface);
  }
  // Слой нужен, чтобы `BlendMode.clear` вырезал букву из плашки, а не из
  // всего изображения разом.
  canvas.saveLayer(full, Paint());
  final art = _Art(canvas, size, layer, ink);
  switch (variant) {
    case BrandIcon.block:
      _block(art);
    case BrandIcon.trail:
      _trail(art);
    case BrandIcon.beam:
      _beam(art);
  }
  canvas.restore();
}

/// Система координат рисунка: (0,0)…(1,1) — вписанный квадрат холста.
class _Art {
  _Art(this.canvas, double canvasSize, this.layer, this.ink)
    : unit = canvasSize * layer.artScale,
      origin =
          Offset.zero +
          const Offset(1, 1) * (canvasSize * (1 - layer.artScale) / 2);

  final Canvas canvas;
  final IconLayer layer;
  final GlyphInk ink;
  final double unit;
  final Offset origin;

  /// Цвет рисунка: монохром система красит сама, ей важна только альфа.
  Color get tone =>
      layer == IconLayer.monochrome ? const Color(0xFFFFFFFF) : brandMint;

  Offset at(double x, double y) => origin + Offset(x * unit, y * unit);

  Rect box(double l, double t, double r, double b) =>
      Rect.fromPoints(at(l, t), at(r, b));

  double u(double v) => v * unit;

  Paint fill(double opacity) =>
      Paint()..color = tone.withValues(alpha: opacity);

  /// Полоса пола — общая для всех трёх вариантов.
  ///
  /// Не во всю ширину и не у самого низа, и это не вкус. Маска адаптивной
  /// иконки — окружность, вписанная в безопасный квадрат, а не сам квадрат:
  /// полоса от края до края у нижней кромки срезалась ею по углам
  /// (видно на первом контрольном листе). Половина ширины 0.30 при низе
  /// 0.885 даёт 0.30² + 0.385² = 0.238 против 0.25 — углы внутри круга.
  void floor() {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        box(0.20, 0.815, 0.80, 0.885),
        Radius.circular(u(0.035)),
      ),
      fill(1),
    );
  }

  /// Буква с чернилами высотой [height], низом на [bottom], центром по x
  /// в [centerX]. Все три — в долях рисунка, не в кеглях.
  void glyph({
    required double height,
    required double bottom,
    double centerX = 0.5,
    double opacity = 1,
  }) {
    _paintGlyph(
      height: height,
      bottom: bottom,
      centerX: centerX,
      style:
          (size) => TextStyle(
            fontFamily: wordarcadeFont,
            fontSize: size,
            height: 1,
            color: tone.withValues(alpha: opacity),
            fontVariations: const [FontVariation('wght', brandWeight)],
          ),
    );
  }

  /// Та же буква, но вырезанная насквозь.
  void glyphHole({
    required double height,
    required double bottom,
    double centerX = 0.5,
  }) {
    _paintGlyph(
      height: height,
      bottom: bottom,
      centerX: centerX,
      style:
          (size) => TextStyle(
            fontFamily: wordarcadeFont,
            fontSize: size,
            height: 1,
            fontVariations: const [FontVariation('wght', brandWeight)],
            // На непрозрачном слое дырка не нужна: под ней тот же surface. На
            // прозрачном — нужна, иначе монохром получил бы сплошную плашку без
            // буквы: система красит по альфе и цвета внутри не видит.
            foreground:
                layer.opaque
                    ? (Paint()..color = brandSurface)
                    : (Paint()..blendMode = BlendMode.clear),
          ),
    );
  }

  void _paintGlyph({
    required double height,
    required double bottom,
    required double centerX,
    required TextStyle Function(double size) style,
  }) {
    final fontSize = u(height) / ink.bounds.height;
    final painter = TextPainter(
      text: TextSpan(text: brandGlyph, style: style(fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    final inkTopLeft = ink.bounds.topLeft * fontSize;
    final inkSize = ink.bounds.size * fontSize;
    final anchor = at(centerX, bottom);
    canvas.save();
    canvas.translate(
      anchor.dx - inkSize.width / 2 - inkTopLeft.dx,
      anchor.dy - inkSize.height - inkTopLeft.dy,
    );
    painter.paint(canvas, Offset.zero);
    canvas.restore();
  }
}

/// Вариант «блок»: аркадная плашка с вырезанной буквой падает на пол.
///
/// Наклон в 8° — не украшение, а единственное, что здесь говорит «падает».
/// Прямая плашка с двумя штрихами сверху читалась роботом: штрихи выходили
/// антеннами, плашка — экраном, полоса пола — клавиатурой.
void _block(_Art a) {
  final pivot = a.at(0.5, 0.44);
  a.canvas.save();
  a.canvas.translate(pivot.dx, pivot.dy);
  a.canvas.rotate(-0.14);
  a.canvas.translate(-pivot.dx, -pivot.dy);
  a.canvas.drawRRect(
    RRect.fromRectAndRadius(
      a.box(0.22, 0.16, 0.78, 0.72),
      Radius.circular(a.u(0.15)),
    ),
    a.fill(1),
  );
  a.glyphHole(height: 0.33, bottom: 0.60);
  a.canvas.restore();
  a.floor();
}

/// Вариант «след»: буква и два её затухающих отпечатка выше.
void _trail(_Art a) {
  // Отпечатки одного размера с буквой, а не уменьшающиеся кверху. Сужение
  // складывало три `A` в ёлку — силуэт читался деревом раньше, чем буквой.
  a.glyph(height: 0.30, bottom: 0.335, opacity: 0.18);
  a.glyph(height: 0.30, bottom: 0.555, opacity: 0.38);
  a.glyph(height: 0.30, bottom: 0.775);
  a.floor();
}

/// Вариант «луч»: буква летит в подкрашенной полосе — тот же приём, что у
/// комбо-тона в SPEC, только здесь ярче внизу, а не в середине.
void _beam(_Art a) {
  // Трапеция, а не полоса: ровные вертикальные борта читались дверью. Луч,
  // расширяющийся книзу, — это направление, и оно совпадает с направлением
  // падения.
  final path =
      Path()
        ..moveTo(a.at(0.37, 0.06).dx, a.at(0.37, 0.06).dy)
        ..lineTo(a.at(0.63, 0.06).dx, a.at(0.63, 0.06).dy)
        ..lineTo(a.at(0.73, 0.86).dx, a.at(0.73, 0.86).dy)
        ..lineTo(a.at(0.27, 0.86).dx, a.at(0.27, 0.86).dy)
        ..close();
  a.canvas.drawPath(
    path,
    Paint()
      ..shader = ui.Gradient.linear(
        a.at(0.5, 0.06),
        a.at(0.5, 0.86),
        [
          a.tone.withValues(alpha: 0),
          a.tone.withValues(alpha: 0.40),
          a.tone.withValues(alpha: 0),
        ],
        const [0, 0.80, 1],
      ),
  );
  a.glyph(height: 0.34, bottom: 0.775);
  a.floor();
}

/// Пиксели готовой иконки: RGBA, straight alpha, row-primary.
Future<Uint8List> rasterize(
  int pixels,
  BrandIcon variant,
  IconLayer layer,
  GlyphInk ink,
) async {
  final recorder = ui.PictureRecorder();
  paintIcon(Canvas(recorder), pixels.toDouble(), variant, layer, ink);
  final picture = recorder.endRecording();
  final image = await picture.toImage(pixels, pixels);
  picture.dispose();
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  image.dispose();
  if (data == null) throw StateError('пустой растр $pixels×$pixels');
  return data.buffer.asUint8List();
}
