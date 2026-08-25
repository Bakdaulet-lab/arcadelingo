// Один вход для всех голденов: экран, тема, зерно перемешивания, баннер.
//
// Восемь эталонов обязаны отличаться только тем, что происходит в игре, и
// ничем больше. Настройки, разъехавшиеся между кадрами, дали бы диффы, в
// которых человек ищет смысл там, где его нет.
//
// Про размер PNG: он всегда 360×780, сколько бы ни стоял devicePixelRatio.
// matchesGoldenFile снимает через captureImage → layer.toImage(paintBounds),
// а там pixelRatio по умолчанию 1.0, то есть кадр в логических пикселях.
// Смотреть на такой файл надо с зумом.

import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/streak/streak_view.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:arcadelingo/ui/week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_review_session.dart';
import 'review_items.dart';

/// Экран, на котором снимаются все эталоны: 360×780 dp.
const Size goldenPhysicalSize = Size(1080, 2340);

/// Плотность того же экрана.
const double goldenDevicePixelRatio = 3;

/// Строка «что дальше» на итогах. Фиксированная: настоящую считает хост по
/// часам и хранилищу, и тянуть их в голден незачем.
const String goldenFooter = 'Ещё есть слова — сыграй ещё раунд';

/// Игра, готовая к съёмке.
///
/// Тема — настоящая, с пиннутой платформой: `Typography` выбирает семейство
/// шрифта по платформе, и на Windows это была бы Segoe UI. Масштаб текста
/// выставлен явно, иначе унаследовалась бы системная настройка машины.
Future<FakeReviewSession> pumpGolden(
  WidgetTester tester, {
  List<ReviewItem>? items,
  int? total,
  String? footer,
}) async {
  final session = FakeReviewSession(items ?? wordItems(3), total: total);
  tester.view.physicalSize = goldenPhysicalSize;
  tester.view.devicePixelRatio = goldenDevicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = 1;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    MaterialApp(
      theme: wordarcadeTheme(platform: TargetPlatform.android),
      debugShowCheckedModeBanner: false,
      home: FallingWordsGame(
        session: session,
        seed: 1,
        summaryFooter: footer == null ? null : () => footer,
        onPlayAgain: () {},
        onExit: () {},
      ),
    ),
  );
  return session;
}

/// Снять кадр целиком и сверить с эталоном `images/<name>.png`.
///
/// Путь относительный, и разрешается он от каталога теста, а не от этого
/// файла: basedir компаратору выставляет сам `flutter test` по пути
/// запущенного теста.
Future<void> expectGolden(WidgetTester tester, String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('images/$name.png'),
);

/// Тап по кнопке с текстом [label] и кадр-взвод.
///
/// Пустой `pump()` обязателен: контроллер подсветки запускается из
/// обработчика тапа, то есть вне кадра, и встаёт на часы только следующим
/// тиком (`docs/dev/context.md`). Без него все последующие `pump(Δ)` уехали
/// бы на кадр, и кадр тряски снялся бы не в тот момент.
Future<void> tapGolden(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

/// Верный ответ на слово [i] через секунду и промотанная подсветка.
///
/// Секунда — заведомо меньше 85% любого лимита, так что ни один разгон серии
/// не превращается в «в последний момент» случайно.
Future<void> answerGolden(WidgetTester tester, int i) async {
  await tester.pump(const Duration(seconds: 1));
  await tapGolden(tester, wordTranslation(i));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Домашний экран с ритуалом, готовый к съёмке.
///
/// Те же размер, плотность и масштаб текста, что и у восьми кадров игры:
/// эталоны обязаны отличаться тем, что на них нарисовано, и ничем больше.
Future<void> pumpRitualGolden(
  WidgetTester tester,
  StreakView ritual, {
  List<WeekDay>? week,
}) async {
  tester.view.physicalSize = goldenPhysicalSize;
  tester.view.devicePixelRatio = goldenDevicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = 1;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    MaterialApp(
      theme: wordarcadeTheme(platform: TargetPlatform.android),
      debugShowCheckedModeBanner: false,
      home: PlayView(
        onPlay: () {},
        onSources: () {},
        ritual: ritual,
        week: week,
      ),
    ),
  );
  await tester.pump();
}
