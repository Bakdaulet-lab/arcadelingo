import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/story_game.dart';
import 'package:arcadelingo/domain/events/app_event.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/word_mahjong/word_mahjong_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_answer_log.dart';
import '../support/in_memory_event_log.dart';
import '../support/in_memory_stores.dart';

const _milk = ReviewItem(
  word: Word(id: 'milk', text: 'milk', translation: 'молоко'),
  distractors: ['сок', 'чай', 'вода'],
);
const _bread = ReviewItem(
  word: Word(id: 'bread', text: 'bread', translation: 'хлеб'),
  distractors: ['масло', 'сыр', 'рис'],
);
const _elsewhere = ReviewItem(
  word: Word(
    id: 'b1',
    text: 'pastry',
    translation: 'выпечка',
    level: CefrLevel.b1,
  ),
);

class _Fixture {
  final events = InMemoryEventLog();
  final answers = InMemoryAnswerLog();
  final streaks = InMemoryStreakStore();
  final cards = InMemoryCardStore({
    'milk': LeitnerCard(box: 2, due: DateTime.utc(2038)),
    'bread': LeitnerCard(box: 2, due: DateTime.utc(2038)),
  });
  bool? result;

  Future<void> start(
    WidgetTester tester,
    int stage,
    List<ReviewItem> items,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: wordarcadeTheme(),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await playStoryStage(
                      context,
                      ports: AppPorts(
                        cards: cards,
                        streaks: streaks,
                        answers: answers,
                        events: events,
                      ),
                      course: StudyCourse.englishFromRussian,
                      level: CefrLevel.a1,
                      stage: stage,
                      items: items,
                      now: () => DateTime.utc(2037),
                    );
                  },
                  child: const Text('Launch'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Launch'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }
}

void main() {
  testWidgets(
    'complete a Mahjong stage with the selected pairs and return to the story',
    (tester) async {
      final fixture = _Fixture();
      await fixture.start(tester, 0, [_milk, _elsewhere, _bread]);
      expect(find.byType(WordMahjongGame), findsOneWidget);
      expect(find.text(_elsewhere.word.text), findsNothing);
      for (final item in [_milk, _bread]) {
        await tester.tap(find.text(item.word.text));
        await tester.pumpAndSettle();
        await tester.tap(find.text(item.word.translation));
        await tester.pumpAndSettle();
      }
      expect(find.text('Launch'), findsOneWidget);
      expect(fixture.result, isTrue);
      expect(fixture.answers.records.map((a) => a.wordId), ['milk', 'bread']);
      expect(
        fixture.answers.records.map((a) => a.gameId),
        everyElement('word_mahjong'),
      );
      expect(fixture.cards.saves.last['milk']!.box, greaterThan(2));
      expect(fixture.cards.saves.last, isNot(contains('b1')));
      expect(fixture.events.kinds, [
        AppEventKind.roundStart,
        AppEventKind.roundOver,
      ]);
      expect(
        fixture.events.events.first.sessionId,
        fixture.answers.records.first.sessionId,
      );
      expect(fixture.streaks.saves, hasLength(1));
    },
  );

  testWidgets(
    'finish Falling Words before the app advances to the final task',
    (tester) async {
      final fixture = _Fixture();
      await fixture.start(tester, 1, [_milk, _elsewhere, _bread]);
      expect(find.byType(FallingWordsGame), findsOneWidget);
      await tester.pump(FallingWordsRun.windUpTime);
      for (final item in [_milk, _bread]) {
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(item.word.text), findsOneWidget);
        await tester.tap(find.text(item.word.translation));
        await tester.pump();
        await tester.pump(FallingWordsRun.correctReveal);
      }
      await tester.pumpAndSettle();
      expect(fixture.result, isTrue);
      expect(find.text('Launch'), findsOneWidget);
      expect(fixture.answers.records.map((a) => a.wordId), ['milk', 'bread']);
      expect(
        fixture.answers.records.map((a) => a.correct),
        everyElement(isTrue),
      );
      expect(
        fixture.answers.records.map((a) => a.gameId),
        everyElement('falling_words'),
      );
      expect(fixture.events.kinds, [
        AppEventKind.roundStart,
        AppEventKind.roundOver,
      ]);
      expect(fixture.streaks.saves, hasLength(1));
    },
  );

  for (final stage in [0, 1]) {
    testWidgets('back during stage $stage leaves the story unfinished', (
      tester,
    ) async {
      final fixture = _Fixture();
      await fixture.start(tester, stage, [_bread, _milk]);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(fixture.result, isFalse);
      expect(fixture.events.kinds, [
        AppEventKind.roundStart,
        AppEventKind.roundAbandon,
      ]);
      expect(fixture.streaks.saves, isEmpty);
    });
  }

  testWidgets('an unavailable level never opens or credits a stage', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.start(tester, 0, [_elsewhere]);
    expect(find.text('Launch'), findsOneWidget);
    expect(fixture.result, isFalse);
    expect(fixture.events.kinds, isEmpty);
    expect(fixture.answers.records, isEmpty);
    expect(fixture.streaks.saves, isEmpty);
  });
}
