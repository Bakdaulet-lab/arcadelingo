import 'package:arcadelingo/domain/candy_delivery/candy_orders.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/candy_delivery/candy_delivery_game.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

final _courses = [
  StudyCourse.spanishFromRussian,
  StudyCourse.spanishFromEnglish,
  StudyCourse.englishFromRussian,
  StudyCourse.englishFromSpanish,
  ...StudyCourse.kazakhCourses,
  ...StudyCourse.germanCourses,
  ...StudyCourse.multilingualCourses.where(
    (course) => const {'ko', 'ja', 'tr'}.contains(course.studyLanguage),
  ),
];

Finder _control(String name) => find.byKey(ValueKey('candy.$name'));

Future<void> _open(
  WidgetTester tester,
  StudyCourse course,
  CefrLevel level, {
  required Brightness brightness,
  double textScale = 1,
  int seed = 37,
}) async {
  // The interface language is deliberately neither language in the lesson.
  final locale = const ['ru', 'es', 'en'].firstWhere(
    (tag) => tag != course.studyLanguage && tag != course.translationLanguage,
  );
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      supportedLocales: const [Locale('ru'), Locale('en'), Locale('es')],
      localizationsDelegates: const [
        AppStrings.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      theme: wordarcadeTheme(brightness: brightness),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: child!,
          ),
      home: CandyDeliveryGame(
        course: course,
        level: level,
        seed: seed,
        onExit: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _press(WidgetTester tester, String name) async {
  final button = _control(name);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  expect(button.hitTestable(), findsOneWidget, reason: name);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'changing course or level refreshes every on-screen order and gloss',
    (tester) async {
      State? firstState;
      var combinations = 0;
      for (final course in _courses) {
        for (final level in CefrLevel.values) {
          final orders = candyOrdersFor(course: course, level: level, seed: 37);
          await _open(
            tester,
            course,
            level,
            brightness: Brightness.values[combinations % 2],
          );
          // Replacing the whole app with a new State would hide stale cached orders.
          final state = tester.state(find.byType(CandyDeliveryGame));
          firstState ??= state;
          expect(identical(state, firstState), isTrue);
          if (orders.isEmpty) {
            expect(_control('cut'), findsNothing);
            expect(_control('hint'), findsNothing);
            expect(_control('replay'), findsNothing);
            continue;
          }
          combinations++;
          final strings =
              tester.element(find.byType(CandyDeliveryGame)).strings;
          expect(find.text(strings.candyDelivery), findsOneWidget);
          for (final (i, order) in orders.indexed) {
            expect(find.text(order.phrase), findsOneWidget);
            expect(find.text(order.translation), findsNothing);
            await _press(tester, 'hint');
            expect(find.text(order.translation), findsOneWidget);
            await _press(tester, 'aim.${order.rabbits.indexOf(order.target)}');
            await _press(tester, 'cut');
            expect(find.text(strings.candyDelivered), findsOneWidget);
            if (i < orders.length - 1) await _press(tester, 'next');
          }
          expect(_control('replay'), findsOneWidget);
        }
      }
      expect(combinations, 112);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name}: long order at 320 dp and 200% text can still be delivered',
      (tester) async {
        tester.view.physicalSize = const Size(320, 570);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const course = StudyCourse.englishFromRussian;
        const level = CefrLevel.c2;
        final seeds = List.generate(40, (i) => i);
        CandyOrder first(int seed) =>
            candyOrdersFor(course: course, level: level, seed: seed).first;
        final seed = seeds.reduce(
          (a, b) => first(a).phrase.length > first(b).phrase.length ? a : b,
        );
        final order = first(seed);
        expect(order.phrase.length, greaterThan(80));
        await _open(
          tester,
          course,
          level,
          brightness: brightness,
          textScale: 2,
          seed: seed,
        );
        expect(find.text(order.phrase), findsOneWidget);
        await _press(tester, 'hint');
        expect(find.text(order.translation), findsOneWidget);
        await _press(tester, 'aim.${order.rabbits.indexOf(order.target)}');
        await _press(tester, 'cut');
        await _press(tester, 'next');
        expect(find.text(order.phrase), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
