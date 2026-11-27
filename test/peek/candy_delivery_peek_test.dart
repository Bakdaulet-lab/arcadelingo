@Tags(['peek'])
library;

import 'package:arcadelingo/domain/candy_delivery/candy_orders.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/candy_delivery/candy_delivery_game.dart';
import 'package:arcadelingo/features/games/candy_delivery/candy_field.dart';
import 'package:arcadelingo/features/games/candy_delivery/candy_glen_art.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'peek_harness.dart';

void main() {
  const course = StudyCourse.spanishFromRussian;
  const level = CefrLevel.a2;
  final seed = Iterable<int>.generate(4096).firstWhere((seed) {
    final order =
        candyOrdersFor(course: course, level: level, seed: seed).first;
    return order.phrase == 'Para el conejo que duerme.' &&
        listEquals(order.rabbits, const [0, 1, 2]);
  });
  for (final brightness in Brightness.values) {
    testWidgets('candy glade, cut and delivery in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = peekPhysicalSize;
      tester.view.devicePixelRatio = peekDevicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: wordarcadeTheme(
            platform: TargetPlatform.android,
            brightness: brightness,
          ),
          debugShowCheckedModeBanner: false,
          supportedLocales: const [Locale('ru')],
          locale: const Locale('ru'),
          localizationsDelegates: const [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: CandyDeliveryGame(
            course: course,
            level: level,
            seed: seed,
            onExit: () {},
          ),
        ),
      );
      final context = tester.element(find.byType(CandyGlenArt));
      await tester.runAsync(
        () => precacheImage(
          CandyGlenArt.imageFor(brightness == Brightness.light),
          context,
        ),
      );
      await tester.pump();
      final prefix = 'candy_delivery_${brightness.name}';
      await peek(tester, '${prefix}_ready');
      await tester.pump(const Duration(milliseconds: 850));
      final field = tester.getRect(find.byType(CandyField));
      Offset at(double x, double y) =>
          field.topLeft + Offset(x * field.width / 360, y * field.height / 292);
      final gesture = await tester.startGesture(at(148, 72));
      await gesture.moveTo(at(245, 72));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 320));
      await peek(tester, '${prefix}_flight');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      await peek(tester, '${prefix}_delivered');
    });
  }
}
