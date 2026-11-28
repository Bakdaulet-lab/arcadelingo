import 'dart:convert';

import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/daily_word/daily_word.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/review/word_labels.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all three courses have five playable, distinct offline levels',
    () async {
      expect(StudyCourse.kazakhCourses.map((c) => c.id), [
        'kk-ru',
        'kk-en',
        'kk-es',
      ]);
      final ids = <String>{};
      final kazakh = RegExp(
        r'^[а-яёәғқңөұүһі\s\-,.()!?]+$',
        caseSensitive: false,
      );
      for (final course in StudyCourse.kazakhCourses) {
        final loaded = await loadKazakhSeed(course);
        expect(loaded, isA<Ok<List<ReviewItem>>>(), reason: course.id);
        final items = (loaded as Ok<List<ReviewItem>>).value;
        expect(items.any((item) => item.word.level == CefrLevel.c2), isFalse);
        final spellings = <String>{};
        for (final level in CefrLevel.values.take(5)) {
          final prefix = '${course.id}/${level.name}';
          final source = await rootBundle.loadString(
            'assets/words_kk_${course.studyLanguage}/${level.name}.json',
          );
          final metadata = jsonDecode(source) as Map<String, dynamic>;
          expect(metadata['source_lang'], course.studyLanguage);
          expect(metadata['target_lang'], 'kk');
          final batch =
              items.where((item) => item.word.level == level).toList();
          expect(batch.length, greaterThanOrEqualTo(80), reason: prefix);
          final glossary = batch.map((item) => item.word.translation).toSet();
          expect(glossary, hasLength(batch.length), reason: prefix);
          for (final item in batch) {
            final word = item.word;
            expect(word.id, startsWith('kk_${course.studyLanguage}_'));
            expect(ids.add(word.id), isTrue, reason: word.id);
            expect(
              spellings.add(normalizedCourseSpelling(word.text)),
              isTrue,
              reason: word.id,
            );
            expect(word.partOfSpeech, isNotEmpty, reason: word.id);
            expect(word.translation, matches(kazakh), reason: word.id);
            expect(item.distractors, hasLength(3), reason: word.id);
            expect(item.distractors.toSet(), hasLength(3), reason: word.id);
            final accepted = translationMeanings(word.translation);
            for (final option in item.distractors) {
              expect(glossary, contains(option), reason: word.id);
              expect(
                translationMeanings(option).intersection(accepted),
                isEmpty,
                reason: word.id,
              );
            }
          }
          final puzzle = selectDailyWord(
            course: course,
            level: level,
            date: DateTime(2026, 12, 1),
            vocabulary: items.map((item) => item.word),
          );
          expect(puzzle?.answer.level, level, reason: prefix);
          expect(DailyWordRound(puzzle!).submit(puzzle.answer.text), isNull);
        }
      }
    },
  );
}
