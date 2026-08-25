// Марка на домашнем экране: имя, начертание и соседство с серией.
//
// Соседний `brand_assets_test.dart` читает файлы платформ — XML, plist, PNG.
// Здесь наоборот, дерево виджетов, и это единственный тест, который вообще
// смотрит на заголовок домашнего экрана: до слияния с Фазой 2 его не
// проверяло ничто, ни текст, ни начертание.
//
// Начертание проверяется осью `wght`, а не полем `fontWeight`, и это не
// придирка к форме записи. На вариативном Rubik `fontWeight` инертен — вес
// двигает только ось (`lib/ui/theme.dart`), — поэтому
// `copyWith(fontWeight: FontWeight.bold)` даёт стиль, у которого `fontWeight`
// говорит «жирный», а экран рисует обычный. Тест, проверяющий `fontWeight`,
// был бы зелёным ровно на той ошибке, ради которой он написан.

import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/domain/streak/streak_view.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ritual_views.dart';

/// Имя, утверждённое автором.
const String appName = 'Arcadelingo';

Future<void> _pump(WidgetTester tester, {StreakView? ritual}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: wordarcadeTheme(platform: TargetPlatform.android),
        home: PlayView(onPlay: () {}, onSources: () {}, ritual: ritual),
      ),
    );

void main() {
  testWidgets('домашний экран назван так же, как иконка', (tester) async {
    await _pump(tester);
    expect(find.text(appName), findsOneWidget);
    expect(
      find.text('Wordarcade'),
      findsNothing,
      reason: 'старое имя не должно пережить переименование ни в одном месте',
    );
  });

  testWidgets('заголовок жирный по оси wght, а не только по fontWeight', (
    tester,
  ) async {
    await _pump(tester);
    final style = tester.widget<Text>(find.text(appName)).style;
    expect(style, isNotNull);
    expect(
      style!.fontVariations,
      contains(const FontVariation('wght', 700)),
      reason:
          'без оси wght Rubik нарисует заголовок обычным начертанием, каким '
          'бы ни был fontWeight',
    );
    // Само поле тоже верно: оно нужно запасным шрифтам и семантике.
    expect(style.fontWeight, FontWeight.bold);
  });

  testWidgets('марка и серия стоят на экране вместе', (tester) async {
    await _pump(tester, ritual: ritualView(days: 5));
    expect(find.text(appName), findsOneWidget);
    // Серия теперь карточка: число в пламени, подпись под ним.
    expect(find.text('5'), findsOneWidget);
    expect(find.text('дней подряд'), findsOneWidget);
    expect(find.byKey(AppKeys.streak), findsOneWidget);
    // Порядок сверху вниз: имя, затем серия. Если строка серии окажется над
    // заголовком, экран начнёт представляться числом, а не приложением.
    expect(
      tester.getTopLeft(find.text(appName)).dy,
      lessThan(tester.getTopLeft(find.byKey(AppKeys.streak)).dy),
    );
  });

  testWidgets('без серии заголовок остаётся один', (tester) async {
    await _pump(tester);
    expect(find.text(appName), findsOneWidget);
    expect(find.byKey(AppKeys.streak), findsNothing);
  });
}
