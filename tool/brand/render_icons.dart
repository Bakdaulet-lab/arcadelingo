/// Генератор иконок лаунчера: рисует три варианта и, по команде, ставит
/// выбранный в `android/` и `ios/`.
///
/// Запускается через `flutter test`, а не `dart run`, и это не причуда:
/// рисунок использует `dart:ui` и настоящий Rubik из ассетов приложения.
/// Голый `dart run` не даёт ни движка, ни шрифта — буква вышла бы
/// прямоугольником либо не вышла бы вовсе. Каталог `tool/`, а не `test/`,
/// потому что `scripts/verify.sh` гоняет `flutter test` по `test/`: генератор
/// не должен переписывать файлы репозитория на каждом прогоне гейта.
///
///   Показать варианты:  flutter test tool/brand/render_icons.dart
///   Поставить выбранный: BRAND_ICON=trail flutter test tool/brand/render_icons.dart
///
/// Без `BRAND_ICON` в репозиторий не пишется ничего: превью уходят в
/// `tool/out/icons/`, который не под гитом. Установка требует назвать вариант
/// вслух — «случайно поставил не тот» так не случается.
///
/// Каждый размер рисуется в своём разрешении, а не ужимается из одного
/// мастера: на 48 px разница между отрисованным и уменьшенным видна на
/// полосе пола толщиной в три пикселя.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:arcadelingo/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'icon_art.dart';
import 'png.dart';

/// Плотности Android и сторона квадрата в пикселях.
///
/// Легаси-иконка — 48 dp, адаптивная — 108 dp; отсюда две таблицы, а не одна
/// с множителем.
const Map<String, int> _legacyDensities = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

const Map<String, int> _adaptiveDensities = {
  'mdpi': 108,
  'hdpi': 162,
  'xhdpi': 216,
  'xxhdpi': 324,
  'xxxhdpi': 432,
};

/// Имена из `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`.
/// Список сверяется тестом: Xcode молча покажет пустую иконку, если файла нет.
const Map<String, int> _iosIcons = {
  'Icon-App-20x20@1x.png': 20,
  'Icon-App-20x20@2x.png': 40,
  'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29,
  'Icon-App-29x29@2x.png': 58,
  'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40,
  'Icon-App-40x40@2x.png': 80,
  'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120,
  'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76,
  'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167,
  'Icon-App-1024x1024@1x.png': 1024,
};

const String _previewDir = 'tool/out/icons';
const String _androidRes = 'android/app/src/main/res';
const String _iosIconDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'иконки: превью, и установка выбранного варианта по BRAND_ICON',
    () async {
      await _loadBrandFont();
      final ink = await GlyphInk.measure(brandGlyph);
      // Чернила печатаются, а не проверяются: число нужно человеку, когда
      // рисунок «поехал» после смены шрифта.
      // ignore: avoid_print
      print('чернила «$brandGlyph» в долях кегля: ${ink.bounds}');

      await _writePreviews(ink);

      final chosen = Platform.environment['BRAND_ICON'];
      if (chosen == null || chosen.isEmpty) {
        // ignore: avoid_print
        print(
          'BRAND_ICON не задан — в репозиторий не записано ничего.\n'
          'Превью: $_previewDir/contact-sheet.png',
        );
        return;
      }
      final variant = BrandIcon.values.firstWhere(
        (v) => v.name == chosen,
        orElse:
            () =>
                throw ArgumentError(
                  'BRAND_ICON=$chosen — нет такого варианта. Есть: '
                  '${BrandIcon.values.map((v) => v.name).join(', ')}',
                ),
      );
      await _install(variant, ink);
      // ignore: avoid_print
      print('поставлен вариант «${variant.name}»');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// Rubik из ассетов приложения — та же гарнитура, что на экране.
Future<void> _loadBrandFont() async {
  final loader = FontLoader(wordarcadeFont)
    ..addFont(rootBundle.load('assets/fonts/Rubik-Variable.ttf'));
  await loader.load();
}

// ── превью ────────────────────────────────────────────────────────────────

Future<void> _writePreviews(GlyphInk ink) async {
  Directory(_previewDir).createSync(recursive: true);
  for (final variant in BrandIcon.values) {
    await _write(
      '$_previewDir/${variant.name}-512.png',
      512,
      variant,
      IconLayer.legacy,
      ink,
    );
    await _write(
      '$_previewDir/${variant.name}-monochrome-512.png',
      512,
      variant,
      IconLayer.monochrome,
      ink,
    );
  }
  await _writeContactSheet(ink);
  // ignore: avoid_print
  print('превью: $_previewDir/contact-sheet.png');
}

/// Один лист, на котором видно всё, ради чего иконку смотрят: силуэт в
/// квадрате, под маской круга и под маской скруглённого квадрата (лаунчеры
/// делят мир примерно так) и мелкие размеры, на которых рисунок обычно
/// разваливается.
Future<void> _writeContactSheet(GlyphInk ink) async {
  const width = 1192;
  const height = 1064;
  const sheet = Rect.fromLTWH(0, 0, 1192, 1064);
  const board = Color(0xFF8F8F99);
  const label = Color(0xFF15131A);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(sheet, Paint()..color = board);

  _text(
    canvas,
    'arcadelingo — иконка лаунчера',
    const Offset(40, 26),
    26,
    label,
  );
  const columns = [
    'квадрат — iOS и старый Android',
    'круглая маска',
    'скруглённая маска',
    'мелко: 96 · 72 · 48',
  ];
  const xs = [40.0, 328.0, 616.0, 904.0];
  for (var i = 0; i < columns.length; i++) {
    _text(canvas, columns[i], Offset(xs[i], 74), 16, label);
  }

  for (var row = 0; row < BrandIcon.values.length; row++) {
    final variant = BrandIcon.values[row];
    final top = 132.0 + row * 310;
    _text(canvas, variant.name, Offset(40, top - 26), 20, label);

    canvas.save();
    canvas.translate(xs[0], top);
    paintIcon(canvas, 256, variant, IconLayer.legacy, ink);
    canvas.restore();

    _masked(canvas, Offset(xs[1], top), 256, variant, ink, circle: true);
    _masked(canvas, Offset(xs[2], top), 256, variant, ink, circle: false);

    var x = xs[3];
    for (final size in const [96.0, 72.0, 48.0]) {
      // Мелкие показаны под маской, а не квадратом: на телефоне их видно
      // именно так, и разваливается рисунок тоже именно там.
      _masked(
        canvas,
        Offset(x, top + (256 - size) / 2),
        size,
        variant,
        ink,
        circle: false,
      );
      x += size + 16;
    }
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  image.dispose();
  File('$_previewDir/contact-sheet.png').writeAsBytesSync(
    encodePng(width, height, data!.buffer.asUint8List(), opaque: true),
  );
}

/// Адаптивная иконка так, как её показывает лаунчер: холст 108 dp,
/// увеличенный до маски 72 dp, и всё лишнее срезано.
void _masked(
  Canvas canvas,
  Offset at,
  double size,
  BrandIcon variant,
  GlyphInk ink, {
  required bool circle,
}) {
  final rect = Rect.fromLTWH(at.dx, at.dy, size, size);
  canvas.save();
  if (circle) {
    canvas.clipPath(Path()..addOval(rect));
  } else {
    canvas.clipRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size * 0.22)),
    );
  }
  canvas.drawRect(rect, Paint()..color = brandSurface);
  // 108/72: внешние 18 dp с каждой стороны маска съедает — превью обязано
  // съедать их тоже, иначе рисунок на листе выглядит просторнее, чем на
  // телефоне.
  const scale = 108 / 72;
  canvas.translate(
    at.dx - size * (scale - 1) / 2,
    at.dy - size * (scale - 1) / 2,
  );
  paintIcon(canvas, size * scale, variant, IconLayer.foreground, ink);
  canvas.restore();
}

void _text(Canvas canvas, String text, Offset at, double size, Color color) {
  TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: wordarcadeFont,
          fontSize: size,
          color: color,
          fontVariations: const [FontVariation('wght', 600)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )
    ..layout()
    ..paint(canvas, at);
}

// ── установка ─────────────────────────────────────────────────────────────

Future<void> _install(BrandIcon variant, GlyphInk ink) async {
  for (final entry in _legacyDensities.entries) {
    await _write(
      '$_androidRes/mipmap-${entry.key}/ic_launcher.png',
      entry.value,
      variant,
      IconLayer.legacy,
      ink,
    );
  }
  for (final entry in _adaptiveDensities.entries) {
    await _write(
      '$_androidRes/drawable-${entry.key}/ic_launcher_foreground.png',
      entry.value,
      variant,
      IconLayer.foreground,
      ink,
    );
    await _write(
      '$_androidRes/drawable-${entry.key}/ic_launcher_monochrome.png',
      entry.value,
      variant,
      IconLayer.monochrome,
      ink,
    );
  }
  for (final entry in _iosIcons.entries) {
    await _write(
      '$_iosIconDir/${entry.key}',
      entry.value,
      variant,
      IconLayer.legacy,
      ink,
    );
  }
  // Иконка магазина в репозиторий не едет: её место — форма загрузки, а не
  // сборка. Лежит рядом с превью, чтобы не рисовать её отдельно перед сдачей.
  await _write(
    '$_previewDir/play-store-512.png',
    512,
    variant,
    IconLayer.legacy,
    ink,
  );
}

Future<void> _write(
  String path,
  int size,
  BrandIcon variant,
  IconLayer layer,
  GlyphInk ink,
) async {
  final rgba = await rasterize(size, variant, layer, ink);
  if (layer.opaque) _assertOpaque(path, rgba);
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(encodePng(size, size, rgba, opaque: layer.opaque));
}

/// Сторож на альфу.
///
/// Непрозрачные PNG пишутся типом цвета 2, то есть альфа выбрасывается. Если
/// она где-то не 255, картинка изменится молча — и заметить это можно будет
/// только глазами на готовой иконке. App Store, наоборот, отклоняет альфу в
/// иконке, поэтому выбрасывать её надо, но с проверкой.
void _assertOpaque(String path, Uint8List rgba) {
  for (var i = 3; i < rgba.length; i += 4) {
    if (rgba[i] != 255) {
      throw StateError(
        '$path: пиксель с альфой ${rgba[i]} в непрозрачном слое. '
        'PNG типа 2 её выбросит, и цвет уедет.',
      );
    }
  }
}
