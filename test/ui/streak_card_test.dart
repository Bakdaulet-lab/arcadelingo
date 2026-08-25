// Карточка серии: что доехало от решений до краски.
//
// Голдены отвечают на «как это выглядит», а здесь — на «то ли нарисовано».
// Разница существенна: голден снимается на другой машине и принимается
// человеком, а эти вопросы обязаны получать ответ на каждом прогоне.

import 'package:arcadelingo/ui/streak_card.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:arcadelingo/ui/week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ritual_views.dart';

Future<void> _pump(
  WidgetTester tester, {
  required int days,
  int lastOffset = 0,
  int freezes = 0,
  List<WeekDay>? week,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: wordarcadeTheme(platform: TargetPlatform.android),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: StreakCard(
                ritual: ritualView(
                  days: days,
                  lastOffset: lastOffset,
                  freezes: freezes,
                ),
                week: week,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

double _flameHeight(WidgetTester tester) =>
    tester.getSize(find.byType(CustomPaint).first).height;

void main() {
  group('Пламя растёт вместе с серией', () {
    testWidgets('на серии 14 оно выше, чем на серии 5', (tester) async {
      await _pump(tester, days: 5);
      final steady = _flameHeight(tester);

      await _pump(tester, days: 14);

      expect(_flameHeight(tester), greaterThan(steady));
    });

    testWidgets('на серии 5 выше, чем на серии 1', (tester) async {
      await _pump(tester, days: 1);
      final spark = _flameHeight(tester);

      await _pump(tester, days: 5);

      expect(_flameHeight(tester), greaterThan(spark));
    });

    testWidgets('число дней стоит внутри пламени', (tester) async {
      await _pump(tester, days: 7);

      expect(tester.widget<Text>(find.byKey(flameDigitKey)).data, '7');
    });

    testWidgets('кегль числа растёт вместе со ступенью', (tester) async {
      await _pump(tester, days: 3);
      final steady = tester.widget<Text>(find.byKey(flameDigitKey)).style!;

      await _pump(tester, days: 20);

      expect(
        tester.widget<Text>(find.byKey(flameDigitKey)).style!.fontSize,
        greaterThan(steady.fontSize!),
      );
    });

    testWidgets('серии нет — числа нет вовсе', (tester) async {
      await _pump(tester, days: 0);

      expect(find.byKey(flameDigitKey), findsNothing);
      expect(find.byKey(streakCaptionKey), findsNothing);
    });
  });

  group('Подпись', () {
    testWidgets('без числа: оно уже в пламени', (tester) async {
      await _pump(tester, days: 5);

      final caption = tester.widget<Text>(find.byKey(streakCaptionKey)).data!;
      expect(caption, 'дней подряд');
      expect(caption, isNot(contains('5')));
    });

    testWidgets('форма слова меняется с числом', (tester) async {
      await _pump(tester, days: 1);
      expect(
        tester.widget<Text>(find.byKey(streakCaptionKey)).data,
        'день подряд',
      );

      await _pump(tester, days: 22);
      expect(
        tester.widget<Text>(find.byKey(streakCaptionKey)).data,
        'дня подряд',
      );
    });
  });

  group('Полоса недели', () {
    testWidgets('журнал ещё не прочитан — полосы нет, но место занято', (
      tester,
    ) async {
      await _pump(tester, days: 3);
      final withoutStrip = tester.getSize(find.byKey(streakCardKey)).height;

      await _pump(
        tester,
        days: 3,
        week: weekStrip(today: ritualToday, played: const {}),
      );

      expect(
        tester.getSize(find.byKey(streakCardKey)).height,
        withoutStrip,
        reason: 'карточка не прыгает, когда данные приедут',
      );
    });

    testWidgets('семь кружков', (tester) async {
      await _pump(
        tester,
        days: 3,
        week: weekStrip(today: ritualToday, played: const {}),
      );

      expect(find.byKey(weekStripKey), findsOneWidget);
      expect(find.text('Пн'), findsOneWidget);
      expect(find.text('Вс'), findsOneWidget);
    });

    testWidgets('сыгранные дни помечены галочкой, а не буквой', (tester) async {
      await _pump(
        tester,
        days: 3,
        week: weekStrip(today: ritualToday, played: {daysAgo(2)}),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(
        find.text('Пн'),
        findsNothing,
        reason: 'понедельник сыгран — на его месте галочка',
      );
    });

    testWidgets('замороженный день помечен щитом', (tester) async {
      await _pump(
        tester,
        days: 3,
        week: weekStrip(
          today: ritualToday,
          played: const {},
          frozen: daysAgo(1),
        ),
      );

      expect(find.byIcon(Icons.shield), findsOneWidget);
    });

    // Полоса не должна ломать ряд на крупном системном шрифте: она
    // уменьшается целиком, а кружки заданы в dp и остаются кружками.
    testWidgets('системный шрифт 2× не переполняет карточку', (tester) async {
      await _pump(
        tester,
        days: 12,
        week: weekStrip(today: ritualToday, played: {daysAgo(1), daysAgo(2)}),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(streakCardKey)).width,
        lessThanOrEqualTo(360 - 48),
      );
    });
  });

  group('Экранный диктор', () {
    testWidgets('пламя читается словами, а не цифрой', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, days: 5);

      expect(find.bySemanticsLabel('Серия: 5 дней'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('серии нет — так и сказано', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, days: 0);

      expect(find.bySemanticsLabel('Серии нет'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('кружок дня называет и день, и что с ним', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        days: 3,
        week: weekStrip(today: ritualToday, played: {daysAgo(2)}),
      );

      expect(find.bySemanticsLabel('Пн: сыграно'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Ср: сегодня, ещё не сыграно'),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
