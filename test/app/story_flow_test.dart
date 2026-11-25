import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/app/story_views.dart';
import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/stories/situation_story.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_views.dart';
import 'package:arcadelingo/features/games/word_mahjong/word_mahjong_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<ReviewItem> spanish;
  setUpAll(() async {
    spanish =
        (await loadSpanishFromEnglishSeed() as Ok<List<ReviewItem>>).value;
  });
  testWidgets(
    'switch course and level, finish two station games and act on the Spanish clue',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      const course = StudyCourse.spanishFromEnglish;
      final baseLog = InMemoryAnswerLog();
      final storyLog = InMemoryAnswerLog();
      await tester.pumpWidget(
        WordarcadeApp(
          ports: AppPorts(
            cards: InMemoryCardStore(),
            streaks: InMemoryStreakStore(),
            answers: baseLog,
          ),
          seed: const Ok([
            ReviewItem(
              word: Word(id: 'chair', text: 'chair', translation: 'стул'),
            ),
          ]),
          additionalDecks: [
            CourseDeck(
              course: course,
              items: spanish,
              cards: InMemoryCardStore(),
              answers: storyLog,
              streaks: InMemoryStreakStore(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(AppKeys.course));
      await _tap(tester, find.byKey(ValueKey('course.${course.id}')));
      await _tap(tester, find.text('B1'));
      await _tap(tester, find.byKey(AppKeys.stories));
      final picker = tester.widget<SituationStoriesScreen>(
        find.byType(SituationStoriesScreen),
      );
      expect(picker.course, course);
      expect(picker.level, CefrLevel.b1);
      expect(
        picker.stories.map((story) => story.situation),
        unorderedEquals(StorySituation.values),
      );
      final story = picker.stories.singleWhere(
        (story) => story.situation == StorySituation.station,
      );
      final targets = [...story.firstRound, ...story.secondRound];
      expect(
        targets.map((item) => item.word.level),
        everyElement(CefrLevel.b1),
      );
      expect(
        targets.map((item) => item.word.id),
        everyElement(isIn(spanish.map((item) => item.word.id))),
      );
      await _tap(tester, find.byKey(const ValueKey('story.station')));
      await _tap(tester, find.byKey(const Key('story.play')));
      for (var i = 0; i < story.firstRound.length; i++) {
        final board =
            tester
                .widget<WordMahjongField>(find.byType(WordMahjongField))
                .board;
        final pair = board.hint!;
        await _tap(tester, find.byKey(WordMahjongKeys.tile(pair.word.index)));
        await _tap(
          tester,
          find.byKey(WordMahjongKeys.tile(pair.translation.index)),
        );
      }
      final next = find.byKey(const Key('story.play'));
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pump();
      for (var i = 0; i < story.secondRound.length; i++) {
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pump(const Duration(milliseconds: 300));
        final text =
            tester.widget<Text>(find.byKey(FallingWordsKeys.word)).data;
        final word =
            story.secondRound
                .singleWhere((item) => item.word.text == text)
                .word;
        await tester.tap(find.text(word.translation));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pumpAndSettle();
      expect(find.text(story.clue), findsOneWidget);
      await _tap(
        tester,
        find.byKey(ValueKey('story.answer.${story.correctIndex}')),
      );
      expect(find.byKey(const Key('story.complete')), findsOneWidget);
      expect(
        storyLog.records.map((answer) => answer.wordId),
        unorderedEquals(targets.map((item) => item.word.id)),
      );
      expect(baseLog.records, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
