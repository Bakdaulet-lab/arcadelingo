// Домашний экран как ритуал: три кадра.
//
// До Фазы 3 у домашнего экрана не было ни одного эталона — там были
// заголовок и кнопка, и смотреть было не на что. Теперь на нём живёт то,
// ради чего фаза существует, и числами это не проверить: вопрос не «есть ли
// строка», а не тесно ли им и читается ли главное первым.
//
// Три состояния, а не шесть: остальные различаются словами, и слова
// проверяет `test/ui/ritual_labels_test.dart`. Кадр «заморозка потрачена
// вчера» эталоном не заводится намеренно — он отличается от соседнего ровно
// одной строкой текста, и держать за это отдельный байтовый эталон дорого.
//
// Пересняты под задачу 3.3.1: вместо трёх строк текста на карточке пламя,
// растущее с серией, и полоса недели. Первые кандидаты автор не принял.
//
// Эталоны снимаются на Linux и принимаются человеком по артефакту прогона
// CI: `--update-goldens` в проекте не работает ни у кого
// (`docs/dev/goldens.md`).

@Tags(['golden'])
library;

import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/ui/week_strip.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/golden_harness.dart';
import '../support/ritual_views.dart';

void main() {
  testWidgets('ритуал: серии ещё нет', (tester) async {
    await pumpRitualGolden(
      tester,
      ritualView(),
      week: weekStrip(today: ritualToday, played: const {}),
    );

    await expectLater(
      find.byType(PlayView),
      matchesGoldenFile('images/ritual_fresh.png'),
    );
  });

  testWidgets('ритуал: сегодня сыграно, серия идёт', (tester) async {
    await pumpRitualGolden(
      tester,
      ritualView(days: 5, best: 9),
      week: weekStrip(
        today: ritualToday,
        played: {daysAgo(2), daysAgo(1), ritualToday},
      ),
    );

    await expectLater(
      find.byType(PlayView),
      matchesGoldenFile('images/ritual_played.png'),
    );
  });

  testWidgets('ритуал: серия под угрозой, заморозка спасёт', (tester) async {
    await pumpRitualGolden(
      tester,
      ritualView(days: 6, lastOffset: 2, best: 9, freezes: 1),
      week: weekStrip(today: ritualToday, played: {daysAgo(2)}),
    );

    await expectLater(
      find.byType(PlayView),
      matchesGoldenFile('images/ritual_at_risk.png'),
    );
  });
}
