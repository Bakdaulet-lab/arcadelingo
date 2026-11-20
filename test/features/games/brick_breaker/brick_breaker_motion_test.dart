import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_field.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_game.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_run.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';
import '../../../support/review_items.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final correct in [true, false]) {
      testWidgets('ловля ответа даёт короткий акцент, $brightness/$correct', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        final session = FakeReviewSession(wordItems(1));
        await tester.pumpWidget(
          MaterialApp(
            theme: wordarcadeTheme(brightness: brightness),
            home: BrickBreakerGame(
              session: session,
              seed: 4,
              onExit: () {},
              onPlayAgain: () {},
            ),
          ),
        );
        await tester.tap(find.byKey(BrickBreakerKeys.launch));
        await tester.pump();
        final field = find.byType(BrickBreakerField);
        final run = tester.widget<BrickBreakerField>(field).run;
        for (
          var frame = 0;
          frame < 60 && run.phase != BrickPhase.bonus;
          frame++
        ) {
          await tester.pump(const Duration(milliseconds: 32));
        }
        expect(run.phase, BrickPhase.bonus);
        final choice = run.choices.firstWhere(
          (s) => (s == wordTranslation(1)) == correct,
        );
        final finger = await tester.startGesture(
          tester.getCenter(find.text(choice)),
        );
        await finger.up();
        final strings = tester.element(field).strings;
        for (
          var frame = 0;
          frame < 150 && run.phase == BrickPhase.bonus;
          frame++
        ) {
          await tester.pump(const Duration(milliseconds: 32));
        }
        expect(run.phase, BrickPhase.feedback);
        expect(session.reports.single.outcome.correct, correct);
        final badge = find.text(correct ? strings.correct : strings.mistake);
        await tester.pump(const Duration(milliseconds: 90));
        final moving = tester.getCenter(badge);
        await tester.pump(const Duration(milliseconds: 200));
        final resting = tester.getCenter(badge);
        expect((moving - resting).distance, greaterThan(.3));
        expect(session.reports, hasLength(1));
      });
    }
  }
}
