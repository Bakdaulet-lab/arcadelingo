// Тесты правил содержания сида.
//
// Правила живут одним файлом и читаются двумя потребителями: тестом ассета на
// живом файле и мерджем на ещё не записанном документе. Здесь проверяются сами
// правила — на выдуманных документах, а не на настоящем сиде.

import 'package:flutter_test/flutter_test.dart';

import '../../tool/seed_rules.dart';

Map<String, Object?> _word(
  String id, {
  Object? text,
  Object? translation = 'слово',
  Object? partOfSpeech = 'noun',
  Object? level = 'a1',
  Object? distractors,
}) => {
  'id': id,
  'text': text ?? id,
  'translation': translation,
  'part_of_speech': partOfSpeech,
  'level': level,
  'distractors': distractors ?? ['один', 'два', 'три'],
};

Map<String, Object?> _doc(
  List<Object?> words, {
  Object? version = seedFormatVersion,
  Object? sourceLang = 'en',
  Object? targetLang = 'ru',
}) => {
  'version': version,
  'source_lang': sourceLang,
  'target_lang': targetLang,
  'words': words,
};

List<SeedRule> _rules(Object? root) =>
    validateSeed(root).map((problem) => problem.rule).toList();

void main() {
  test('корректный документ — ни одного нарушения', () {
    expect(
      validateSeed(
        _doc([
          _word('apple', translation: 'яблоко'),
          _word('bread', translation: 'хлеб'),
        ]),
      ),
      isEmpty,
    );
  });

  group('корень', () {
    test('чужая версия формата, не тот язык, отсутствующий список', () {
      expect(_rules(_doc(const [], version: 2)), [SeedRule.document]);
      expect(_rules(_doc(const [], sourceLang: 'de')), [SeedRule.document]);
      expect(_rules(_doc(const [], targetLang: 'kk')), [SeedRule.document]);
      expect(_rules(const <String, Object?>{}), [SeedRule.document]);
      expect(_rules('не объект'), [SeedRule.document]);
    });

    test('сломанный корень не тянет за собой каскад других правил', () {
      // Иначе в отчёте было бы двадцать нарушений на данных, которых нет.
      expect(_rules({'version': 1, 'words': 'не список'}), [SeedRule.document]);
    });
  });

  group('identity', () {
    test('id не равен text в нижнем регистре', () {
      expect(
        _rules(_doc([_word('apple', text: 'Apple')])),
        contains(SeedRule.identity),
      );
    });

    test('пустой перевод и отсутствующий id', () {
      expect(
        _rules(_doc([_word('apple', translation: '')])),
        contains(SeedRule.identity),
      );
      expect(_rules(_doc(const [<String, Object?>{}])), [SeedRule.identity]);
    });
  });

  test('uniqueIds: два слова с одним id', () {
    expect(
      _rules(
        _doc([
          _word('apple', translation: 'яблоко'),
          _word('apple', translation: 'груша'),
        ]),
      ),
      contains(SeedRule.uniqueIds),
    );
  });

  test('partOfSpeech: значение источника, а не наше', () {
    // adjective — как в CEFR-J; у нас adj. Разойтись эти наборы не имеют права.
    expect(
      _rules(_doc([_word('big', partOfSpeech: 'adjective')])),
      contains(SeedRule.partOfSpeech),
    );
    expect(
      _rules(_doc([_word('big', partOfSpeech: null)])),
      contains(SeedRule.partOfSpeech),
    );
  });

  test('level: верхний регистр как в источнике и отсутствующее поле', () {
    expect(_rules(_doc([_word('big', level: 'A1')])), contains(SeedRule.level));
    expect(_rules(_doc([_word('big', level: null)])), contains(SeedRule.level));
  });

  group('distractors', () {
    test('не три штуки', () {
      expect(
        _rules(
          _doc([
            _word('big', distractors: ['один', 'два']),
          ]),
        ),
        contains(SeedRule.distractors),
      );
      expect(
        _rules(
          _doc([
            _word('big', distractors: ['один', 'два', 'три', 'четыре']),
          ]),
        ),
        contains(SeedRule.distractors),
      );
    });

    test('повторяются между собой', () {
      expect(
        _rules(
          _doc([
            _word('big', distractors: ['один', 'один', 'три']),
          ]),
        ),
        contains(SeedRule.distractors),
      );
    });

    test('обманка совпадает с переводом — верный ответ на двух кнопках', () {
      expect(
        _rules(
          _doc([
            _word(
              'big',
              translation: 'большой',
              distractors: ['большой', 'два', 'три'],
            ),
          ]),
        ),
        contains(SeedRule.distractors),
      );
    });

    test('пустая обманка', () {
      expect(
        _rules(
          _doc([
            _word('big', distractors: ['', 'два', 'три']),
          ]),
        ),
        contains(SeedRule.distractors),
      );
    });
  });

  test('script: латиница в переводе, кириллица в слове', () {
    expect(
      _rules(_doc([_word('big', translation: 'bolshoy')])),
      contains(SeedRule.script),
    );
    expect(
      _rules(_doc([_word('большой', text: 'большой')])),
      contains(SeedRule.script),
    );
    expect(
      _rules(
        _doc([
          _word('big', distractors: ['one', 'два', 'три']),
        ]),
      ),
      contains(SeedRule.script),
    );
  });

  group('translationCollision', () {
    test('два слова с одним переводом', () {
      // «начинать» верно и для start, и для begin: попав обманкой ко второму,
      // оно накажет игрока за правильный ответ.
      final problems = validateSeed(
        _doc([
          _word('start', translation: 'начинать'),
          _word('begin', translation: 'начинать'),
        ]),
      );

      expect(
        problems.map((p) => p.rule),
        contains(SeedRule.translationCollision),
      );
      expect(
        problems
            .firstWhere((p) => p.rule == SeedRule.translationCollision)
            .message,
        allOf(contains('start'), contains('begin')),
        reason: 'в сообщении обязаны быть оба слова, иначе искать вручную',
      );
    });

    test('регистр и пробелы по краям не спасают от столкновения', () {
      expect(
        _rules(
          _doc([
            _word('start', translation: 'начинать'),
            _word('begin', translation: ' начинать'),
          ]),
        ),
        contains(SeedRule.translationCollision),
      );
    });
  });

  test('identicalOptions: у двух слов совпал весь набор из четырёх', () {
    // Тогда запоминается позиция кнопки, а не слово.
    expect(
      _rules(
        _doc([
          _word(
            'cat',
            translation: 'кот',
            distractors: ['пёс', 'конь', 'мышь'],
          ),
          _word(
            'dog',
            translation: 'пёс',
            distractors: ['кот', 'конь', 'мышь'],
          ),
        ]),
      ),
      contains(SeedRule.identicalOptions),
    );
  });

  test('совпадение трёх вариантов из четырёх — не нарушение', () {
    expect(
      _rules(
        _doc([
          _word(
            'cat',
            translation: 'кот',
            distractors: ['пёс', 'конь', 'мышь'],
          ),
          _word(
            'dog',
            translation: 'пёс',
            distractors: ['кот', 'конь', 'лиса'],
          ),
        ]),
      ),
      isEmpty,
    );
  });

  group('зеркальные пары — отчёт, а не правило', () {
    test('взаимные обманки находятся', () {
      final pairs = findMirrorPairs(
        _doc([
          _word(
            'open',
            translation: 'открывать',
            distractors: ['закрывать', 'ломать', 'толкать'],
          ),
          _word(
            'close',
            translation: 'закрывать',
            distractors: ['открывать', 'ломать', 'тянуть'],
          ),
        ]),
      );

      expect(pairs, hasLength(1));
      expect(pairs.single.first, 'open');
      expect(pairs.single.second, 'close');
    });

    test('односторонняя обманка парой не считается', () {
      expect(
        findMirrorPairs(
          _doc([
            _word(
              'open',
              translation: 'открывать',
              distractors: ['закрывать', 'ломать', 'толкать'],
            ),
            _word(
              'close',
              translation: 'закрывать',
              distractors: ['тянуть', 'ломать', 'резать'],
            ),
          ]),
        ),
        isEmpty,
      );
    });

    test('пара нарушением не является: запрещать её нельзя', () {
      // В сиде такие пары сделаны намеренно, лечит их правило сессии (Б1).
      expect(
        validateSeed(
          _doc([
            _word(
              'open',
              translation: 'открывать',
              distractors: ['закрывать', 'ломать', 'толкать'],
            ),
            _word(
              'close',
              translation: 'закрывать',
              distractors: ['открывать', 'ломать', 'тянуть'],
            ),
          ]),
        ),
        isEmpty,
      );
    });
  });
}
