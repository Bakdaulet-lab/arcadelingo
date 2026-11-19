import 'dart:convert';

import 'package:arcadelingo/data/words/words_seed_codec.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the Spanish–English seed preserves Spanish A1 words and uses unique English options',
    () async {
      final source = await rootBundle.loadString('assets/words_es_a1_en.json');
      final metadata = jsonDecode(source) as Map<String, dynamic>;
      expect(metadata['source_lang'], 'es');
      expect(metadata['target_lang'], 'en');
      final items = (parseWordsSeed(source) as Ok<List<ReviewItem>>).value;
      final original = await rootBundle.loadString('assets/words_es_a1.json');
      final base = (parseWordsSeed(original) as Ok<List<ReviewItem>>).value;
      final a1 = {
        for (final item in base)
          if (item.word.level == CefrLevel.a1) item.word.id: item.word,
      };
      expect(items, hasLength(a1.length));
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
      final english = RegExp(r'^[A-Za-z]+(?:[ -][a-z]+)*$');
      expect(byTranslation['boy']?.text, 'niño');
      expect(byTranslation['house']?.text, 'casa');
      expect(byTranslation['song']?.text, 'canción');
      expect(byTranslation['ice cream']?.text, 'helado');
      expect(byTranslation['ticket']?.text, 'billete');
      expect(
        {
          for (final day in [
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
          ])
            day: byTranslation[day]?.text,
        },
        {
          'Monday': 'lunes',
          'Tuesday': 'martes',
          'Wednesday': 'miércoles',
          'Thursday': 'jueves',
          'Friday': 'viernes',
          'Saturday': 'sábado',
          'Sunday': 'domingo',
        },
      );
      for (final item in items) {
        final word = item.word;
        expect(word.level, CefrLevel.a1);
        expect(word.text, matches(RegExp(r'^[a-záéíóúüñ]+$')));
        expect(a1[word.id]?.text, word.text);
        expect(a1[word.id]?.partOfSpeech, word.partOfSpeech);
        final choices = [word.translation, ...item.distractors];
        expect(choices, hasLength(4));
        expect(choices.toSet(), hasLength(4));
        for (final choice in choices) {
          expect(choice, matches(english));
          expect(byTranslation[choice]?.partOfSpeech, word.partOfSpeech);
        }
      }
    },
  );
}
