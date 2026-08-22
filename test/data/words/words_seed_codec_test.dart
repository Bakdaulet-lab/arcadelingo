// Разбор сида слов: форма записи и битые данные.
//
// Только инлайн-фикстуры: кодек чистый, ассет и binding ему не нужны.
// Реальный файл через кодек прогоняет words_seed_loader_test.dart;
// содержание сида (50 слов, закрытый набор part_of_speech, три дистрактора)
// проверяет test/assets/words_seed_test.dart.

import 'dart:convert';

import 'package:arcadelingo/data/words/words_seed_codec.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/result.dart';

const _apple = <String, Object?>{
  'id': 'apple',
  'text': 'apple',
  'translation': 'яблоко',
  'part_of_speech': 'noun',
  'distractors': ['груша', 'слива', 'вишня'],
};

final _isErr = isA<Err<Object?>>();

/// Документ сида формата v1 с записями [words] как есть.
String _doc(List<Object?> words, {Object? version = 1}) => jsonEncode({
  'version': version,
  'source_lang': 'en',
  'target_lang': 'ru',
  'words': words,
});

/// Копия [_apple] с [overrides] поверх; `null` в значении удаляет поле.
Map<String, Object?> _appleWith(Map<String, Object?> overrides) {
  final entry = Map<String, Object?>.of(_apple);
  for (final MapEntry(:key, :value) in overrides.entries) {
    if (value == null) {
      entry.remove(key);
    } else {
      entry[key] = value;
    }
  }
  return entry;
}

void main() {
  group('parseWordsSeed: валидные данные', () {
    test('запись → ReviewItem: слово и дистракторы в исходном порядке', () {
      final items = ok(parseWordsSeed(_doc([_apple])));

      expect(items, hasLength(1));
      final item = items.single;
      expect(item.word.id, 'apple');
      expect(item.word.text, 'apple');
      expect(item.word.translation, 'яблоко');
      expect(item.word.partOfSpeech, 'noun');
      expect(item.distractors, ['груша', 'слива', 'вишня']);
    });

    test('part_of_speech отсутствует → partOfSpeech == null', () {
      final items = ok(
        parseWordsSeed(
          _doc([
            _appleWith({'part_of_speech': null}),
          ]),
        ),
      );

      expect(items.single.word.partOfSpeech, isNull);
    });

    test('порядок записей сохраняется', () {
      final items = ok(
        parseWordsSeed(
          _doc([
            _appleWith({'id': 'bread', 'text': 'bread'}),
            _apple,
          ]),
        ),
      );

      expect(items.map((i) => i.word.id), ['bread', 'apple']);
    });
  });

  group('parseWordsSeed: битые данные → Err, не исключение', () {
    test('невалидный JSON', () {
      expect(() => parseWordsSeed('{bad'), returnsNormally);
      expect(parseWordsSeed('{bad'), _isErr);
    });

    test('корень не объект; words отсутствует или не список', () {
      expect(parseWordsSeed('[]'), _isErr, reason: 'корень — список');
      expect(parseWordsSeed('{"version":1}'), _isErr, reason: 'нет words');
      expect(
        parseWordsSeed('{"version":1,"words":{}}'),
        _isErr,
        reason: 'words — объект',
      );
    });

    test('version не 1', () {
      expect(parseWordsSeed(_doc([_apple], version: 2)), _isErr);
    });

    test('запись не объект', () {
      expect(parseWordsSeed(_doc([3])), _isErr);
    });

    test('обязательное поле отсутствует или пустое → Err с id записи', () {
      for (final field in ['text', 'translation']) {
        final missing = err(
          parseWordsSeed(
            _doc([
              _appleWith({field: null}),
            ]),
          ),
        );
        expect(missing.message, contains('apple'), reason: 'нет $field');

        final empty = err(
          parseWordsSeed(
            _doc([
              _appleWith({field: ''}),
            ]),
          ),
        );
        expect(empty.message, contains('apple'), reason: 'пустой $field');
      }
    });

    test('id отсутствует или не строка', () {
      expect(
        parseWordsSeed(
          _doc([
            _appleWith({'id': null}),
          ]),
        ),
        _isErr,
        reason: 'нет id',
      );
      expect(
        parseWordsSeed(
          _doc([
            _appleWith({'id': 7}),
          ]),
        ),
        _isErr,
        reason: 'id — число',
      );
    });

    test('part_of_speech есть, но не строка', () {
      expect(
        parseWordsSeed(
          _doc([
            _appleWith({'part_of_speech': 1}),
          ]),
        ),
        _isErr,
      );
    });

    test('distractors отсутствует или содержит не строку', () {
      // Ленивый `cast<String>()` пропустил бы второй случай: TypeError вылетел
      // бы в игре при показе кнопки, а не здесь.
      expect(
        parseWordsSeed(
          _doc([
            _appleWith({'distractors': null}),
          ]),
        ),
        _isErr,
        reason: 'нет distractors',
      );
      expect(
        parseWordsSeed(
          _doc([
            _appleWith({
              'distractors': ['груша', 7],
            }),
          ]),
        ),
        _isErr,
        reason: 'дистрактор — число',
      );
    });
  });
}
