import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/leitner_review_session.dart';
import 'package:arcadelingo/features/games/snake/snake_field.dart';
import 'package:arcadelingo/features/games/snake/snake_game.dart';
import 'package:arcadelingo/features/games/snake/snake_run.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const words = [
    Word(id: 'road', text: 'road', translation: 'дорога'),
    Word(id: 'cat', text: 'cat', translation: 'кот'),
  ];

  testWidgets('background time does not skip the final glide onto an apple', (
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
        home: SnakeGame(
          session: session,
          vocabulary: words,
          seed: 3,
          onPlayAgain: () {},
          onExit: () {},
        ),
      ),
    );
    final field = tester.widget<SnakeField>(find.byKey(SnakeKeys.field));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(SnakeRun.stepTime);
    await tester.pump(SnakeRun.stepTime);
    await tester.pump(const Duration(milliseconds: 80));
    expect(field.run.phase, SnakePhase.feedback);
    final atBackground = field.motion.value;
    expect(atBackground, inExclusiveRange(.05, .9));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    // Simulate the gap between the last platform frame and the first resumed one.
    await tester.pump(const Duration(seconds: 3));
    expect(field.motion.value, closeTo(atBackground, .001));
    await tester.pump(const Duration(milliseconds: 32));
    expect(field.motion.value, inExclusiveRange(atBackground, 1.0));
    expect(session.answered, 1);
  });

  for (final theme in Brightness.values) {
    testWidgets(
      'continuous play shows the next word after a wrong apple ($theme)',
      (tester) async {
        final session = LeitnerReviewSession.start(
          items: [for (final word in words) ReviewItem(word: word)],
          cards: {},
          target: 2,
          now: () => DateTime(2026, 11, 24),
          onCardsChanged: (_) {},
        );
        var finishes = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: wordarcadeTheme(brightness: theme),
            home: SnakeGame(
              session: session,
              vocabulary: words,
              continuous: true,
              onPlayAgain: () {},
              onExit: () {},
              onRoundOver: () => finishes++,
              seed: Iterable<int>.generate(
                30,
              ).firstWhere((seed) => Random(seed).nextInt(3) == 0),
            ),
          ),
        );
        final field = find.byKey(SnakeKeys.field);
        final run = tester.widget<SnakeField>(field).run;
        final eaten =
            run.apples.singleWhere((a) => a.cell == (x: 8, y: 6)).word;
        expect(eaten, words.last);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        await tester.pump(run.pace);
        await tester.pump(run.pace);
        expect(session.answered, 1);
        expect(run.phase, SnakePhase.moving);
        expect(
          tester.widget<Text>(find.byKey(SnakeKeys.word)).data,
          words.last.translation,
        );
        expect(
          find.text(
            tester
                .element(field)
                .strings
                .snakeAnswer(words.first, eaten, correct: false),
          ),
          findsOneWidget,
        );
        expect(find.byKey(SnakeKeys.next), findsNothing);
        await tester.tap(find.byKey(SnakeKeys.pause));
        await tester.pump();
        await tester.tap(find.byKey(SnakeKeys.finish));
        await tester.pumpAndSettle();
        expect(finishes, 1);
        expect(find.byKey(SnakeKeys.summary), findsOneWidget);
        expect(session.answered, 1);
      },
    );

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
