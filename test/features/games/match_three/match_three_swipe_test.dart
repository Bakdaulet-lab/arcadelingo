import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/match_three/match_three_field.dart';
import 'package:arcadelingo/features/games/match_three/match_three_game.dart';
import 'package:arcadelingo/features/games/match_three/match_three_run.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';

void main() {
  testWidgets(
    'the two gems follow a short drag, return on cancel, and continue from the finger on commit',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: wordarcadeTheme(),
          home: MatchThreeGame(
            session: FakeReviewSession(const [
              ReviewItem(
                word: Word(id: 'sun', text: 'sun', translation: 'солнце'),
              ),
            ]),
            onPlayAgain: () {},
            onExit: () {},
            seed: 10,
          ),
        ),
      );
      Finder piece(int index) =>
          find.byKey(ValueKey('match_three.piece.$index'));
      final origin = tester.getCenter(piece(9));
      final dest = tester.getCenter(piece(15));
      final step = dest.dy - origin.dy;
      final short = await tester.startGesture(origin);
      await short.moveBy(Offset(0, step * .14));
      await tester.pump();
      expect(tester.getCenter(piece(9)).dy, closeTo(origin.dy + step * .14, 1));
      expect(tester.getCenter(piece(15)).dy, closeTo(dest.dy - step * .14, 1));
      await short.cancel();
      await tester.pumpAndSettle();
      expect(tester.getCenter(piece(9)), origin);
      expect(tester.getCenter(piece(15)), dest);

      final swap = await tester.startGesture(origin);
      await swap.moveBy(Offset(0, step * .32));
      await tester.pump();
      // The model now indexes the original piece at its destination (15).
      expect(
        tester.getCenter(piece(15)).dy,
        closeTo(origin.dy + step * .32, 1),
      );
      await swap.up();
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.getCenter(piece(15)).dy,
        greaterThan(origin.dy + step * .32 + 1),
      );
    },
  );

  // Both axes pass touch slop in a single pointer event, as can happen on a
  // quick diagonal swipe. The larger displacement must determine the exchange.
  for (final (delta, neighbor) in const [
    (Offset(34, 23), 10),
    (Offset(-34, 23), 8),
    (Offset(22, 33), 15),
    (Offset(-22, -33), 3),
  ]) {
    testWidgets('diagonal $delta swaps 9 and $neighbor without scrolling', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(
        MaterialApp(
          theme: wordarcadeTheme(),
          home: MatchThreeGame(
            session: FakeReviewSession(const [
              ReviewItem(
                word: Word(id: 'sun', text: 'sun', translation: 'солнце'),
              ),
            ]),
            onPlayAgain: () {},
            onExit: () {},
            seed: 10,
          ),
        ),
      );
      final from = find.byKey(MatchThreeKeys.cell(9));
      await tester.ensureVisible(from);
      await tester.pumpAndSettle();
      final field = find.byType(MatchThreeField);
      final run = tester.widget<MatchThreeField>(field).run;
      final scroll = Scrollable.of(tester.element(from)).position;
      expect(scroll.maxScrollExtent, greaterThan(0));
      final startOffset = scroll.pixels;
      final origin = tester.getCenter(from);
      final cancelled = await tester.startGesture(origin);
      await cancelled.moveBy(const Offset(3, 4));
      await cancelled.cancel();
      await tester.pump();
      expect(run.phase, MatchThreePhase.ready);
      expect(tester.widget<MatchThreeField>(field).selected, isNull);
      final gesture = await tester.startGesture(origin);
      await gesture.moveBy(delta);
      await tester.pump();
      expect(run.phase, MatchThreePhase.swapping);
      expect(run.travel.keys, unorderedEquals([9, neighbor]));
      await gesture.moveBy(delta);
      await gesture.up();
      expect(scroll.pixels, startOffset);
      expect(run.travel.keys, unorderedEquals([9, neighbor]));
    });
  }
}
