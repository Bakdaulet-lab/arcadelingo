// Разбор сида слов: форма записи и битые данные.
//
// Только инлайн-фикстуры: кодек чистый, ассет и binding ему не нужны.
// Реальный файл через кодек прогоняет words_seed_loader_test.dart;
// содержание сида (закрытый набор part_of_speech, три дистрактора)
// проверяет test/assets/words_seed_test.dart.

import 'dart:convert';

import 'package:arcadelingo/data/words/words_seed_codec.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
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
  test(
    'a noun article can be shown while the stored lemma stays unchanged',
    () {
      final items = ok(
        parseWordsSeed(
          _doc([
            _appleWith({'text': 'Apfel', 'article': 'der'}),
          ]),
        ),
      );
      final word = items.single.word;
      expect(word.article, 'der');
      expect(word.headword, 'der Apfel');
      expect(word.text, 'Apfel');
      expect(
        parseWordsSeed(
          _doc([
            _appleWith({'article': 1}),
          ]),
        ),
        _isErr,
      );
    },
  );

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

    test('старый сид v1 без level читается как A1', () {
      final items = ok(parseWordsSeed(_doc([_apple])));

      expect(items.single.word.level, CefrLevel.a1);
    });

    test('читает все шесть уровней CEFR', () {
      const levels = {
        'a1': CefrLevel.a1,
        'a2': CefrLevel.a2,
        'b1': CefrLevel.b1,
        'b2': CefrLevel.b2,
        'c1': CefrLevel.c1,
        'c2': CefrLevel.c2,
      };
      final items = ok(
        parseWordsSeed(
          _doc([
            for (final level in levels.keys) {..._apple, 'level': level},
          ]),
        ),
      );

      expect(items.map((item) => item.word.level), levels.values);
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

    test('неизвестный или неверно записанный level → Err с id слова', () {
      for (final level in [null, 1, '', 'A2', 'b3']) {
        final failure = err(
          parseWordsSeed(
            _doc([
              {..._apple, 'level': level},
            ]),
          ),
        );

        expect(failure.message, allOf(contains('apple'), contains('level')));
      }
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
