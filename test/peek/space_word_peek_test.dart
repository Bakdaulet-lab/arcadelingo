@Tags(['peek'])
library;

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/space_word/space_field.dart';
import 'package:arcadelingo/features/games/space_word/space_word_game.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_review_session.dart';
import 'peek_harness.dart';

void main() {
  const words = [
    Word(id: 'luna', text: 'luna', translation: 'луна'),
    Word(id: 'sol', text: 'sol', translation: 'солнце'),
    Word(id: 'nube', text: 'nube', translation: 'облако'),
    Word(id: 'mar', text: 'mar', translation: 'море'),
    Word(id: 'cielo', text: 'cielo', translation: 'небо'),
  ];
  for (final brightness in Brightness.values) {
    testWidgets('Space Word launch and flight in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = peekPhysicalSize;
      tester.view.devicePixelRatio = peekDevicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: wordarcadeTheme(
            brightness: brightness,
            platform: TargetPlatform.android,
          ),
          supportedLocales: const [Locale('ru')],
          locale: const Locale('ru'),
          localizationsDelegates: const [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: SpaceWordGame(
            session: FakeReviewSession([
              for (final word in words) ReviewItem(word: word),
            ]),
            vocabulary: words,
            course: StudyCourse.spanishFromRussian,
            level: CefrLevel.a1,
            seed: 3,
            onExit: () {},
            onPlayAgain: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(SpaceField));
      final path =
          'assets/images/space_word/${brightness == Brightness.dark ? 'night' : 'day'}.webp';
      await tester.runAsync(
        () => precacheImage(ExactAssetImage(path, bundle: rootBundle), context),
      );
      await tester.pump();
      final prefix = 'space_word_${brightness.name}';
      await peek(tester, '${prefix}_ready');
      await tester.tap(find.byKey(SpaceWordKeys.start));
      await tester.pump();
      final field = tester.widget<SpaceField>(find.byType(SpaceField));
      final drone = field.flight.drones[field.labels.indexOf('luna')];
      final left = drone.position.dx < field.flight.ship.dx;
      final key =
          left ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight;
      var moving = (drone.position.dx - field.flight.ship.dx).abs() > 6;
      if (moving) await tester.sendKeyDownEvent(key);
      for (var frame = 0; frame < 96; frame++) {
        if (moving && (drone.position.dx - field.flight.ship.dx).abs() <= 6) {
          await tester.sendKeyUpEvent(key);
          moving = false;
        }
        if (frame == 23) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        }
        if (frame == 58) await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        if (frame == 60) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
        }
        if (frame == 73) {
          await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
        }
        await tester.pump(const Duration(microseconds: 16667));
        if (frame == 27) await peek(tester, '${prefix}_flight');
        if (const bool.fromEnvironment('SPACE_WORD_MOTION') && frame.isEven) {
          await peek(
            tester,
            '${prefix}_motion_${frame.toString().padLeft(2, '0')}',
          );
        }
      }
      if (moving) await tester.sendKeyUpEvent(key);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
