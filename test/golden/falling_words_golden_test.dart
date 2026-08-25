// Восемь кадров «падающих слов», зафиксированных картинкой.
//
// Зачем вообще голдены, когда рядом лежат сто с лишним виджет-тестов: те
// проверяют числа — «dx сместился», «цвет не surface», «расстояние до счёта
// уменьшилось». Ни один из них не отвечает на вопрос, выглядит ли это как
// игра, а не как баг вёрстки. Отвечает картинка, на которую посмотрел
// человек.
//
// Эталоны создаёт и обновляет человек: --update-goldens в этом проекте
// выключён на уровне компаратора. Процедура — docs/dev/goldens.md.
//
// Все настройки съёмки — в pumpGolden (test/support/golden_harness.dart),
// чтобы восемь кадров отличались только тем, что произошло в игре.
//
// Чего здесь нет: кадров при системном шрифте 2×. Там открыта Р7 — игровое
// поле переполняется на коротком экране, — и эталон закрепил бы сломанную
// вёрстку как правильную. Вернуться сюда после Р7.

import 'package:arcadelingo/features/games/falling_words/falling_words_views.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/golden_harness.dart';
import '../support/review_items.dart';

void main() {
  // Канарейка. Без загруженных шрифтов flutter test рисует каждую букву
  // прямоугольником одинаковой ширины: восемь эталонов снялись бы,
  // сравнились сами с собой и остались бы зелёными, не говоря ни о чём.
  //
  // Проверок две, и обе нужны. Первая — что тема голденов вообще просит
  // Roboto: `Typography` выбирает семейство по платформе, и незапиненная
  // платформа дала бы на Windows Segoe UI, которого в тестовом движке нет.
  // Вторая — что за этим именем стоит настоящий шрифт: Roboto
  // пропорциональный, и восемь «W» шире восьми «i» больше чем вдвое, тогда
  // как у запасного шрифта тестов каждая глифа ровно в одну em.
  //
  // Текст стоит под Scaffold намеренно. Вне Material его стиль приходит не
  // из темы, а из отладочного `monospace`, и канарейка мерила бы не то —
  // на этом она в первый же прогон и поймала сама себя.
  //
  // Иконок эта проверка не покрывает: у MaterialIcons все глифы одной
  // ширины, и подмену запасным шрифтом по размеру не увидеть. Их сторожит
  // загрузчик (падает, если в FontManifest нет семейства) и сам эталон —
  // сердца на нём человек либо видит, либо нет.
  testWidgets('шрифты загружены и тема их просит', (tester) async {
    const narrow = ValueKey('narrow');
    const wide = ValueKey('wide');
    await tester.pumpWidget(
      MaterialApp(
        theme: wordarcadeTheme(platform: TargetPlatform.android),
        home: const Scaffold(
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('iiiiiiii', key: narrow, style: TextStyle(fontSize: 20)),
              Text('WWWWWWWW', key: wide, style: TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ),
    );

    expect(
      DefaultTextStyle.of(tester.element(find.byKey(wide))).style.fontFamily,
      'Rubik',
      reason: 'тема просит не тот шрифт — эталон снимется не в той гарнитуре',
    );
    expect(
      tester.getSize(find.byKey(wide)).width,
      greaterThan(tester.getSize(find.byKey(narrow)).width * 1.5),
      reason:
          'ширины сошлись — значит за именем Rubik стоит запасной шрифт '
          'тестов и всё нарисовано прямоугольниками; смотреть на такие '
          'эталоны бессмысленно',
    );
  });

  // Вторая канарейка, и она про вариативный файл. Обычный fontWeight ось
  // wght у Rubik не двигает — замерено: строка в w400 и в w700 выходит
  // ровно одной ширины. Вес идёт через fontVariations, и если эта проводка
  // порвётся, весь текст молча уедет в значение по умолчанию, а для Rubik
  // это Light 300. На голдене такое видно, только если знать, что искать.
  testWidgets('вес шрифта применяется: жирное шире обычного', (tester) async {
    const plain = ValueKey('plain');
    const bold = ValueKey('bold');
    final theme = wordarcadeTheme(platform: TargetPlatform.android);
    final base = theme.textTheme.titleLarge!;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Проверка веса', key: plain, style: base),
              Text(
                'Проверка веса',
                key: bold,
                style: withWeight(base, FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(bold)).width,
      greaterThan(tester.getSize(find.byKey(plain)).width),
      reason:
          'ширины сошлись — ось wght не применилась, и весь текст рисуется '
          'значением по умолчанию (для Rubik это Light 300)',
    );
  });

  testWidgets('падение', tags: 'golden', (tester) async {
    await pumpGolden(tester, total: 15);

    await tester.pump(const Duration(seconds: 2));

    await expectGolden(tester, 'falling');
  });

  testWidgets('промах: пара по центру, тряска улеглась', tags: 'golden', (
    tester,
  ) async {
    await pumpGolden(tester, total: 15);

    await tester.pump(const Duration(seconds: 1));
    await tapGolden(tester, wordDistractor(1, 1));
    // 500 мс из 800: тряска кончилась на 300-й, пара стоит ровно.
    await tester.pump(const Duration(milliseconds: 500));

    await expectGolden(tester, 'reveal_miss');
  });

  // Отличается от предыдущего кадра ровно одним: HUD и ряд кнопок уехали на
  // −6.7 dp, а пара осталась по центру. Если однажды поедет и пара, это
  // будет видно сравнением двух PNG рядом.
  testWidgets('промах: 50 мс, тряска в разгаре', tags: 'golden', (
    tester,
  ) async {
    await pumpGolden(tester, total: 15);

    await tester.pump(const Duration(seconds: 1));
    await tapGolden(tester, wordDistractor(1, 1));
    await tester.pump(const Duration(milliseconds: 50));

    await expectGolden(tester, 'shake');
  });

  testWidgets(
    'серия 8: поле подкрашено, кнопки на чистом фоне',
    tags: 'golden',
    (tester) async {
      await pumpGolden(tester, items: wordItems(12), total: 15);

      for (var i = 1; i <= 8; i++) {
        await answerGolden(tester, i);
      }
      // 400 мс — полный перелив тона; девятое слово к этому моменту прошло
      // десятую часть пути.
      await tester.pump(const Duration(milliseconds: 400));

      await expectGolden(tester, 'combo_tint');
    },
  );

  // Кадр успеха, ради которого затевалась 0.11: до неё верный ответ ничем не
  // помечался вовсе. Снимается вариант «в последний момент» — он визуальное
  // надмножество обычного: то же «плюс очки в полёте» плюс метка ×1.5.
  testWidgets(
    'верный ответ в последний момент: очки в полёте',
    tags: 'golden',
    (tester) async {
      await pumpGolden(tester, total: 15);

      // 5500 из 6000 — это 92% лимита, окно бонуса начинается с 85%.
      await tester.pump(const Duration(milliseconds: 5500));
      await tapGolden(tester, wordTranslation(1));
      // 225 мс из 300 — пик пульса счёта; «+15» прошёл 98% пути и ещё виден.
      await tester.pump(const Duration(milliseconds: 225));

      await expectGolden(tester, 'score_pop');
    },
  );

  // Запрос ревьюера 0.7: какой остаётся зазор между словом и верхней кнопкой.
  // 5950 мс — 99% пути и уже внутри окна «в последний момент», так что кадр
  // заодно показывает, где эта зона проходит относительно ряда кнопок.
  testWidgets('слово у самого низа, таймаут ещё не сработал', tags: 'golden', (
    tester,
  ) async {
    await pumpGolden(tester, total: 15);

    await tester.pump(const Duration(milliseconds: 5950));

    expect(
      find.byKey(FallingWordsKeys.revealAnswer),
      findsNothing,
      reason: 'если таймаут успел сработать, снимется пара, а не слово',
    );
    await expectGolden(tester, 'word_at_bottom');
  });

  testWidgets('итоги', tags: 'golden', (tester) async {
    await pumpGolden(tester, items: wordItems(3), footer: goldenFooter);

    await answerGolden(tester, 1);
    await answerGolden(tester, 2);
    await answerGolden(tester, 3);

    await expectGolden(tester, 'summary');
  });

  testWidgets('на сегодня всё', tags: 'golden', (tester) async {
    await pumpGolden(tester, items: const []);

    await expectGolden(tester, 'nothing_today');
  });
}
