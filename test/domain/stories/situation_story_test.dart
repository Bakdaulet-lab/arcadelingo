import 'dart:math';

import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/stories/situation_story.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (course, loader, levelCount) in [
    (StudyCourse.englishFromRussian, loadWordsSeed, 6),
    (StudyCourse.englishFromSpanish, loadEnglishA1FromSpanishSeed, 1),
    (StudyCourse.spanishFromRussian, loadSpanishSeed, 5),
    (StudyCourse.spanishFromEnglish, loadSpanishFromEnglishSeed, 5),
  ]) {
    test(
      'three complete offline stories per released level of ${course.id}',
      () async {
        final result = await loader() as Ok<List<ReviewItem>>;
        final levels = result.value.map((item) => item.word.level).toSet();
        expect(levels, hasLength(levelCount));
        for (final level in levels) {
          final stories = buildSituationStories(
            course: course,
            level: level,
            courseItems: result.value,
            random: Random(1),
          );
          expect(
            stories.map((story) => story.situation),
            StorySituation.values,
            reason: level.name,
          );
          for (final story in stories) {
            expect(story.firstRound, hasLength(2));
            expect(story.secondRound, hasLength(2));
            final cards = [...story.firstRound, ...story.secondRound];
            expect(cards.toSet(), hasLength(4));
            for (final card in cards) {
              expect(card.word.level, level);
              expect(result.value.contains(card), isTrue);
            }
            expect(story.clue, isNotEmpty);
            expect(story.question, isNotEmpty);
            expect(story.explanation, isNotEmpty);
            expect(story.choices.toSet(), hasLength(3));
            expect(story.choices[story.correctIndex], isNotEmpty);
          }
        }
      },
    );
  }

  test(
    'an incomplete story cannot borrow a missing word from the next level',
    () {
      final deck = [
        for (final text in ['bread', 'milk', 'coffee'])
          ReviewItem(word: Word(id: text, text: text, translation: text)),
        const ReviewItem(
          word: Word(
            id: 'later',
            text: 'butter',
            translation: 'масло',
            level: CefrLevel.a2,
          ),
        ),
      ];
      expect(
        buildSituationStories(
          course: StudyCourse.englishFromRussian,
          level: CefrLevel.a1,
          courseItems: deck,
          random: Random(1),
        ),
        isEmpty,
      );
    },
  );

  test(
    'the breakfast answer follows its text when choices are shuffled',
    () async {
      final items = (await loadSpanishSeed() as Ok<List<ReviewItem>>).value;
      final positions = <int>{};
      for (var seed = 0; seed < 15; seed++) {
        final story =
            buildSituationStories(
              course: StudyCourse.spanishFromRussian,
              level: CefrLevel.a1,
              courseItems: items,
              random: Random(seed),
            ).first;
        expect(story.situation, StorySituation.breakfast);
        expect(story.clue, contains('leche'));
        expect(story.choices[story.correctIndex], 'С молоком');
        positions.add(story.correctIndex);
      }
      expect(positions, hasLength(3));
    },
  );
}
