import 'dart:convert';

import 'package:arcadelingo/data/words/words_seed_codec.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<ReviewItem>> _read(String path, String target) async {
  final source = await rootBundle.loadString('assets/$path.json');
  final doc = jsonDecode(source) as Map<String, dynamic>;
  expect(doc['source_lang'], 'es');
  expect(doc['target_lang'], target);
  return (parseWordsSeed(source) as Ok<List<ReviewItem>>).value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (level, count, earlierLevels) in [
    (CefrLevel.a2, 300, ['a1']),
    (CefrLevel.b1, 300, ['a1', 'a2']),
    (CefrLevel.b2, 300, ['a1', 'a2', 'b1']),
  ]) {
    test(
      'Spanish ${level.name} aligns both courses and has four distinct same-POS options',
      () async {
        final spanish = RegExp(r'^[a-záéíóúüñ]+$');
        final earlier = [
          for (final code in earlierLevels)
            ...await _read('words_es_$code', 'ru'),
        ];
        final earlierIds = earlier.map((item) => item.word.id).toSet();
        final earlierWords = earlier.map((item) => item.word.text).toSet();
        final ru = await _read('words_es_${level.name}', 'ru');
        final en = await _read('words_es_${level.name}_en', 'en');

        expect(ru, hasLength(count));
        expect(en, hasLength(ru.length));
        expect(ru.map((item) => item.word.id).toSet(), hasLength(ru.length));
        expect(ru.map((item) => item.word.text).toSet(), hasLength(ru.length));
        final enWords = {for (final item in en) item.word.id: item.word};
        expect(enWords, hasLength(en.length));

        for (final item in ru) {
          final word = item.word;
          expect(earlierIds, isNot(contains(word.id)));
          expect(earlierWords, isNot(contains(word.text)));
          expect(word.text, matches(spanish));
          expect(word.text.length, lessThanOrEqualTo(12));
          expect(enWords[word.id]?.text, word.text);
          expect(enWords[word.id]?.partOfSpeech, word.partOfSpeech);
        }

        for (final (items, script) in [
          (ru, RegExp(r'^[а-яё]+(?:[ -][а-яё]+)*$')),
          (en, RegExp(r'^[a-z]+(?:[ -][a-z]+)*$')),
        ]) {
          final byTranslation = {
            for (final item in items) item.word.translation: item.word,
          };
          expect(byTranslation, hasLength(items.length));
          for (final item in items) {
            final word = item.word;
            expect(word.level, level);
            final choices = [word.translation, ...item.distractors];
            expect(choices, hasLength(4));
            expect(choices.toSet(), hasLength(4));
            for (final choice in choices) {
              expect(choice, matches(script));
              expect(byTranslation[choice]?.partOfSpeech, word.partOfSpeech);
            }
          }
        }
      },
    );
  }
}
