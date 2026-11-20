import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/leitner_review_session.dart';
import 'package:arcadelingo/features/games/snake/snake_field.dart';
import 'package:arcadelingo/features/games/snake/snake_game.dart';
import 'package:arcadelingo/features/games/snake/snake_run.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const words = [
    Word(id: 'cat', text: 'cat', translation: 'кот'),
    Word(id: 'dog', text: 'dog', translation: 'собака'),
    Word(id: 'sun', text: 'sun', translation: 'солнце'),
  ];
  for (final theme in Brightness.values) {
    testWidgets('diagonal starts along its dominant axis in ${theme.name}', (
      tester,
    ) async {
      final session = LeitnerReviewSession.start(
        items: [ReviewItem(word: words.first)],
        cards: {},
        target: 1,
        now: () => DateTime(2026, 11, 21),
        onCardsChanged: (_) {},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: wordarcadeTheme(brightness: theme),
          home: SnakeGame(
            session: session,
            vocabulary: words,
            onExit: () {},
            onPlayAgain: () {},
            seed: 3,
          ),
        ),
      );
      final field = find.byKey(SnakeKeys.field);
      await tester.ensureVisible(field);
      final finger = await tester.startGesture(tester.getCenter(field));
      await finger.moveBy(const Offset(34, 23));
      await tester.pump();
      final run = tester.widget<SnakeField>(field).run;
      expect(run.direction, SnakeDirection.right);
      expect(run.body.first, (x: 6, y: 6));
      await finger.moveBy(const Offset(8, -38));
      await tester.pump(SnakeRun.stepTime);
      expect(run.direction, SnakeDirection.up);
      await finger.up();
      await tester.ensureVisible(find.byKey(SnakeKeys.pause));
      await tester.tap(find.byKey(SnakeKeys.pause));
      await tester.pumpAndSettle();
    });
  }
}
