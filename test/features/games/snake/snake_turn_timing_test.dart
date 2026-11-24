import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/leitner_review_session.dart';
import 'package:arcadelingo/features/games/snake/snake_field.dart';
import 'package:arcadelingo/features/games/snake/snake_game.dart';
import 'package:arcadelingo/features/games/snake/snake_run.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const words = [
    Word(id: 'road', text: 'road', translation: 'дорога'),
    Word(id: 'cat', text: 'cat', translation: 'кот'),
  ];

  for (final theme in Brightness.values) {
    testWidgets('rapid turns and pause keep continuous motion ($theme)', (
      tester,
    ) async {
      final session = LeitnerReviewSession.start(
        items: [ReviewItem(word: words.first)],
        cards: {},
        target: 1,
        now: () => DateTime(2026, 11, 24),
        onCardsChanged: (_) {},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: wordarcadeTheme(brightness: theme),
          home: SnakeGame(
            session: session,
            vocabulary: words,
            onPlayAgain: () {},
            onExit: () {},
            seed: 3,
          ),
        ),
      );
      final field = tester.widget<SnakeField>(find.byKey(SnakeKeys.field));
      final run = field.run;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final atInput = field.motion.value;
      expect(atInput, inExclusiveRange(0.0, .5));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(field.motion.value, closeTo(atInput, .001));
      await tester.pump(const Duration(milliseconds: 30));
      expect(field.motion.value, inExclusiveRange(atInput, 1.0));
      await tester.pump(const Duration(milliseconds: 65));
      expect(run.body.first, (x: 6, y: 5));
      await tester.pump(const Duration(milliseconds: 95));
      expect(run.body.first, (x: 5, y: 5));
      await tester.pump(const Duration(milliseconds: 90));
      final beforePause = field.motion.value;
      expect(beforePause, inExclusiveRange(0.0, .7));
      await tester.tap(find.byKey(SnakeKeys.pause));
      await tester.pump(const Duration(seconds: 2));
      expect(field.motion.value, closeTo(beforePause, .001));
      await tester.tap(find.byKey(SnakeKeys.resume));
      await tester.pump();
      expect(run.body.first, (x: 5, y: 5));
      expect(field.motion.value, closeTo(beforePause, .001));
      await tester.pump(const Duration(milliseconds: 40));
      expect(field.motion.value, greaterThan(beforePause));
      expect(session.answered, 0);
    });
  }
}
