import 'dart:convert';

import 'package:arcadelingo/data/words/words_seed_codec.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled Spanish A1 cards have distinct Russian A1 options', () async {
    final asset = await rootBundle.loadString('assets/words_es_a1.json');
    final data = jsonDecode(asset) as Map<String, dynamic>;
    expect(data['source_lang'], 'es');
    expect(data['target_lang'], 'ru');
    final items = (parseWordsSeed(asset) as Ok<List<ReviewItem>>).value;
    expect(items, hasLength(greaterThanOrEqualTo(200)));
    expect(items.map((item) => item.word.id).toSet(), hasLength(items.length));
    expect(
      items.map((item) => item.word.text).toSet(),
      hasLength(items.length),
    );

    final words = {for (final item in items) item.word.text: item.word};
    expect(words['niño']?.translation, 'мальчик');
    expect(words['música']?.translation, 'музыка');
    expect(words['canción']?.translation, 'песня');
    final parts = <String, Set<String?>>{};
    for (final item in items) {
      parts
          .putIfAbsent(item.word.translation, () => {})
          .add(item.word.partOfSpeech);
    }

    final spanish = RegExp(r'^[a-záéíóúüñ]+$');
    final russian = RegExp(r'^[а-яё-]+(?: [а-яё-]+)*$');
    for (final item in items) {
      final word = item.word;
      expect(word.level, CefrLevel.a1, reason: word.text);
      expect(word.text, matches(spanish));
      expect(item.distractors, hasLength(3), reason: word.text);
      final options = [word.translation, ...item.distractors];
      expect(options.toSet(), hasLength(4), reason: word.text);
      for (final option in options) {
        expect(option, matches(russian));
        expect(parts[option], contains(word.partOfSpeech), reason: word.text);
      }
    }
  });
}
