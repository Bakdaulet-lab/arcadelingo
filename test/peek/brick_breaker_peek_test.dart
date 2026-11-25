@Tags(['peek'])
library;

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_field.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_game.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_run.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_review_session.dart';
import 'peek_harness.dart';

const _agua = ReviewItem(
  word: Word(id: 'agua', text: 'agua', translation: 'вода'),
  distractors: ['сок', 'вино', 'чай'],
);

void main() {
  testWidgets('испытание арканоида', (tester) async {
    await pumpPeek(
      tester,
      BrickBreakerGame(
        session: FakeReviewSession([_agua, _agua, _agua]),
        onExit: () {},
        onPlayAgain: () {},
        onChallengeComplete: (_) => const SizedBox.shrink(),
        seed: 19,
      ),
    );
    await tester.pumpAndSettle();
    await peek(tester, 'brick_three_golden_bricks');
  });

  for (final brightness in Brightness.values) {
    testWidgets('полные переводы на узком телефоне в теме ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(640, 1440);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      const pertinent = ReviewItem(
        word: Word(
          id: 'pertinent',
          text: 'pertinent',
          translation: 'непосредственно связанный с вопросом',
        ),
        distractors: [
          'не имеющий отношения к теме',
          'преждевременно высказанный',
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: wordarcadeTheme(
            brightness: brightness,
            platform: TargetPlatform.android,
          ),
          home: BrickBreakerGame(
            session: FakeReviewSession([pertinent, pertinent]),
            onExit: () {},
            onPlayAgain: () {},
            seed: 19,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BrickBreakerKeys.launch));
      await tester.pump();
      final run =
          tester.widget<BrickBreakerField>(find.byType(BrickBreakerField)).run;
      while (run.phase == BrickPhase.flying) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final initial = run.dropY;
      while (run.phase == BrickPhase.bonus &&
          run.dropY < (initial + BrickBreakerRun.paddleY) / 2) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await peek(tester, 'brick_${brightness.name}_long_words');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('арканоид в теме ${brightness.name}', (tester) async {
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
          home: BrickBreakerGame(
            session: FakeReviewSession([_agua, _agua]),
            onExit: () {},
            onPlayAgain: () {},
            seed: 19,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await peek(tester, 'brick_${brightness.name}_ready');
      await tester.tap(find.byKey(BrickBreakerKeys.launch));
      for (var i = 0; i < 65; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      if (brightness == Brightness.dark) {
        await peek(tester, 'brick_dark_impact');
      }
      for (var i = 65; i < 140; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await peek(tester, 'brick_${brightness.name}_bonus');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
