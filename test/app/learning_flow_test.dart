import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/app/learning_views.dart';
import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/events/app_event.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_field.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_game.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_run.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_views.dart'
    as falling;
import 'package:arcadelingo/features/games/match_three/match_three_game.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_views.dart'
    as ninja;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/claw_actions.dart';
import '../support/in_memory_answer_log.dart';
import '../support/in_memory_event_log.dart';
import '../support/in_memory_stores.dart';

final _today = DateTime(2026, 11, 17, 12);
const _learn = Key('app.learn');
const _review = Key('game.review_mistakes');

class _Speech implements WordSpeech {
  final spoken = <String>[];
  var stops = 0;
  @override
  Future<SpeechResult> speak(String text) async {
    spoken.add(text);
    return SpeechResult.completed;
  }

  @override
  Future<void> stop() async => stops++;
}

class _Fixture {
  _Fixture(this.items, {Map<String, LeitnerCard>? initial})
    : cards = InMemoryCardStore(initial);
  final List<ReviewItem> items;
  final InMemoryCardStore cards;
  final streaks = InMemoryStreakStore();
  final answers = InMemoryAnswerLog();
  final events = InMemoryEventLog();
  final speech = _Speech();

  Widget get app => WordarcadeApp(
    ports: AppPorts(
      cards: cards,
      streaks: streaks,
      answers: answers,
      events: events,
      speech: speech,
    ),
    seed: Ok(items),
    now: () => _today,
  );
}

Future<void> _pump(WidgetTester tester, _Fixture fixture) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(fixture.app);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _beginGame(
  WidgetTester tester,
  GameEntry entry,
  Key action,
) async {
  await tester.ensureVisible(find.byKey(action));
  await tester.tap(find.byKey(action));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  if (entry.id == brickBreakerEntry.id) {
    await _openBrickBonus(tester);
  } else if (entry.id == matchThreeEntry.id) {
    await _tap(tester, find.byKey(MatchThreeKeys.cell(9)));
    await _tap(tester, find.byKey(MatchThreeKeys.cell(15)));
  } else {
    await tester.pump(
      entry.id == ninjaSlashEntry.id
          ? NinjaRun.windUpTime
          : FallingWordsRun.windUpTime,
    );
  }
}

Future<void> _openBrickBonus(WidgetTester tester) async {
  final field = find.byKey(BrickBreakerKeys.field);
  final run = tester.widget<BrickBreakerField>(field).run;
  final board = tester.getRect(field);
  final gold = run.bricks.singleWhere((brick) => brick.gold);
  await tester.tapAt(
    Offset(
      board.left + gold.bounds.center.dx * board.width / BrickBreakerRun.width,
      board.top + 12,
    ),
  );
  await tester.tap(find.byKey(BrickBreakerKeys.launch));
  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(find.byKey(BrickBreakerKeys.word), findsOneWidget);
}

Future<void> _answerBrick(WidgetTester tester, String translation) async {
  final card = find.text(translation);
  await tester.ensureVisible(card);
  await tester.tap(card);
  await tester.pumpAndSettle(const Duration(milliseconds: 20));
}

Future<void> _answer(
  WidgetTester tester,
  bool isNinja,
  String translation,
) async {
  await tester.pump(const Duration(seconds: 1));
  final answer = find.text(translation);
  expect(answer, findsOneWidget);
  if (isNinja) {
    final center = tester.getCenter(answer);
    final gesture = await tester.startGesture(center - const Offset(20, 0));
    await gesture.moveTo(center + const Offset(20, 0));
    await gesture.up();
  } else {
    await tester.tap(answer);
  }
  await tester.pump();
}

void main() {
  late List<ReviewItem> bundled;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final seed = await loadWordsSeed();
    bundled = (seed as Ok<List<ReviewItem>>).value;
  });

  // The board and movement games have dedicated launch tests.
  for (final entry in wordarcadeGames.where(
    (game) => !const {'word_mahjong', 'snake', 'word_maze'}.contains(game.id),
  )) {
    final isMatch = entry.id == matchThreeEntry.id;
    final isBrick = entry.id == brickBreakerEntry.id;
    final isClaw = entry.id == clawMachineEntry.id;
    final isNinja = entry.id == ninjaSlashEntry.id;
    final wordKey =
        isMatch
            ? MatchThreeKeys.word
            : isBrick
            ? BrickBreakerKeys.word
            : isClaw
            ? ClawKeys.prompt
            : isNinja
            ? ninja.NinjaKeys.word
            : falling.FallingWordsKeys.word;
    final summaryKey =
        isMatch
            ? MatchThreeKeys.summary
            : isBrick
            ? BrickBreakerKeys.summary
            : isClaw
            ? ClawKeys.summary
            : isNinja
            ? ninja.NinjaKeys.summary
            : falling.FallingWordsKeys.summary;

    for (final level in CefrLevel.values) {
      testWidgets(
        '${entry.id}/${level.name}: знакомство, речь, ошибки одного уровня',
        (tester) async {
          final subset = [
            for (final cefr in CefrLevel.values)
              ...bundled
                  .where((item) => item.word.level == cefr)
                  .take(
                    isMatch
                        ? 1
                        : isClaw || isBrick
                        ? 3
                        : 7,
                  ),
          ];
          final selected =
              subset.where((item) => item.word.level == level).toList();
          // Просроченные карточки других уровней не должны попасть ни в один шаг.
          final fixture = _Fixture(
            subset,
            initial: {
              for (final item in subset.where(
                (item) => item.word.level != level,
              ))
                item.word.id: LeitnerCard(box: 2, due: _today),
            },
          );
          await _pump(tester, fixture);
          await _tap(tester, find.text(level.name.toUpperCase()));
          await _tap(tester, find.text(entry.title));
          await _tap(tester, find.byKey(_learn));
          expect(find.byKey(LearningKeys.introduction), findsOneWidget);
          final introduction = tester.widget<WordIntroductionScreen>(
            find.byType(WordIntroductionScreen),
          );
          expect(
            introduction.words.map((word) => word.id),
            selected.take(5).map((item) => item.word.id),
          );
          expect(
            introduction.words.every((word) => word.level == level),
            isTrue,
          );
          expect(fixture.cards.saves, isEmpty);
          expect(fixture.answers.records, isEmpty);
          expect(
            fixture.events.kinds,
            isNot(contains(AppEventKind.roundStart)),
          );
          for (var index = 0; index < introduction.words.length; index++) {
            expect(find.text(introduction.words[index].text), findsOneWidget);
            await _tap(tester, find.byKey(LearningKeys.speak));
            expect(fixture.speech.spoken.last, introduction.words[index].text);
            if (index + 1 < introduction.words.length) {
              await _tap(tester, find.byKey(LearningKeys.next));
            }
          }
          await _beginGame(tester, entry, LearningKeys.start);
          expect(find.byKey(LearningKeys.introduction), findsNothing);
          // В играх с жизнями делаем три промаха. Автомат доходит
          // до итогов по исчерпании короткой очереди из трёх слов.
          final choices = <String>[];
          final answered = isMatch ? 1 : 3;
          for (var index = 0; index < answered; index++) {
            final word = selected[index].word;
            expect(
              tester.widget<Text>(find.byKey(wordKey)).data,
              isClaw ? word.translation : word.text,
            );
            if (isClaw) {
              choices.add(await missWithClaw(tester, word.text[0]));
              await spellWithClaw(tester, word.text);
              expect(fixture.answers.records.last.correct, isFalse);
              await tapClaw(tester, ClawKeys.next);
              continue;
            }
            if (isBrick) {
              expect(fixture.speech.spoken.last, word.text);
              final wrong = selected[index].distractors.firstWhere(
                (label) => find.text(label).evaluate().isNotEmpty,
              );
              choices.add(wrong);
              await _answerBrick(tester, wrong);
              expect(fixture.answers.records.last.correct, isFalse);
              if (index < 2) await _openBrickBonus(tester);
              continue;
            }
            if (isMatch) {
              expect(fixture.speech.spoken.last, word.text);
              final wrong = selected[index].distractors.firstWhere(
                (label) => find.text(label).evaluate().isNotEmpty,
              );
              choices.add(wrong);
              await _tap(tester, find.text(wrong));
              expect(fixture.answers.records.last.correct, isFalse);
              continue;
            }
            final wrongLabels =
                isNinja
                    ? tester
                        .widgetList<ninja.FlyingObject>(
                          find.byType(ninja.FlyingObject),
                        )
                        .map((object) => object.label)
                    : tester
                        .widgetList<falling.AnswerButton>(
                          find.byType(falling.AnswerButton),
                        )
                        .map((button) => button.label);
            final wrong = wrongLabels.firstWhere(
              (label) => label != selected[index].word.translation,
            );
            choices.add(wrong);
            await _answer(tester, isNinja, wrong);
            expect(fixture.answers.records.last.correct, isFalse);
            await tester.pump(const Duration(milliseconds: 800));
          }
          expect(find.byKey(summaryKey), findsOneWidget);
          expect(fixture.answers.records, hasLength(answered));
          expect(
            fixture.answers.records.every(
              (record) => record.gameId == entry.id,
            ),
            isTrue,
          );
          expect(
            fixture.answers.records.map((record) => record.wordId),
            selected.take(answered).map((item) => item.word.id),
          );
          final savesBefore = fixture.cards.saves.length;
          final eventsBefore = fixture.events.events.length;
          await _tap(tester, find.byKey(_review));
          final review = tester.widget<MistakesReviewScreen>(
            find.byType(MistakesReviewScreen),
          );
          expect(
            review.words.map((word) => word.id),
            selected.take(answered).map((item) => item.word.id),
          );
          expect(review.words.every((word) => word.level == level), isTrue);
          for (var index = 0; index < review.words.length; index++) {
            expect(find.text(review.words[index].translation), findsOneWidget);
            expect(find.text('Правильный перевод'), findsOneWidget);
            expect(find.text('Твой ответ'), findsOneWidget);
            expect(find.text(choices[index]), findsOneWidget);
            await _tap(tester, find.byKey(LearningKeys.speak));
            expect(fixture.speech.spoken.last, review.words[index].text);
            if (index + 1 < review.words.length) {
              await _tap(tester, find.byKey(LearningKeys.next));
            }
          }
          await _tap(tester, find.byKey(LearningKeys.done));
          expect(find.byKey(summaryKey), findsOneWidget);
          expect(fixture.cards.saves, hasLength(savesBefore));
          expect(fixture.answers.records, hasLength(answered));
          expect(fixture.events.events, hasLength(eventsBefore));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }

    testWidgets('${entry.id}: знакомство можно отменить без записи прогресса', (
      tester,
    ) async {
      final fixture = _Fixture(
        bundled
            .where((item) => item.word.level == CefrLevel.b2)
            .take(8)
            .toList(),
      );
      await _pump(tester, fixture);
      await _tap(tester, find.text(entry.title));
      await _tap(tester, find.byKey(_learn));
      await _tap(tester, find.byKey(LearningKeys.speak));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.play), findsOneWidget);
      expect(fixture.cards.saves, isEmpty);
      expect(fixture.answers.records, isEmpty);
      expect(fixture.streaks.saves, isEmpty);
      expect(fixture.events.kinds, isNot(contains(AppEventKind.roundStart)));
      expect(fixture.events.kinds, isNot(contains(AppEventKind.roundAbandon)));
      expect(fixture.speech.stops, greaterThan(0));
    });

    testWidgets('${entry.id}: повторение без новых слов сразу запускает игру', (
      tester,
    ) async {
      final item = bundled.firstWhere(
        (item) => item.word.level == CefrLevel.c1,
      );
      final fixture = _Fixture(
        [item],
        initial: {item.word.id: LeitnerCard(box: 2, due: _today)},
      );
      await _pump(tester, fixture);
      await _tap(tester, find.text(entry.title));
      await _beginGame(tester, entry, _learn);
      expect(find.byKey(LearningKeys.introduction), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(wordKey)).data,
        isClaw ? item.word.translation : item.word.text,
      );
      if (isClaw) {
        await spellWithClaw(tester, item.word.text);
        await tapClaw(tester, ClawKeys.next);
      } else if (isBrick) {
        await _answerBrick(tester, item.word.translation);
      } else if (isMatch) {
        await _tap(tester, find.text(item.word.translation));
      } else {
        await _answer(tester, isNinja, item.word.translation);
        await tester.pump(
          isNinja ? NinjaRun.correctReveal : FallingWordsRun.correctReveal,
        );
      }
      expect(find.byKey(summaryKey), findsOneWidget);
      expect(find.byKey(_review), findsNothing);
      expect(fixture.answers.records.single.correct, isTrue);
    });

    testWidgets('${entry.id}: обычная партия тоже даёт разбор ошибок', (
      tester,
    ) async {
      final item = bundled.firstWhere(
        (item) => item.word.level == CefrLevel.a2,
      );
      final fixture = _Fixture([item]);
      await _pump(tester, fixture);
      await _tap(tester, find.text(entry.title));
      await _beginGame(tester, entry, AppKeys.play);
      expect(find.byKey(LearningKeys.introduction), findsNothing);
      final String feedback;
      if (isClaw) {
        feedback = await missWithClaw(tester, item.word.text[0]);
        await spellWithClaw(tester, item.word.text);
        await tapClaw(tester, ClawKeys.next);
      } else if (isBrick) {
        feedback = item.distractors.firstWhere(
          (label) => find.text(label).evaluate().isNotEmpty,
        );
        await _answerBrick(tester, feedback);
      } else if (isMatch) {
        feedback = item.distractors.firstWhere(
          (label) => find.text(label).evaluate().isNotEmpty,
        );
        await _tap(tester, find.text(feedback));
      } else {
        await tester.pump(const Duration(seconds: 8));
        await tester.pump(const Duration(milliseconds: 800));
        feedback = 'Время вышло';
      }
      expect(find.byKey(summaryKey), findsOneWidget);
      await _tap(tester, find.byKey(_review));
      expect(find.text(feedback), findsOneWidget);
      expect(
        tester
            .widget<MistakesReviewScreen>(find.byType(MistakesReviewScreen))
            .words
            .single
            .id,
        item.word.id,
      );
    });
  }
}
