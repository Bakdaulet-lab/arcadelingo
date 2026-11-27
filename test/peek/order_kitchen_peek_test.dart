@Tags(['peek'])
library;

import 'package:arcadelingo/domain/kitchen/kitchen_shift.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/order_kitchen/order_kitchen_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'peek_harness.dart';

void main() {
  const course = StudyCourse.spanishFromRussian;
  final seed = Iterable<int>.generate(100).firstWhere(
    (seed) =>
        kitchenOrdersFor(course: course, level: CefrLevel.a1, seed: seed).any(
          (order) =>
              order.phrase('es').contains('sin azúcar') &&
              order.ingredients.contains(KitchenIngredient.coffee),
        ),
  );
  final orders = kitchenOrdersFor(
    course: course,
    level: CefrLevel.a1,
    seed: seed,
  );
  for (final brightness in Brightness.values) {
    testWidgets('café counter, order and handoff in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = peekPhysicalSize;
      tester.view.devicePixelRatio = peekDevicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: wordarcadeTheme(
            brightness: brightness,
            platform: TargetPlatform.android,
          ),
          debugShowCheckedModeBanner: false,
          home: OrderKitchenGame(course: course, seed: seed, onExit: () {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      Future<void> tap(String id) async {
        final target = find.byKey(Key('kitchen.$id'));
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pump();
      }

      final name = 'order_kitchen_${brightness.name}';
      for (final order in orders) {
        final capture =
            order.ingredients.contains(KitchenIngredient.coffee) &&
            order.phrase('es').contains('sin azúcar');
        if (capture) await peek(tester, '${name}_order');
        for (final ingredient in order.ingredients) {
          await tap('ingredient.${ingredient.name}');
          await tester.pump(const Duration(milliseconds: 340));
        }
        if (capture) await peek(tester, '${name}_prepared');
        await tap('serve');
        await tester.pump(const Duration(milliseconds: 480));
        if (capture) {
          await peek(tester, '${name}_served');
          break;
        }
        await tap('next');
        await tester.pump(const Duration(milliseconds: 450));
      }
    });
  }
}
