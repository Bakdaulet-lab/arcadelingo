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
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_views.dart'
    as falling;
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_views.dart'
    as ninja;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

Future<void> _beginGame(WidgetTester tester, bool isNinja, Key action) async {
  await tester.ensureVisible(find.byKey(action));
  await tester.tap(find.byKey(action));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(isNinja ? NinjaRun.windUpTime : FallingWordsRun.windUpTime);
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

  for (final entry in wordarcadeGames) {
    final isNinja = entry.id == ninjaSlashEntry.id;
    final wordKey =
        isNinja ? ninja.NinjaKeys.word : falling.FallingWordsKeys.word;
    final summaryKey =
        isNinja ? ninja.NinjaKeys.summary : falling.FallingWordsKeys.summary;

    for (final level in CefrLevel.values) {
      testWidgets(
        '${entry.id}/${level.name}: знакомство, речь, ошибки одного уровня',
        (tester) async {
          final subset = [
            for (final cefr in CefrLevel.values)
              ...bundled.where((item) => item.word.level == cefr).take(7),
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
          await _beginGame(tester, isNinja, LearningKeys.start);
          expect(find.byKey(LearningKeys.introduction), findsNothing);
          // Реальные тапы/свайпы по неверным ответам завершают обе игры тремя потерями.
          for (var index = 0; index < 3; index++) {
            expect(
              tester.widget<Text>(find.byKey(wordKey)).data,
              selected[index].word.text,
            );
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
            await _answer(tester, isNinja, wrong);
            expect(fixture.answers.records.last.correct, isFalse);
            await tester.pump(const Duration(milliseconds: 800));
          }
          expect(find.byKey(summaryKey), findsOneWidget);
          expect(fixture.answers.records, hasLength(3));
          expect(
            fixture.answers.records.every(
              (record) => record.gameId == entry.id,
            ),
            isTrue,
          );
          expect(
            fixture.answers.records.map((record) => record.wordId),
            selected.take(3).map((item) => item.word.id),
          );
          final savesBefore = fixture.cards.saves.length;
          final eventsBefore = fixture.events.events.length;
          await _tap(tester, find.byKey(_review));
          final review = tester.widget<MistakesReviewScreen>(
            find.byType(MistakesReviewScreen),
          );
          expect(
            review.words.map((word) => word.id),
            selected.take(3).map((item) => item.word.id),
          );
          expect(review.words.every((word) => word.level == level), isTrue);
          for (var index = 0; index < review.words.length; index++) {
            expect(find.text(review.words[index].translation), findsOneWidget);
            await _tap(tester, find.byKey(LearningKeys.speak));
            expect(fixture.speech.spoken.last, review.words[index].text);
            if (index + 1 < review.words.length) {
              await _tap(tester, find.byKey(LearningKeys.next));
            }
          }
          await _tap(tester, find.byKey(LearningKeys.done));
          expect(find.byKey(summaryKey), findsOneWidget);
          expect(fixture.cards.saves, hasLength(savesBefore));
          expect(fixture.answers.records, hasLength(3));
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
      await tester.pageBack();
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
      await _beginGame(tester, isNinja, _learn);
      expect(find.byKey(LearningKeys.introduction), findsNothing);
      expect(tester.widget<Text>(find.byKey(wordKey)).data, item.word.text);
      await _answer(tester, isNinja, item.word.translation);
      await tester.pump(
        isNinja ? NinjaRun.correctReveal : FallingWordsRun.correctReveal,
      );
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
      await _beginGame(tester, isNinja, AppKeys.play);
      expect(find.byKey(LearningKeys.introduction), findsNothing);
      await tester.pump(const Duration(seconds: 8));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byKey(summaryKey), findsOneWidget);
      await _tap(tester, find.byKey(_review));
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
