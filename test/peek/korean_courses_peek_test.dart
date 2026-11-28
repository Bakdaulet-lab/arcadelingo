@Tags(['peek'])
library;

import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_review_session.dart';
import 'peek_harness.dart';

void main() {
  late ReviewItem school;
  setUpAll(() async {
    final course = StudyCourse.multilingualCourses.singleWhere(
      (course) => course.id == 'ru-ko',
    );
    final seed = await loadMultilingualSeed(course) as Ok<List<ReviewItem>>;
    school = seed.value.singleWhere((item) => item.word.text == '학교');
  });

  for (final brightness in Brightness.values) {
    testWidgets('Hangul spelling · ${brightness.name}', (tester) async {
      tester.view.physicalSize = peekPhysicalSize;
      tester.view.devicePixelRatio = peekDevicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru')],
          localizationsDelegates: const [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: wordarcadeTheme(
            platform: TargetPlatform.android,
            brightness: brightness,
          ),
          debugShowCheckedModeBanner: false,
          home: ClawMachineGame(
            session: FakeReviewSession([school]),
            studyLanguage: 'ko',
            onExit: () {},
            onPlayAgain: () {},
            seed: 7,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var letter = 0; letter < 5; letter++) {
        final hint = find.byKey(ClawKeys.hint);
        final grab = find.byKey(ClawKeys.grab);
        await tester.ensureVisible(hint);
        await tester.tap(hint);
        await tester.pumpAndSettle();
        await tester.ensureVisible(grab);
        await tester.tap(grab);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        if (letter == 2) {
          await peek(tester, 'korean_claw_syllable_${brightness.name}');
        }
      }
      await peek(tester, 'korean_claw_solved_${brightness.name}');
    });
  }
}
