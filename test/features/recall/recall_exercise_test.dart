import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/recall/recall_exercise.dart';
import 'package:flutter_test/flutter_test.dart';

const _prompt = Word(id: 'llave', text: 'llave', translation: 'ключ');

RecallExercise _exercise(
  Word target, {
  List<Word> vocabulary = const [],
  int seed = 0,
  List<String> distractors = const [],
}) => RecallExercise(
  item: ReviewItem(word: target, distractors: distractors),
  vocabulary: vocabulary,
  random: Random(seed),
);

void _spell(RecallExercise exercise, Iterable<String> letters) {
  for (final letter in letters) {
    final tile = exercise.tiles.indexed.firstWhere(
      (entry) => entry.$2 == letter && !exercise.selected.contains(entry.$1),
    );
    exercise.selectTile(tile.$1);
  }
}

void main() {
  test('shuffles physical tiles and keeps the two L tiles independent', () {
    for (var seed = 0; seed < 16; seed++) {
      final exercise = _exercise(_prompt, seed: seed);
      expect(exercise.slots, List<String?>.filled(5, null));
      expect(exercise.tiles, unorderedEquals(['l', 'l', 'a', 'v', 'e']));
      expect(exercise.tiles.join(), isNot('llave'));
      _spell(exercise, ['l']);
      exercise.selectTile(exercise.selected.single);
      expect(exercise.selected, hasLength(1));
      _spell(exercise, ['l', 'a', 'e', 'v']);
      expect(exercise.complete, isTrue);
      expect(exercise.correct, isFalse);
      exercise.undo();
      exercise.undo();
      expect(exercise.complete, isFalse);
      expect(exercise.slots, ['l', 'l', 'a', null, null]);
      _spell(exercise, ['v', 'e']);
      expect(exercise.correct, isTrue);
      exercise.clear();
      exercise.undo();
      expect(exercise.selected, isEmpty);
      expect(exercise.complete, isFalse);
    }
  });

  test('keeps accents together and supplies punctuation and spaces', () {
    const word = Word(
      id: 'custom:ru-es:a1:cafe',
      text: '¡Cafe\u0301 2!',
      translation: 'Кофе 2!',
    );
    final exercise = _exercise(word);
    expect(exercise.slots, ['¡', null, null, null, null, ' ', null, '!']);
    expect(exercise.tiles, unorderedEquals(['C', 'a', 'f', 'e\u0301', '2']));
    _spell(exercise, ['C', 'a', 'f', 'e\u0301', '2']);
    expect(exercise.correct, isTrue);
    expect(exercise.slots.join(), word.text);
  });

  test('uses only distinct spellings with no matching sense in this level', () {
    const sources = [
      _prompt,
      Word(id: 'alt', text: 'clave', translation: 'пароль'),
      Word(id: 'polyseme', text: ' CLAVE ', translation: 'шифр / ключ'),
      Word(id: 'key2', text: ' LLAVE ', translation: 'кран'),
      Word(id: 'h', text: 'hora', translation: 'час'),
      Word(id: 'h2', text: ' HORA ', translation: 'время'),
      Word(id: 'b', text: 'bolso', translation: 'сумка'),
      Word(
        id: 'other-level',
        text: 'viaje',
        translation: 'поездка',
        level: CefrLevel.b1,
      ),
    ];
    final counts = <int>{};
    for (var seed = 0; seed < 32; seed++) {
      final exercise = _exercise(_prompt, vocabulary: sources, seed: seed);
      expect(
        exercise.choices.map((s) => s.trim().toLowerCase()),
        unorderedEquals(['llave', 'hora', 'bolso']),
      );
      expect(exercise.choices.where(exercise.isCorrectChoice), [_prompt.text]);
      counts.add(exercise.choices.indexOf(_prompt.text));
    }
    expect(counts, hasLength(3));
  });

  test('favours curated choices over unrelated vocabulary', () {
    final exercise = _exercise(
      _prompt,
      distractors: ['зáмок', 'ручка', 'коробка'],
      vocabulary: const [
        Word(id: 'door', text: 'puerta', translation: 'дверь'),
        Word(id: 'lock', text: 'castillo', translation: 'зáмок'),
        Word(id: 'pen', text: 'bolígrafo', translation: 'ручка'),
        Word(id: 'box', text: 'caja', translation: 'коробка'),
      ],
    );
    expect(
      exercise.choices,
      unorderedEquals(['llave', 'castillo', 'bolígrafo', 'caja']),
    );
  });

  test('handles one-symbol and repeated-symbol spellings and empty pools', () {
    for (final term in ['a', 'll', '…']) {
      final word = Word(id: term, text: term, translation: 'перевод');
      final exercise = _exercise(word);
      expect(exercise.choices, [term]);
      expect(exercise.complete, isFalse);
      for (var i = 0; i < exercise.tiles.length; i++) {
        exercise.selectTile(i);
      }
      expect(exercise.correct, isTrue);
    }
  });
}
