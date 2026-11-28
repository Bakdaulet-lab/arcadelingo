import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/candy_delivery/candy_orders.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/daily_word/daily_word.dart';
import 'package:arcadelingo/domain/kitchen/kitchen_shift.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/review/word_labels.dart';
import 'package:flutter_test/flutter_test.dart';

const _levels = [
  CefrLevel.a1,
  CefrLevel.a2,
  CefrLevel.b1,
  CefrLevel.b2,
  CefrLevel.c1,
];
const _wordsPerLevel = 500;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('24 offline courses each include 500 words per level', () async {
    final courses = StudyCourse.multilingualCourses;
    expect(
      courses.map((course) => course.id),
      unorderedEquals([
        for (final study in ['fr', 'zh', 'ar', 'ko', 'ja', 'tr'])
          for (final bridge in ['ru', 'en', 'es', 'kk']) '$bridge-$study',
      ]),
    );
    final references = <String, Map<String, Object>>{};
    for (final course in courses) {
      final result = await loadMultilingualSeed(course);
      expect(result, isA<Ok<List<ReviewItem>>>(), reason: course.id);
      final catalogue = (result as Ok<List<ReviewItem>>).value;
      final words = catalogue.map((item) => item.word).toList();
      final catalogueSize = _levels.length * _wordsPerLevel;
      expect(words, hasLength(catalogueSize));
      expect(words.map((word) => word.id).toSet(), hasLength(catalogueSize));
      expect(
        words.map((word) => normalizedCourseSpelling(word.text)).toSet(),
        hasLength(catalogueSize),
      );
      final lexical = <String, Object>{
        for (final word in words)
          word.id: (
            word.text,
            word.article,
            word.reading,
            word.partOfSpeech,
            word.level,
          ),
      };
      expect(
        lexical,
        references.putIfAbsent(course.studyLanguage, () => lexical),
        reason: course.id,
      );
      for (final level in _levels) {
        final items = catalogue.where((item) => item.word.level == level);
        expect(
          items,
          hasLength(_wordsPerLevel),
          reason: '${course.id}/${level.name}',
        );
        final translations = {
          for (final item in items)
            item.word.translation: item.word.partOfSpeech,
        };
        expect(translations, hasLength(_wordsPerLevel));
        for (final item in items) {
          final word = item.word;
          expect(word.id, startsWith('${course.studyLanguage}_'));
          expect(word.translation, isNotEmpty, reason: word.id);
          expect(item.distractors.toSet(), hasLength(3), reason: word.id);
          for (final distractor in item.distractors) {
            expect(translations[distractor], word.partOfSpeech);
            expect(
              translationMeanings(
                distractor,
              ).intersection(translationMeanings(word.translation)),
              isEmpty,
              reason: word.id,
            );
          }
          if (course.studyLanguage == 'fr' && word.partOfSpeech == 'noun') {
            expect(word.article, isIn(['le', 'la', 'l’', 'les']));
          }
          if (course.studyLanguage == 'zh') {
            expect(word.text, matches(RegExp(r'[\u3400-\u9fff]')));
            expect(word.reading, isNotEmpty);
          } else if (course.studyLanguage == 'ja') {
            expect(word.text, matches(RegExp(r'[\u3041-\u30fa\u3400-\u9fff]')));
            expect(word.reading, matches(RegExp(r'^[ぁ-ゖァ-ヺーゝゞヽヾ]+$')));
            expect(word.article, isNull);
          } else {
            expect(word.reading, isNull);
          }
          if (course.studyLanguage == 'ko') {
            expect(word.text, matches(RegExp(r'[\uac00-\ud7a3]')));
            expect(word.article, isNull);
          }
        }
        final daily = selectDailyWord(
          course: course,
          level: level,
          date: DateTime(2026, 11, 28),
          vocabulary: words,
        );
        expect(daily?.answer.level, level, reason: course.id);
        expect(DailyWordRound(daily!).submit(daily.answer.text), isNull);
      }
    }
  });

  test('café and candy use sentences written in the selected language', () {
    for (final course in StudyCourse.multilingualCourses) {
      final writing = switch (course.studyLanguage) {
        'zh' => RegExp(r'[\u3400-\u9fff]'),
        'ar' => RegExp(r'[\u0621-\u064a]'),
        'ko' => RegExp(r'[\uac00-\ud7a3]'),
        'ja' => RegExp(r'[ぁ-ゖァ-ヺ]'),
        'tr' => RegExp(r'[çğıİöşüÇĞÖŞÜ]'),
        _ => RegExp(r'[a-z]'),
      };
      for (final level in _levels) {
        final kitchen = kitchenOrdersFor(course: course, level: level, seed: 8);
        expect(kitchen, hasLength(level == CefrLevel.a1 ? 5 : 0));
        for (final order in kitchen) {
          expect(order.phrase(course.studyLanguage), matches(writing));
          expect(order.phrase(course.studyLanguage), isNot(order.phrase('en')));
          expect(order.phrase(course.translationLanguage), isNotEmpty);
        }
        final candy = candyOrdersFor(course: course, level: level, seed: 8);
        expect(candy, hasLength(3));
        final english = candyOrdersFor(
          course: StudyCourse.englishFromRussian,
          level: level,
          seed: 8,
        );
        for (final (index, order) in candy.indexed) {
          expect(order.level, level);
          expect(order.courseId, course.id);
          expect(order.phrase, matches(writing));
          expect(order.phrase, isNot(english[index].phrase));
          expect(order.target, english[index].target);
          expect(order.translation, isNotEmpty);
        }
      }
      expect(candyAvailableFor(course, CefrLevel.c2), isFalse);
    }
  });

  test('French articles elide and accents survive keyboard normalization', () {
    const word = Word(
      id: 'fr_ecole',
      text: 'école',
      translation: 'school',
      article: 'l’',
    );
    expect(word.headword, 'l’école');
    expect(normalizedCourseSpelling('FAC\u0327ON'), 'façon');
    expect(normalizedCourseSpelling('c\u2019est'), "c'est");
  });

  test('Arabic optional marks preserve spelling distinctions', () {
    expect(normalizedCourseSpelling('مَدْرَسَة'), 'مدرسة');
    expect(normalizedCourseSpelling('ا\u0654مل'), 'أمل');
    expect(normalizedCourseSpelling('إرسال'), isNot('ارسال'));
    expect(normalizedCourseSpelling('عَلَى'), isNot('علي'));
  });
}
