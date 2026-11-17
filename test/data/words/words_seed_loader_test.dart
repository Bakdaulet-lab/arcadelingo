// Реальные ассеты через кодек; число слов сверяется и в тесте ассетов.

import 'dart:convert';

import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/result.dart';

final class _WordBundles extends CachingAssetBundle {
  _WordBundles({required this.c1Id, required this.c1Level});

  final String c1Id;
  final String c1Level;

  @override
  Future<ByteData> load(String key) async {
    final (id, level) = switch (key) {
      wordsSeedAssetPath => ('apple', 'a1'),
      wordsC1AssetPath => (c1Id, c1Level),
      _ => throw ArgumentError.value(key, 'key'),
    };
    final json = jsonEncode({
      'version': 1,
      'source_lang': 'en',
      'target_lang': 'ru',
      'words': [
        {
          'id': id,
          'text': id,
          'translation': 'перевод',
          'level': level,
          'part_of_speech': 'noun',
          'distractors': ['первый', 'второй', 'третий'],
        },
      ],
    });
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(json)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Второй счётчик размера сида. Первый — «ровно N слов» в
  // test/assets/words_seed_test.dart; правятся оба и в одном коммите порции.
  test('loadWordsSeed: 6666 карточек в бандле, C1 после B2', () async {
    final items = ok(await loadWordsSeed());

    expect(items, hasLength(6666));
    expect(items.first.word.id, 'apple');
    expect(items.first.word.level, CefrLevel.a1);
    expect(items.first.distractors, hasLength(3));
    expect(items[719].word.id, 'skiing');
    expect(items[719].word.level, CefrLevel.a2);
    expect(items[1701].word.id, 'bookcase');
    expect(items[1701].word.level, CefrLevel.a2);
    expect(items[1702].word.id, 'climate');
    expect(items[1702].word.level, CefrLevel.b1);
    expect(items[1739].word.id, 'exhausted');
    expect(items[1739].word.level, CefrLevel.b1);
    expect(items[1740].word.id, 'grill');
    expect(items[1740].word.level, CefrLevel.b1);
    expect(items[3603].word.id, 'publisher');
    expect(items[3603].word.level, CefrLevel.b1);
    expect(items[3604].word.id, 'cooperate');
    expect(items[3604].word.level, CefrLevel.b2);
    expect(items[5800].word.id, 'developing');
    expect(items[5800].word.level, CefrLevel.b2);
    expect(items[5801].word.id, 'commercially');
    expect(items[5801].word.level, CefrLevel.c1);
    expect(items.last.word.id, 'insubordinately');
    expect(items.last.word.level, CefrLevel.c1);
  });

  test('loadWordsSeed отклоняет другой уровень в ассете C1', () async {
    final result = await loadWordsSeed(
      bundle: _WordBundles(c1Id: 'clause', c1Level: 'b2'),
    );
    expect(result, isA<Err<List<ReviewItem>>>());
    expect(result.toString(), contains('уровень слова «clause» не C1'));
  });

  test('loadWordsSeed отклоняет повтор id между ассетами', () async {
    final result = await loadWordsSeed(
      bundle: _WordBundles(c1Id: 'apple', c1Level: 'c1'),
    );
    expect(result, isA<Err<List<ReviewItem>>>());
    expect(result.toString(), contains('повторяется id слова «apple»'));
  });
}
