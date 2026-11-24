import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/learning/custom_review_items.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/domain/usecases/start_session.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/match_three/match_three_game.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/features/games/snake/snake_field.dart';
import 'package:arcadelingo/features/games/snake/snake_run.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/claw_actions.dart';
import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';

const _courses = [
  (
    StudyCourse.englishFromRussian,
    CefrLevel.a1,
    'at 5',
    'в пять',
    ['ключ', 'лифт', 'билет'],
  ),
  (
    StudyCourse.spanishFromEnglish,
    CefrLevel.b1,
    '¡sí, tú!',
    'yes, you!',
    ['key', 'lift', 'ticket'],
  ),
  (
    StudyCourse.englishFromSpanish,
    CefrLevel.a1,
    're-do',
    'rehacer',
    ['llave', 'ascensor', 'billete'],
  ),
  (
    StudyCourse.spanishFromRussian,
    CefrLevel.c1,
    'café',
    'кофе',
    ['ключ', 'лифт', 'билет'],
  ),
];

void main() {
  for (final (course, level, source, translation, localAnswers) in _courses) {
    for (final game in wordarcadeGames) {
      testWidgets(
        '${game.id} answers the personal card in ${course.id}/${level.name}',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final target = Word(
            id: 'custom:${course.id}:1',
            text: source,
            translation: translation,
            level: level,
          );
          final wrongLevel = Word(
            id: 'custom:elsewhere',
            text: 'elsewhere',
            translation: 'excluded',
            level: level == CefrLevel.a1 ? CefrLevel.a2 : CefrLevel.a1,
          );
          final support = [
            for (final (index, label) in localAnswers.indexed)
              Word(
                id: 'seed:$index',
                text: 'seed-$index',
                translation: label,
                level: level,
              ),
          ];
          final items = buildCustomReviewItems(
            words: [wrongLevel, target],
            courseItems: [
              for (final word in [...support, wrongLevel])
                ReviewItem(word: word),
            ],
            level: level,
          );
          final tomorrow = LeitnerCard(box: 2, due: DateTime(2031));
          final cards = InMemoryCardStore({
            target.id: tomorrow,
            wrongLevel.id: tomorrow,
          });
          final answers = InMemoryAnswerLog();
          final start = StartSession(
            cards: cards,
            streaks: InMemoryStreakStore(),
            now: () => DateTime(2030),
            target: 15,
            answerLog: answers,
          );
          final regular =
              start(items: items, gameId: game.id, level: level)
                  as Ok<ReviewSession>;
          expect(regular.value.total, 0);
          final practice =
              start(
                    items: items,
                    gameId: game.id,
                    level: level,
                    practiceAll: true,
                  )
                  as Ok<ReviewSession>;
          expect(practice.value.total, 1);
          await tester.pumpWidget(
            MaterialApp(
              theme: wordarcadeTheme(),
              home: game.build(
                GameLaunch(
                  session: practice.value,
                  course: course,
                  level: level,
                  vocabulary: [target, ...support, wrongLevel],
                  summaryFooter: () => '',
                  onExit: () {},
                  onPlayAgain: () {},
                  onRoundOver: () {},
                ),
              ),
            ),
          );
          await tester.pump();
          final answer = find.text(translation);

          switch (game.id) {
            case 'falling_words':
            case 'ninja_slash':
              final ninja = game.id == 'ninja_slash';
              await tester.pump(
                ninja ? NinjaRun.windUpTime : FallingWordsRun.windUpTime,
              );
              await tester.pump(const Duration(milliseconds: 850));
              expect(find.text(source), findsOneWidget);
              expect(find.text(wrongLevel.translation), findsNothing);
              expect(
                localAnswers.where(
                  (text) => find.text(text).evaluate().isNotEmpty,
                ),
                hasLength(ninja ? 2 : 3),
              );
              if (ninja) {
                final center = tester.getCenter(answer);
                final slash = await tester.startGesture(
                  center - const Offset(30, 0),
                );
                await slash.moveTo(center + const Offset(30, 0));
                await slash.up();
              } else {
                await tester.tap(answer);
              }
              await tester.pump();
              await tester.pump(
                ninja ? NinjaRun.correctReveal : FallingWordsRun.correctReveal,
              );
            case 'claw_machine':
              expect(answer, findsOneWidget);
              for (final letter in source.toUpperCase().characters.where(
                (c) => RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(c),
              )) {
                await catchClawLetter(tester, letter);
              }
              expect(find.text(source.toUpperCase()), findsOneWidget);
            case 'brick_breaker':
              await tester.tap(find.byKey(BrickBreakerKeys.launch));
              await _frames(tester, 80);
              expect(find.text(source), findsOneWidget);
              final field = tester.getRect(find.byKey(BrickBreakerKeys.field));
              await tester.dragFrom(
                Offset(field.center.dx, field.bottom - 26),
                Offset(tester.getCenter(answer).dx - field.center.dx, 0),
              );
              await _frames(tester, 260);
            case 'match_three':
              final from = tester.getCenter(find.byKey(MatchThreeKeys.cell(9)));
              await tester.dragFrom(
                from,
                tester.getCenter(find.byKey(MatchThreeKeys.cell(15))) - from,
              );
              await tester.pumpAndSettle();
              expect(find.text(source), findsOneWidget);
              await tester.tap(answer);
            case 'word_mahjong':
              await tester.tap(find.text(source));
              await tester.pumpAndSettle();
              await tester.tap(answer);
            case 'snake':
              final field = tester.widget<SnakeField>(find.byType(SnakeField));
              expect(answer, findsOneWidget);
              expect(
                field.run.apples.map((apple) => apple.word),
                everyElement(isIn([target, ...support])),
              );
              expect(field.run.apples, hasLength(3));
              await _eatOpeningApple(tester, field.run);
            default:
              fail('Missing game exercise for ${game.id}');
          }
          await tester.pump();
          expect(answers.records.single.wordId, target.id);
          expect(answers.records.single.gameId, game.id);
          expect(answers.records.single.correct, isTrue);
          expect(
            cards.saves.single.keys,
            unorderedEquals([wrongLevel.id, target.id]),
          );
          expect(cards.saves.single[wrongLevel.id], tomorrow);
          expect(cards.saves.single[target.id]!.box, greaterThan(1));
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

Future<void> _frames(WidgetTester tester, int count) async {
  for (var index = 0; index < count; index++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _eatOpeningApple(WidgetTester tester, SnakeRun run) async {
  final target =
      run.apples.singleWhere((apple) => apple.word == run.item!.word).cell;
  final route = switch (target) {
    (x: 3, y: 2) => [
      (LogicalKeyboardKey.arrowUp, (x: 5, y: 2)),
      (LogicalKeyboardKey.arrowLeft, target),
    ],
    (x: 8, y: 6) => [(LogicalKeyboardKey.arrowRight, target)],
    (x: 8, y: 9) => [
      (LogicalKeyboardKey.arrowDown, (x: 5, y: 9)),
      (LogicalKeyboardKey.arrowRight, target),
    ],
    _ => throw StateError('Unexpected opening apple: $target'),
  };
  for (final (direction, stop) in route) {
    await tester.sendKeyEvent(direction);
    await tester.pump();
    for (var i = 0; i < 4 && run.body.first != stop; i++) {
      await tester.pump(SnakeRun.stepTime);
    }
    expect(run.body.first, stop);
  }
}
