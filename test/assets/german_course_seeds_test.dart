import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/daily_word/daily_word.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/review/word_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'four offline German courses share 500 spellings, articles and levels',
    () async {
      expect(StudyCourse.germanCourses.map((course) => course.id), [
        'ru-de',
        'en-de',
        'es-de',
        'kk-de',
      ]);
      Map<String, (String, String?, String?, CefrLevel)>? reference;
      for (final course in StudyCourse.germanCourses) {
        final result = await loadGermanSeed(course);
        expect(result, isA<Ok<List<ReviewItem>>>(), reason: course.id);
        final catalogue = (result as Ok<List<ReviewItem>>).value;
        expect(catalogue, hasLength(500));
        final headwords = <String>{};
        final lexical = <String, (String, String?, String?, CefrLevel)>{};
        for (final item in catalogue) {
          final word = item.word;
          expect(word.id, startsWith('de_'));
          expect(
            headwords.add(normalizedCourseSpelling(word.text)),
            isTrue,
            reason: word.id,
          );
          if (word.partOfSpeech == 'noun') {
            expect(word.article, isIn(['der', 'die', 'das']), reason: word.id);
            expect(word.text, matches(RegExp(r'^[A-ZÄÖÜ]')), reason: word.id);
            expect(word.headword, '${word.article} ${word.text}');
          } else {
            expect(word.article, isNull, reason: word.id);
            expect(word.headword, word.text);
          }
          lexical[word.id] = (
            word.text,
            word.article,
            word.partOfSpeech,
            word.level,
          );
        }
        expect(lexical, hasLength(500));
        expect(lexical, reference ?? lexical, reason: course.id);
        reference = lexical;
        expect(
          catalogue.any((item) => item.word.level == CefrLevel.c2),
          isFalse,
        );
        for (final level in CefrLevel.values.take(5)) {
          final items =
              catalogue.where((item) => item.word.level == level).toList();
          expect(items, hasLength(100), reason: '${course.id}/${level.name}');
          final byMeaning = {
            for (final item in items)
              item.word.translation: item.word.partOfSpeech,
          };
          expect(byMeaning, hasLength(items.length));
          for (final item in items) {
            expect(item.distractors, hasLength(3), reason: item.word.id);
            expect(
              item.distractors.toSet(),
              hasLength(3),
              reason: item.word.id,
            );
            for (final distractor in item.distractors) {
              expect(
                byMeaning[distractor],
                item.word.partOfSpeech,
                reason: item.word.id,
              );
              expect(
                translationMeanings(
                  distractor,
                ).intersection(translationMeanings(item.word.translation)),
                isEmpty,
                reason: item.word.id,
              );
            }
          }
          final puzzle = selectDailyWord(
            course: course,
            level: level,
            date: DateTime(2026, 12, 4),
            vocabulary: catalogue.map((item) => item.word),
          );
          expect(
            puzzle?.answer.level,
            level,
            reason: '${course.id}/${level.name}',
          );
          expect(DailyWordRound(puzzle!).submit(puzzle.answer.text), isNull);
        }
      }
    },
  );
}
