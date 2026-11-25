import 'package:arcadelingo/domain/learning/custom_review_items.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only current course words of the chosen level enter a set round', () {
    const home = Word(id: 'home', text: 'casa', translation: 'дом');
    const key = Word(id: 'custom:key', text: 'llave', translation: 'ключ');
    const day = Word(id: 'day', text: 'día', translation: 'день');
    const permit = Word(
      id: 'permit',
      text: 'permiso',
      translation: 'разрешение',
      level: CefrLevel.b1,
    );
    final items = buildWordSetReviewItems(
      vocabulary: [day, permit, home, key],
      wordIds: [
        'custom:key',
        'deleted',
        'home',
        'from-another-course',
        'permit',
        'home',
      ],
      level: CefrLevel.a1,
    );
    expect(items.map((item) => item.word), [key, home]);
    expect(items.first.distractors, ['дом']);
    expect(items.last.distractors, ['ключ']);
  });

  test('a missing set member and an empty set never borrow course words', () {
    const key = Word(id: 'key', text: 'key', translation: 'ключ');
    for (final ids in [
      <String>[],
      ['retired-id'],
    ]) {
      expect(
        buildWordSetReviewItems(
          vocabulary: [key],
          wordIds: ids,
          level: CefrLevel.a1,
        ),
        isEmpty,
      );
    }
    final items = buildWordSetReviewItems(
      vocabulary: [key],
      wordIds: ['key', 'retired-id'],
      level: CefrLevel.a1,
    );
    expect(items.single.distractors, isEmpty);
  });

  test(
    'other senses can exclude an ambiguous option but never enter choices',
    () {
      const lift = Word(
        id: 'lift',
        text: 'lift',
        translation: 'поднять / приподнять',
      );
      const otherSense = Word(
        id: 'other-sense',
        text: 'Lift',
        translation: 'подъёмник',
      );
      const elevator = Word(
        id: 'elevator',
        text: 'elevator',
        translation: 'подъёмник',
      );
      const raise = Word(id: 'raise', text: 'raise', translation: 'приподнять');
      const door = Word(id: 'custom:door', text: 'door', translation: 'дверь');
      final items = buildWordSetReviewItems(
        vocabulary: [lift, otherSense, elevator, raise, door],
        wordIds: ['lift', 'elevator', 'raise', 'custom:door'],
        level: CefrLevel.a1,
      );
      expect(items.map((item) => item.word), [lift, elevator, raise, door]);
      expect(items.first.distractors, ['дверь']);
    },
  );
}
