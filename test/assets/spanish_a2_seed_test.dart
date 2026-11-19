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

  test(
    'Spanish A2 aligns both courses and has four distinct same-POS options',
    () async {
      final spanish = RegExp(r'^[a-záéíóúüñ]+$');
      final a1 = await _read('words_es_a1', 'ru');
      final a1Ids = a1.map((item) => item.word.id).toSet();
      final a1Words = a1.map((item) => item.word.text).toSet();
      final ru = await _read('words_es_a2', 'ru');
      final en = await _read('words_es_a2_en', 'en');

      expect(ru, hasLength(300));
      expect(en, hasLength(ru.length));
      expect(ru.map((item) => item.word.id).toSet(), hasLength(ru.length));
      expect(ru.map((item) => item.word.text).toSet(), hasLength(ru.length));
      final enWords = {for (final item in en) item.word.id: item.word};
      expect(enWords, hasLength(en.length));

      for (final item in ru) {
        final word = item.word;
        expect(a1Ids, isNot(contains(word.id)));
        expect(a1Words, isNot(contains(word.text)));
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
          expect(word.level, CefrLevel.a2);
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
