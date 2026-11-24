import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/leitner_review_session.dart';
import 'package:arcadelingo/features/games/snake/snake_field.dart';
import 'package:arcadelingo/features/games/snake/snake_game.dart';
import 'package:arcadelingo/features/games/snake/snake_run.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

const _words = [
  Word(id: 'apple', text: 'apple', translation: 'яблоко'),
  Word(id: 'door', text: 'door', translation: 'дверь'),
  Word(id: 'fish', text: 'fish', translation: 'рыба'),
];

Future<LeitnerReviewSession> _open(
  WidgetTester tester,
  Brightness brightness, {
  bool correctAhead = true,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final session = LeitnerReviewSession.start(
    cards: {},
    items: [ReviewItem(word: _words.first)],
    target: 1,
    now: () => DateTime(2026, 11, 21),
    onCardsChanged: (_) {},
  );
  var seed = 0;
  while ((Random(seed).nextInt(3) == 1) != correctAhead) {
    seed++;
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: wordarcadeTheme(brightness: brightness),
      home: SnakeGame(
        session: session,
        vocabulary: _words,
        onPlayAgain: () {},
        onExit: () {},
        seed: seed,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

void main() {
  final field = find.byKey(SnakeKeys.field);
  for (final brightness in Brightness.values) {
    testWidgets('a short swipe steers before release ($brightness)', (
      tester,
    ) async {
      await _open(tester, brightness);
      final run = tester.widget<SnakeField>(field).run;
      final finger = await tester.startGesture(tester.getCenter(field));
      await finger.moveBy(const Offset(2, -3));
      await tester.pump();
      expect(run.phase, SnakePhase.ready);
      await finger.moveBy(const Offset(0, -7));
      await tester.pump();
      expect(run.phase, SnakePhase.moving);
      expect(run.direction, SnakeDirection.up);
      await finger.up();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the board offers accessible turn actions ($brightness)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      addTearDown(handle.dispose);
      await _open(tester, brightness);
      final strings = tester.element(field).strings;
      final node = tester.getSemantics(field);
      final ids = node.getSemanticsData().customSemanticsActionIds;
      expect(ids, hasLength(4));
      final directions = {
        for (final id in ids!) CustomSemanticsAction.getAction(id)!.label: id,
      };
      expect(
        directions.keys,
        unorderedEquals([
          strings.snakeLeft,
          strings.snakeRight,
          strings.snakeUp,
          strings.snakeDown,
        ]),
      );
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.customAction,
        directions[strings.snakeDown],
      );
      await tester.pump();
      expect(
        tester.widget<SnakeField>(field).run.direction,
        SnakeDirection.down,
      );
      expect(find.byType(OutlinedButton), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('one continuous swipe turns around a corner ($brightness)', (
      tester,
    ) async {
      final session = await _open(tester, brightness);
      final finger = await tester.startGesture(tester.getCenter(field));
      await finger.moveBy(const Offset(48, 0));
      await tester.pump();
      final run = tester.widget<SnakeField>(field).run;
      expect(run.body.first, (x: 6, y: 6));
      await finger.moveBy(const Offset(0, -48));
      await tester.pump(SnakeRun.stepTime);
      expect(run.body.first, (x: 6, y: 5));
      await finger.up();
      expect(session.answered, 0);
      await tester.tap(find.byKey(SnakeKeys.pause));
      await tester.pumpAndSettle();
    });

    for (final correct in [true, false]) {
      testWidgets('apple reaction ($brightness, correct=$correct)', (
        tester,
      ) async {
        final session = await _open(tester, brightness, correctAhead: correct);
        final run = tester.widget<SnakeField>(field).run;
        final eaten =
            run.apples.singleWhere((apple) => apple.cell == (x: 8, y: 6)).word;
        final message = tester
            .element(field)
            .strings
            .snakeAnswer(_words.first, eaten, correct: correct);
        await tester.drag(field, const Offset(24, 0));
        await tester.pump();
        await tester.pump(SnakeRun.stepTime);
        await tester.pump(SnakeRun.stepTime);
        expect(session.answered, 1);
        expect(run.answerCorrect, correct);
        final text = find.text(message);
        await tester.pump(const Duration(milliseconds: 60));
        final moving = tester.getRect(text);
        await tester.pumpAndSettle();
        expect(tester.getRect(text), isNot(moving));
        expect(session.answered, 1);
        expect(find.byKey(SnakeKeys.next), findsOneWidget);
      });
    }
  }
}
