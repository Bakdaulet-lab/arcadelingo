import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/word_maze/maze_field.dart';
import 'package:arcadelingo/features/games/word_maze/maze_run.dart';
import 'package:arcadelingo/features/games/word_maze/word_maze_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';

const target = Word(id: 'key', text: 'llave', translation: 'ключ');
const candle = Word(id: 'candle', text: 'vela', translation: 'свеча');
const table = Word(id: 'table', text: 'mesa', translation: 'стол');

Future<void> mountGame(
  WidgetTester tester,
  FakeReviewSession session,
  List<Word> vocabulary, {
  Brightness brightness = Brightness.dark,
  VoidCallback? onOver,
  VoidCallback? onReplay,
  VoidCallback? onExit,
  int seed = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: wordarcadeTheme(
        brightness: brightness,
        platform: TargetPlatform.android,
      ),
      home: WordMazeGame(
        key: ObjectKey(session),
        session: session,
        vocabulary: vocabulary,
        seed: seed,
        course: StudyCourse.spanishFromRussian,
        level: CefrLevel.a1,
        onRoundOver: onOver,
        onPlayAgain: onReplay ?? () {},
        onExit: onExit ?? () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> reachNorthGate(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
  for (
    var frame = 0;
    frame < 400 && find.byKey(MazeKeys.next).evaluate().isEmpty;
    frame++
  ) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(find.byKey(MazeKeys.next), findsOneWidget);
}

void main() {
  testWidgets('answer and next question keep the field and prompt in place', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = FakeReviewSession(const [
      ReviewItem(word: target),
      ReviewItem(word: candle),
    ]);
    await mountGame(tester, session, [target, candle, table]);
    final field = find.byKey(MazeKeys.field);
    final prompt = find.byKey(MazeKeys.word);
    final frame = tester.getRect(field);
    final label = tester.getTopLeft(prompt);
    await reachNorthGate(tester);
    await tester.pumpAndSettle();
    expect(tester.getRect(field), frame);
    expect(tester.getTopLeft(prompt), label);
    await tester.tap(find.byKey(MazeKeys.next));
    await tester.pumpAndSettle();
    expect(tester.getRect(field), frame);
    expect(tester.getTopLeft(prompt), label);
  });

  testWidgets(
    'system back closes the pending review once without inventing a selected gate',
    (tester) async {
      final session = FakeReviewSession(const [ReviewItem(word: target)]);
      var finished = 0;
      final game = WordMazeGame(
        session: session,
        vocabulary: const [target],
        onPlayAgain: () {},
        onExit: () {},
        onRoundOver: () => finished++,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  child: const Text('open'),
                  onPressed:
                      () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute<void>(builder: (_) => game)),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final outcome = session.reports.single.outcome;
      expect(outcome.correct, isFalse);
      expect(outcome.selectedAnswer, isNull);
      expect(outcome.timedOut, isFalse);
      expect(finished, 0);
    },
  );

  testWidgets(
    'being caught returns to the same word and keeps its collected dots',
    (tester) async {
      final session = FakeReviewSession(const [ReviewItem(word: target)]);
      await mountGame(tester, session, [target, candle, table]);
      final field = find.byKey(MazeKeys.field);
      final run = tester.widget<MazeField>(field).run;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      for (
        var frame = 0;
        frame < 1000 && find.byKey(MazeKeys.respawn).evaluate().isEmpty;
        frame++
      ) {
        await tester.pump(const Duration(milliseconds: 32));
      }
      expect(find.byKey(MazeKeys.respawn), findsOneWidget);
      expect(session.reports, isEmpty);
      final collected = run.collected;
      expect(collected, greaterThan(0));
      await tester.tap(find.byKey(MazeKeys.respawn));
      await tester.pumpAndSettle();
      expect(find.byKey(MazeKeys.respawn), findsNothing);
      expect(run.collected, collected);
      expect(session.nextItemCalls, 1);
      await reachNorthGate(tester);
      expect(session.reports, hasLength(1));
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'gate alone reports the answer, final result and replay in ${brightness.name}',
      (tester) async {
        final session = FakeReviewSession(const [ReviewItem(word: target)]);
        var finishes = 0;
        var replays = 0;
        await mountGame(
          tester,
          session,
          [target],
          brightness: brightness,
          onOver: () => finishes++,
          onReplay: () => replays++,
        );
        expect(find.byKey(MazeKeys.word), findsOneWidget);
        expect(find.text('ключ'), findsOneWidget);
        final gate = find.byKey(MazeKeys.gate(0));
        expect(tester.widget<Text>(gate).data, 'llave');
        await tester.ensureVisible(gate);
        await tester.tap(gate);
        await tester.pump(const Duration(seconds: 4));
        expect(session.reports, isEmpty);
        await reachNorthGate(tester);
        final outcome = session.reports.single.outcome;
        expect(outcome.correct, isTrue);
        expect(outcome.selectedAnswer, 'llave');
        expect(outcome.isUntimed, isTrue);
        expect(find.byKey(MazeKeys.feedback), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump(const Duration(seconds: 2));
        expect(session.reports, hasLength(1));
        final next = find.byKey(MazeKeys.next);
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(find.byKey(MazeKeys.summary), findsOneWidget);
        expect(finishes, 1);
        await tester.tap(find.text('Ещё раз'));
        expect(replays, 1);
      },
    );
  }

  testWidgets(
    'incorrect gate records chosen spelling and reveals the intended pair',
    (tester) async {
      late FakeReviewSession session;
      late String northLabel;
      for (var seed = 0; seed < 10; seed++) {
        session = FakeReviewSession(const [ReviewItem(word: target)]);
        await mountGame(tester, session, [target, candle, table], seed: seed);
        northLabel = tester.widget<Text>(find.byKey(MazeKeys.gate(1))).data!;
        if (northLabel != 'llave') break;
      }
      expect(northLabel, isNot('llave'));
      await reachNorthGate(tester);
      expect(session.reports.single.outcome.correct, isFalse);
      expect(session.reports.single.outcome.selectedAnswer, northLabel);
      expect(find.textContaining('llave — ключ'), findsOneWidget);
    },
  );

  testWidgets(
    'pausing freezes the maze until explicit resume and caps frame stalls',
    (tester) async {
      final session = FakeReviewSession(const [ReviewItem(word: target)]);
      await mountGame(tester, session, [target, candle, table]);
      final run = tester.widget<MazeField>(find.byKey(MazeKeys.field)).run;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      expect(run.player.y, lessThan(MazeRun.spawn.y));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      final position = run.player;
      await tester.pump(const Duration(seconds: 60));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(run.player, position);
      expect(find.byKey(MazeKeys.resume), findsOneWidget);
      await tester.tap(find.byKey(MazeKeys.resume));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect((run.player.y - position.y).abs(), lessThan(1));
      expect(session.reports, isEmpty);
    },
  );

  testWidgets(
    'shows only unambiguous options of the requested level and supports large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 610);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final session = FakeReviewSession(const [ReviewItem(word: target)]);
      await mountGame(tester, session, const [
        target,
        candle,
        Word(id: 'synonym', text: 'clave', translation: 'ключ; код'),
        Word(id: 'homonym', text: 'clave', translation: 'секрет'),
        Word(
          id: 'foreign_level',
          text: 'carretera',
          translation: 'шоссе',
          level: CefrLevel.b1,
        ),
      ]);
      expect(find.text('llave'), findsOneWidget);
      expect(find.text('vela'), findsOneWidget);
      expect(find.text('clave'), findsNothing);
      expect(find.text('carretera'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
