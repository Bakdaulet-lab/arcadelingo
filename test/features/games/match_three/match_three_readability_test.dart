import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/match_three/match_three_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'single words that are too wide for columns get full rows, $brightness',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 650);
        addTearDown(tester.view.reset);
        const translation = 'производство';
        const decoys = ['перспектива', 'действие'];
        final session = FakeReviewSession([
          const ReviewItem(
            word: Word(
              id: 'production',
              text: 'production',
              translation: translation,
            ),
            distractors: decoys,
          ),
        ]);
        await tester.pumpWidget(
          MaterialApp(
            theme: wordarcadeTheme(brightness: brightness),
            home: MatchThreeGame(
              session: session,
              seed: 10,
              onExit: () {},
              onPlayAgain: () {},
            ),
          ),
        );
        for (final cell in [9, 15]) {
          await tester.tap(find.byKey(MatchThreeKeys.cell(cell)));
          await tester.pumpAndSettle();
        }
        final cards = [
          for (final choice in [translation, ...decoys])
            find.widgetWithText(OutlinedButton, choice),
        ];
        expect(
          cards.map((card) => tester.getRect(card).center.dy).toSet(),
          hasLength(3),
        );
        expect(cards.every((card) => tester.getSize(card).width > 210), isTrue);
        await tester.ensureVisible(find.text(translation));
        await tester.tap(find.text(translation));
        await tester.pumpAndSettle();
        expect(session.reports.single.outcome.selectedAnswer, translation);
        expect(session.reports.single.outcome.correct, isTrue);
      },
    );
  }
}
