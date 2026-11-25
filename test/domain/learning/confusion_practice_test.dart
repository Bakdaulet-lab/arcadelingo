import 'dart:math';

import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/learning/confusion_practice.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:flutter_test/flutter_test.dart';

Word card(
  String term,
  String gloss, {
  String? example,
  CefrLevel level = CefrLevel.a1,
}) => Word(
  id: 'mine-$term',
  text: term,
  translation: gloss,
  level: level,
  example: example,
);

List<ConfusionQuestion> practice(Word a, Word b, StudyCourse course) =>
    buildConfusionPractice(
      first: a,
      second: b,
      course: course,
      random: Random(17),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (course, load, pairs) in [
    (
      StudyCourse.englishFromRussian,
      loadWordsSeed,
      [
        ('buy', 'sell'),
        ('spoon', 'fork'),
        ('satellite', 'comet'),
        ('insufficient', 'redundant'),
        ('manicure', 'pedicure'),
        ('jarring', 'melodious'),
      ],
    ),
    (
      StudyCourse.englishFromSpanish,
      loadEnglishA1FromSpanishSeed,
      [('today', 'tomorrow')],
    ),
    for (final (course, load) in [
      (StudyCourse.spanishFromRussian, loadSpanishSeed),
      (StudyCourse.spanishFromEnglish, loadSpanishFromEnglishSeed),
    ])
      (
        course,
        load,
        [
          ('comprar', 'vender'),
          ('descuento', 'recibo'),
          ('despegar', 'aterrizar'),
          ('matiz', 'premisa'),
          ('falacia', 'corolario'),
        ],
      ),
  ]) {
    test(
      'real deck pairs have two distinct cloze sentences in ${course.id}',
      () async {
        final cards = (await load() as Ok<List<ReviewItem>>).value;
        for (final (first, second) in pairs) {
          final a = cards.singleWhere((item) => item.word.text == first).word;
          final b = cards.singleWhere((item) => item.word.text == second).word;
          final questions = practice(a, b, course);
          expect(questions.map((q) => q.target), unorderedEquals([a, b]));
          expect(questions.map((q) => q.prompt).toSet(), hasLength(2));
          for (final q in questions) {
            expect(q.kind, ConfusionPromptKind.sentence, reason: q.target.text);
            expect(q.choices, unorderedEquals([a, b]));
            expect(q.cue, q.target.translation);
            expect(
              q.completedSentence,
              q.prompt.replaceFirst('___', q.target.text),
            );
          }
        }
      },
    );
  }

  test('the same traer/tomar contrast works for both teaching languages', () {
    for (final (course, bring, take) in [
      (StudyCourse.spanishFromRussian, 'приносить', 'брать'),
      (StudyCourse.spanishFromEnglish, 'bring', 'take'),
    ]) {
      final qs = practice(card('traer', bring), card('tomar', take), course);
      expect(qs.map((q) => q.kind), everyElement(ConfusionPromptKind.sentence));
      expect(
        qs.firstWhere((q) => q.target.text == 'traer').completedSentence,
        contains('traer '),
      );
      expect(
        qs.firstWhere((q) => q.target.text == 'tomar').completedSentence,
        contains('tomar '),
      );
    }
  });

  test(
    'masks the exact card example including multiword forms and punctuation',
    () {
      final a = card('té', 'чай', example: '¿Hay té sin azúcar?');
      final b = card(
        'de vez en cuando',
        'время от времени',
        example: 'Lo veo de vez en cuando.',
      );
      final qs = practice(a, b, StudyCourse.spanishFromRussian);
      expect(
        qs.map((q) => q.prompt),
        unorderedEquals(['¿Hay ___ sin azúcar?', 'Lo veo ___.']),
      );
      expect(
        qs.map((q) => q.completedSentence),
        unorderedEquals([a.example, b.example]),
      );
    },
  );

  test(
    'does not teach another sense, guess inflections or mask parts of words',
    () {
      for (final (text, example) in [
        ('mañana', 'Cada mañana nado.'),
        ('pan', 'Hay una pantalla aquí.'),
        ('pensar', 'Ya pienso en eso.'),
        ('eco', 'Un eco tras otro eco.'),
      ]) {
        final a = card(
          text,
          text == 'mañana' ? 'утро' : 'мой перевод',
          example: text == 'mañana' ? null : example,
        );
        final qs = practice(
          a,
          card('otro', 'другой'),
          StudyCourse.spanishFromRussian,
        );
        final q = qs.firstWhere((q) => q.target == a);
        expect(q.kind, ConfusionPromptKind.meaning);
        expect(q.prompt, contains(a.translation));
        expect(q.cue, isNull);
        expect(q.completedSentence, isNull);
      }
    },
  );

  test(
    'fallback uses the course base language, quotes the exact personal gloss and covers each word',
    () {
      for (final (course, gloss, marker) in [
        (StudyCourse.spanishFromRussian, 'любимый двор', '«любимый двор»'),
        (StudyCourse.spanishFromEnglish, 'favorite yard', '“favorite yard”'),
        (StudyCourse.englishFromSpanish, 'patio favorito', '«patio favorito»'),
      ]) {
        final a = card('custom entry', gloss);
        final b = card('another entry', '…');
        final qs = practice(a, b, course);
        expect(qs.map((q) => q.target), unorderedEquals([a, b]));
        expect(qs.firstWhere((q) => q.target == a).prompt, contains(marker));
        expect(
          qs.map((q) => q.kind),
          everyElement(ConfusionPromptKind.meaning),
        );
      }
    },
  );

  test('ambiguous duplicates and mixed levels cannot start a practice', () {
    final a = card('bring', 'приносить');
    for (final b in [
      a,
      card('BRING', 'приводить'),
      card('carry', ' Приносить '),
      card('take', 'брать', level: CefrLevel.a2),
    ]) {
      expect(practice(a, b, StudyCourse.englishFromRussian), isEmpty);
    }
  });
}
