import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/match_three/match_three_field.dart';
import 'package:arcadelingo/features/games/match_three/match_three_game.dart';
import 'package:arcadelingo/features/games/match_three/match_three_run.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';

const _item = ReviewItem(
  word: Word(id: 'moon', text: 'moon', translation: 'луна'),
  distractors: ['солнце', 'звезда'],
);

void main() {
  for (final theme in Brightness.values) {
    for (final correct in [true, false]) {
      testWidgets('swap on drag, then answer $correct in ${theme.name}', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        final session = FakeReviewSession([_item]);
        await tester.pumpWidget(
          MaterialApp(
            theme: wordarcadeTheme(brightness: theme),
            home: MatchThreeGame(
              session: session,
              onPlayAgain: () {},
              onExit: () {},
              seed: 10,
            ),
          ),
        );
        final field = find.byKey(MatchThreeKeys.field);
        final run = tester.widget<MatchThreeField>(field).run;
        final first = tester.getCenter(find.byKey(MatchThreeKeys.cell(9)));
        final second = tester.getCenter(find.byKey(MatchThreeKeys.cell(15)));
        final finger = await tester.startGesture(first);
        await finger.moveBy((second - first) * .55);
        await tester.pump();
        expect(run.phase, MatchThreePhase.swapping);
        await finger.moveTo(second);
        await finger.up();
        await tester.pumpAndSettle();
        expect(run.moves, MatchThreeRun.moveLimit - 1);
        expect(run.phase, MatchThreePhase.question);

        final strings = tester.element(field).strings;
        final value = correct ? 'луна' : 'солнце';
        await tester.tap(find.text(value));
        await tester.pump();
        expect(session.reports.single.outcome.correct, correct);
        final label = find.text(
          correct ? strings.correct : '${strings.correctTranslation} — луна',
        );
        expect(label, findsOneWidget);
        // Measure the feedback itself; the board and the answers stay in place.
        await tester.pump(const Duration(milliseconds: 60));
        final moving = tester
            .renderObject<RenderBox>(label)
            .getTransformTo(null);
        await tester.pump(const Duration(milliseconds: 400));
        final settled = tester
            .renderObject<RenderBox>(label)
            .getTransformTo(null);
        expect(moving, isNot(equals(settled)));
        expect(run.phase, MatchThreePhase.feedback);
        await tester.pumpAndSettle();
        expect(session.reports, hasLength(1));
      });
    }
  }
}
