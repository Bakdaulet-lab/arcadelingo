import 'dart:convert';

import 'package:arcadelingo/data/words/words_seed_codec.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the English–Spanish seed uses vetted A1 headwords and unique options',
    () async {
      final source = await rootBundle.loadString('assets/words_en_a1_es.json');
      final metadata = jsonDecode(source) as Map<String, dynamic>;
      expect(metadata['source_lang'], 'en');
      expect(metadata['target_lang'], 'es');
      final items = (parseWordsSeed(source) as Ok<List<ReviewItem>>).value;
      final original = await rootBundle.loadString('assets/words_seed.json');
      final base = (parseWordsSeed(original) as Ok<List<ReviewItem>>).value;
      final a1 = {
        for (final item in base)
          if (item.word.level == CefrLevel.a1) item.word.id: item.word,
      };
      expect(items.length, greaterThanOrEqualTo(200));
      expect(
        items.map((item) => item.word.id).toSet(),
        hasLength(items.length),
      );
      expect(
        items.map((item) => item.word.text).toSet(),
        hasLength(items.length),
      );
      final byTranslation = {
        for (final item in items) item.word.translation: item.word,
      };
      expect(byTranslation, hasLength(items.length));
      final spanish = RegExp(r'^[a-záéíóúüñ]+(?: [a-záéíóúüñ]+)*$');
      expect(byTranslation['pez']?.text, 'fish');
      for (final item in items) {
        final word = item.word;
        expect(word.level, CefrLevel.a1);
        expect(word.text, matches(RegExp(r'^[a-z]+$')));
        expect(a1[word.id]?.text, word.text);
        expect(a1[word.id]?.partOfSpeech, word.partOfSpeech);
        final choices = [word.translation, ...item.distractors];
        expect(choices, hasLength(4));
        expect(choices.toSet(), hasLength(4));
        for (final choice in choices) {
          expect(choice, matches(spanish));
          expect(byTranslation[choice]?.partOfSpeech, word.partOfSpeech);
        }
      }
    },
  );
}
