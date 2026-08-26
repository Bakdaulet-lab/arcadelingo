// Четыре кадра ниндзя-слэша, зафиксированных картинкой.
//
// Зачем голдены, когда рядом двести с лишним виджет-тестов: те проверяют
// числа — «dx сместился», «искр восемь», «след есть». Ни один не отвечает
// на вопрос, выглядит ли рез резом, а не багом вёрстки. Отвечает картинка,
// на которую посмотрел человек.
//
// Эталоны создаёт и обновляет человек: `--update-goldens` в этом проекте
// выключен на уровне компаратора. Процедура — `docs/dev/goldens.md`.
//
// Все настройки съёмки — в `pumpNinjaGolden`, чтобы кадры отличались только
// тем, что произошло в игре.
//
// Чего здесь нет: итогов и «на сегодня всё». Это дословные копии виджетов,
// уже покрытых кадрами падающих слов, и второй эталон на копию удвоил бы
// приёмку, не добавив информации. Разойтись копиям даст только выделение
// общего на третьей игре — тогда и снимать.
//
// Канареек шрифтов здесь тоже нет: они стоят в `falling_words_golden_test`,
// тегом не помечены и гоняются в обоих режимах. Вторая пара сторожила бы то
// же самое дважды.

import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_views.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/golden_harness.dart';
import '../support/review_items.dart';

void main() {
  // Взвод: слово уже читается, поле пусто, ничего не движется. 350 мс из
  // 700 — середина окна, где точно не видно ни старта, ни конца.
  testWidgets('взвод: слово наверху, поле пусто', tags: 'golden', (
    tester,
  ) async {
    await pumpNinjaGolden(tester, total: 15);

    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(NinjaKeys.objectAt(0)), findsNothing);
    await expectGolden(tester, 'ninja_windup');
  });

  // Полёт на серии 8: три объекта у апексов, поле на потолке тона. Девятая
  // волна летит 2 секунды, 900 мс — это t = 0.45, чуть до вершины, так что
  // на кадре видно и разные высоты апексов, и подъём.
  testWidgets('полёт на серии 8: поле подкрашено', tags: 'golden', (
    tester,
  ) async {
    await pumpNinjaGolden(tester, total: 15);
    await tester.pump(NinjaRun.windUpTime);

    for (var i = 1; i <= 8; i++) {
      await ninjaAnswerGolden(tester, i);
    }
    await tester.pump(const Duration(milliseconds: 900));

    await expectGolden(tester, 'ninja_flight');
  });

  // Рез в последний момент: след жеста, половинки, искры и «×1.5». 3200 из
  // 3500 — это 91% лимита, окно бонуса с 85%. 150 мс из 300 — половина
  // подсветки: половинки разошлись, искры на полпути, «+15» ещё виден.
  testWidgets(
    'рез в последний момент: след, половинки, искры',
    tags: 'golden',
    (tester) async {
      await pumpNinjaGolden(tester, total: 15);
      await tester.pump(NinjaRun.windUpTime);

      await tester.pump(const Duration(milliseconds: 3200));
      await sliceGolden(tester, ninjaIndexOf(tester, wordTranslation(1)));
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byKey(NinjaKeys.nearMissBadge), findsOneWidget);
      await expectGolden(tester, 'ninja_slice');
    },
  );

  // Промах: пара по центру, объекты замерли и погасли, разрезанный неверный
  // помечен. 500 мс из 800 — тряска кончилась на 300-й, кадр стоит ровно.
  testWidgets('промах: пара по центру, стоп-кадр', tags: 'golden', (
    tester,
  ) async {
    await pumpNinjaGolden(tester, total: 15);
    await tester.pump(NinjaRun.windUpTime);

    await tester.pump(const Duration(seconds: 1));
    await sliceGolden(tester, ninjaWrongIndex(tester, 1));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(NinjaKeys.revealAnswer), findsOneWidget);
    await expectGolden(tester, 'ninja_miss');
  });
}
