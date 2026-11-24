import 'package:arcadelingo/domain/learning/custom_review_items.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter_test/flutter_test.dart';

Word word(
  String id,
  String text,
  String translation, [
  CefrLevel level = CefrLevel.b1,
]) => Word(id: id, text: text, translation: translation, level: level);

void main() {
  test(
    'custom questions use distinct translations from their selected level',
    () {
      final target = word('custom:1', 'lift', 'поднять / приподнять');
      final keys = word('custom:2', 'keys', 'ключи');
      final items = buildCustomReviewItems(
        words: [target, keys, word('custom:3', 'white', 'белый', CefrLevel.a1)],
        courseItems: [
          for (final seed in [
            word('lift', ' LIFT ', 'подъёмник'),
            word('elevator', 'elevator', 'подъёмник'),
            word('raise', 'raise', 'приподнять'),
            word('keys', 'keys', ' КЛЮЧИ '),
            word('door', 'door', 'дверь'),
            word('lock', 'lock', 'замок'),
            word('sky', 'sky', 'небо', CefrLevel.c1),
          ])
            ReviewItem(word: seed),
        ],
        level: CefrLevel.b1,
      );
      expect(items.map((item) => item.word), [target, keys]);
      expect(
        items.first.distractors,
        unorderedEquals(['ключи', 'дверь', 'замок']),
      );
    },
  );

  test('a single custom word works even without other translations', () {
    final only = word('custom:1', 'tal vez', 'perhaps');
    final items = buildCustomReviewItems(
      words: [only],
      courseItems: [],
      level: only.level,
    );
    expect(items.single.word, same(only));
    expect(items.single.distractors, isEmpty);
  });
}
