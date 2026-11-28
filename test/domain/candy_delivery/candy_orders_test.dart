import 'dart:convert';
import 'dart:io';

import 'package:arcadelingo/domain/candy_delivery/candy_orders.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:flutter_test/flutter_test.dart';

const _courses = [
  StudyCourse.englishFromRussian,
  StudyCourse.englishFromSpanish,
  StudyCourse.spanishFromRussian,
  StudyCourse.spanishFromEnglish,
];

void main() {
  test('only offers directions and levels present in the bundled decks', () {
    final deckLevels = <(String, String)>{};
    final assets = Directory('assets').listSync().whereType<File>();
    for (final file in assets.where(
      (f) => RegExp(r'^words_.*\.json$').hasMatch(f.uri.pathSegments.last),
    )) {
      final deck = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final courseId = '${deck['target_lang']}-${deck['source_lang']}';
      for (final word in (deck['words'] as List).cast<Map<String, dynamic>>()) {
        deckLevels.add((courseId, word['level'] as String));
      }
    }
    expect(deckLevels.length, 17);
    for (final course in _courses) {
      for (final level in CefrLevel.values) {
        final available = deckLevels.contains((course.id, level.name));
        expect(candyAvailableFor(course, level), available);
        final orders = candyOrdersFor(course: course, level: level, seed: 8);
        expect(orders, available ? hasLength(3) : isEmpty);
        for (final order in orders) {
          expect(order.level, level);
          expect(order.courseId, course.id);
        }
      }
    }
    for (final course in [
      const StudyCourse(
        id: 'ru-es',
        studyLanguage: 'en',
        translationLanguage: 'ru',
      ),
      const StudyCourse(
        id: 'fr-es',
        studyLanguage: 'es',
        translationLanguage: 'fr',
      ),
    ]) {
      expect(candyAvailableFor(course, CefrLevel.a1), isFalse);
      expect(
        candyOrdersFor(course: course, level: CefrLevel.a1, seed: 1),
        isEmpty,
      );
    }
  });

  test(
    'each level has its own prompt pool and distinct identifiable targets',
    () {
      for (final course in _courses) {
        final seenLevels = <String, CefrLevel>{};
        for (final level in CefrLevel.values.where(
          (level) => candyAvailableFor(course, level),
        )) {
          final phrasesByTarget = <int, Set<String>>{
            for (var id = 0; id < 3; id++) id: {},
          };
          final positions = <int, Set<int>>{
            for (var id = 0; id < 3; id++) id: {},
          };
          for (var seed = 0; seed < 64; seed++) {
            final orders = candyOrdersFor(
              course: course,
              level: level,
              seed: seed,
            );
            expect(orders.map((o) => o.target), unorderedEquals([0, 1, 2]));
            for (final order in orders) {
              expect(order.rabbits, unorderedEquals([0, 1, 2]));
              expect(order.translation.trim(), isNotEmpty);
              expect(order.phrase, isNot(order.translation));
              expect(seenLevels.putIfAbsent(order.phrase, () => level), level);
              phrasesByTarget[order.target]!.add(order.phrase);
              positions[order.target]!.add(order.rabbits.indexOf(order.target));
            }
          }
          expect(
            phrasesByTarget.values.map((phrases) => phrases.length),
            everyElement(greaterThanOrEqualTo(2)),
          );
          expect(
            positions.values.map((lanes) => lanes.length),
            everyElement(3),
          );
        }
      }
    },
  );

  test(
    'target language and gloss independently follow the selected course',
    () {
      for (final level in CefrLevel.values.where((l) => l != CefrLevel.c2)) {
        for (var seed = 0; seed < 20; seed++) {
          final esRu = candyOrdersFor(
            course: StudyCourse.spanishFromRussian,
            level: level,
            seed: seed,
          );
          final esEn = candyOrdersFor(
            course: StudyCourse.spanishFromEnglish,
            level: level,
            seed: seed,
          );
          final enRu = candyOrdersFor(
            course: StudyCourse.englishFromRussian,
            level: level,
            seed: seed,
          );
          for (var i = 0; i < esRu.length; i++) {
            expect(esRu[i].phrase, esEn[i].phrase);
            expect(esRu[i].translation, enRu[i].translation);
            expect(esEn[i].translation, enRu[i].phrase);
            expect(esRu[i].target, enRu[i].target);
            if (level == CefrLevel.a1) {
              final enEs = candyOrdersFor(
                course: StudyCourse.englishFromSpanish,
                level: level,
                seed: seed,
              );
              expect(enEs[i].translation, esRu[i].phrase);
              expect(enEs[i].phrase, enRu[i].phrase);
            }
          }
        }
      }
      final sample = List.generate(
            32,
            (seed) => candyOrdersFor(
              course: StudyCourse.spanishFromRussian,
              level: CefrLevel.a2,
              seed: seed,
            ),
          )
          .expand((o) => o)
          .firstWhere((o) => o.phrase == 'Para el conejo que duerme.');
      expect(sample.target, 1);
      expect(sample.translation, 'Для кролика, который спит.');
      expect(() => sample.rabbits.clear(), throwsUnsupportedError);
    },
  );
}
