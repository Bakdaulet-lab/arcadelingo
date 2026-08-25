// Санкционированный peek: снять PNG любого экрана и положить его человеку.
//
// Зачем это есть. Definition of Done в CLAUDE.md требует для UI-изменений
// скриншот, а голден на каждый экран заводить нельзя: эталоны существуют для
// одной платформы (Linux, docs/dev/goldens.md), их принимает человек по
// артефакту CI, и превращать эту процедуру в способ «посмотреть, что
// получилось» — значит износить её до бессмысленности. Отсюда законная дверь:
// картинка, которая никогда не станет эталоном.
//
// Чего здесь нет и не будет:
//
//   * компаратора. Peek ничего не сравнивает — он пишет файл. Поэтому он не
//     может ни принять эталон, ни его испортить, ни покраснеть «не тем»;
//   * ассертов. Peek — не тест, он ничего не проверяет и всегда зелёный.
//     Тег `peek` держит его вне обычных прогонов именно поэтому: зелёный
//     навсегда шаг внутри гейта был бы враньём про покрытие;
//   * пути в test/golden/. Снимки уходят в test/peek/out/, каталог в
//     .gitignore. Файл оттуда не может попасть в эталоны опечаткой в `mv`:
//     у него другое имя каталога, а не другое расширение.
//
// Запуск только руками:
//
//   flutter test --tags peek test/peek/
//
// Снимок снят на той платформе, где его запустили. Для разглядывания это
// ровно то, что нужно; эталоном он не является ни на какой платформе.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:arcadelingo/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Куда складываются снимки. Относительно корня пакета: `flutter test`
/// запускает тесты с рабочим каталогом в корне.
const String peekOutDir = 'test/peek/out';

/// Экран съёмки по умолчанию — тот же, что у голденов: 360×780 dp при
/// плотности 3. Совпадение намеренное: peek и эталон должны показывать одну
/// и ту же вёрстку, иначе peek перестаёт что-либо предсказывать.
const Size peekPhysicalSize = Size(1080, 2340);

/// Плотность того же экрана.
const double peekDevicePixelRatio = 3;

/// Развернуть [home] в настоящем `MaterialApp` с темой приложения.
///
/// Тема — `wordarcadeTheme` с пиннутой платформой, как в голденах: копия
/// темы в тесте разошлась бы с приложением молча, а незапиненная платформа
/// дала бы на Windows Segoe UI.
///
/// [textScale] выставляется явно: иначе унаследовалась бы системная настройка
/// машины, и снимок показал бы не то, что видит пользователь по умолчанию.
/// Он же — способ снять экран «как при системном шрифте 2×».
Future<void> pumpPeek(
  WidgetTester tester,
  Widget home, {
  Size physicalSize = peekPhysicalSize,
  double devicePixelRatio = peekDevicePixelRatio,
  double textScale = 1,
}) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = devicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    MaterialApp(
      theme: wordarcadeTheme(platform: TargetPlatform.android),
      debugShowCheckedModeBanner: false,
      home: home,
    ),
  );
}

/// Снять текущий кадр в `test/peek/out/<name>.png` и вернуть файл.
///
/// По умолчанию снимается весь экран. [of] позволяет снять поддерево — файл
/// тогда обрезан по ближайшей к нему границе перерисовки, а не по нему
/// самому: слой есть только у границ, и рисовать «половину слоя» нечем.
///
/// Реализация повторяет то, что делает `matchesGoldenFile`: подъём до
/// ближайшего `isRepaintBoundary` и `OffsetLayer.toImage(paintBounds)`.
/// Скопировано, а не вызвано: `captureImage` из flutter_test импортируется
/// внутрь пакета, но наружу не экспортируется.
///
/// `paintBounds` корня считаются в физических пикселях, поэтому PNG выходит
/// 1080×2340, а не 360×780.
Future<File> peek(WidgetTester tester, String name, {Finder? of}) async {
  final finder = of ?? find.byType(MaterialApp);
  final element = finder.evaluate().single;

  // runAsync обязателен: toImage уходит в настоящий движок, а фейковые часы
  // тестового биндинга его не докрутят.
  final bytes = await tester.binding.runAsync<Uint8List>(() async {
    var object = element.renderObject!;
    while (!object.isRepaintBoundary) {
      object = object.parent!;
    }
    final image = await (object.debugLayer! as OffsetLayer).toImage(
      object.paintBounds,
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });

  final file = File('$peekOutDir/$name.png');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!, flush: true);
  // Путь печатается: снимок делают, чтобы на него посмотреть, и искать его
  // потом по дереву — лишний шаг.
  // ignore: avoid_print
  print('peek: ${file.path} (${bytes.length} байт)');
  return file;
}
