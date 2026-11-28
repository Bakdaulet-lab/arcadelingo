import 'package:arcadelingo/domain/kitchen/kitchen_shift.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/order_kitchen/order_kitchen_game.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const course = StudyCourse.spanishFromRussian;
const seed = 41;

Finder keyed(String id) => find.byKey(ValueKey('kitchen.$id'));

Future<void> press(WidgetTester tester, String id) async {
  await tester.ensureVisible(keyed(id));
  await tester.pump();
  await tester.tap(keyed(id));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> open(
  WidgetTester tester, {
  Brightness brightness = Brightness.dark,
  bool reduced = false,
  double scale = 1,
  String locale = 'en',
  StudyCourse selectedCourse = course,
  VoidCallback? onExit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      supportedLocales: const [Locale('en'), Locale('es'), Locale('ru')],
      localizationsDelegates: const [
        AppStrings.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      theme: wordarcadeTheme(brightness: brightness),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduced,
            ),
            child: child!,
          ),
      home: OrderKitchenGame(
        course: selectedCourse,
        seed: seed,
        onExit: onExit ?? () {},
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets(
    'a mistaken drink can be corrected; only clean tickets earn first try',
    (tester) async {
      await open(tester);
      final orders = kitchenOrdersFor(
        course: course,
        level: CefrLevel.a1,
        seed: seed,
      );
      for (final (index, order) in orders.indexed) {
        expect(find.text(order.phrase('es')), findsOneWidget);
        expect(keyed('feedback'), findsNothing);
        if (index == 0) {
          final extra = KitchenIngredient.values.firstWhere(
            (i) => !order.ingredients.contains(i),
          );
          await press(tester, 'ingredient.${extra.name}');
          await press(tester, 'serve');
          final feedback = find.descendant(
            of: keyed('feedback'),
            matching: find.byType(Text),
          );
          final message = tester
              .widgetList<Text>(feedback)
              .map((text) => text.data)
              .join(' ');
          expect(message, contains(extra.label('ru')));
          for (final missing in order.ingredients) {
            expect(message, contains(missing.label('ru')));
          }
          expect(keyed('next'), findsNothing);
          await press(tester, 'ingredient.${extra.name}');
        }
        for (final ingredient in order.ingredients) {
          await press(tester, 'ingredient.${ingredient.name}');
        }
        await press(tester, 'serve');
        expect(keyed('next'), findsOneWidget);
        await press(tester, 'next');
      }
      expect(tester.widget<Text>(keyed('first-try')).data, contains('4/5'));
      await press(tester, 'replay');
      final nextShift = kitchenOrdersFor(
        course: course,
        level: CefrLevel.a1,
        seed: seed + 1,
      );
      expect(find.text(nextShift.first.phrase('es')), findsOneWidget);
      expect(keyed('first-try'), findsNothing);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name}: at large text every control stays reachable in reduced motion',
      (tester) async {
        tester.view.physicalSize = const Size(320, 580);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var exits = 0;
        await open(
          tester,
          brightness: brightness,
          reduced: true,
          scale: 2,
          locale: 'es',
          selectedCourse: StudyCourse.englishFromSpanish,
          onExit: () => exits++,
        );
        final first =
            kitchenOrdersFor(
              course: StudyCourse.englishFromSpanish,
              level: CefrLevel.a1,
              seed: seed,
            ).first;
        expect(find.text(first.phrase('en')), findsOneWidget);
        for (final ingredient in KitchenIngredient.values) {
          expect(find.text(ingredient.label('es')), findsOneWidget);
        }
        for (final ingredient in first.ingredients) {
          await press(tester, 'ingredient.${ingredient.name}');
        }
        await press(tester, 'serve');
        expect(keyed('next'), findsOneWidget);
        await press(tester, 'exit');
        expect(exits, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
