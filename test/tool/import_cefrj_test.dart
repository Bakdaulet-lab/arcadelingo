// Тесты импортёра, а не контента.
//
// Реальный CSV CEFR-J в репозитории не лежит и лежать не будет, поэтому здесь
// маленькая встроенная фикстура: она проверяет правила разбора и разбиения.
// Что в источнике 7799 строк и что после воронки остаётся 1962 слова — это
// свойство источника, и проверяется прогоном на живом файле, а не тестом.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/import_cefrj.dart';

/// Шапка настоящего файла: шесть колонок, нужны первые три.
const _header = 'headword,pos,CEFR,CoreInventory 1,CoreInventory 2,Threshold';

/// Строка источника. Хвостовые колонки пустые — как в большинстве строк CSV.
String _row(String headword, String pos, String level) =>
    '$headword,$pos,$level,,,';

String _csv(List<String> rows) => [_header, ...rows].join('\n');

/// Синтетическое слово из одних строчных букв: `wa`, `wb`, … Цифры в headword
/// нельзя — их отсекает тот самый фильтр формы, который здесь ни при чём.
String _word(int i) {
  final buffer = StringBuffer('w');
  var n = i;
  do {
    buffer.writeCharCode(97 + n % 26);
    n ~/= 26;
  } while (n > 0);
  return buffer.toString();
}

List<String> _rows(int count, String level, {int from = 0}) => [
  for (var i = from; i < from + count; i++) _row(_word(i), 'noun', level),
];

ImportResult _import(
  String csv, {
  Set<String> excluded = const {},
  int? size,
}) => importCefrj(
  csv,
  excludedIds: excluded,
  portionSize: size ?? defaultPortionSize,
);

List<String> _texts(ImportResult result) => [
  for (final portion in result.portions)
    for (final word in portion.words) word.text,
];

ImportedWord _find(ImportResult result, String text) =>
    result.portions.expand((p) => p.words).firstWhere((w) => w.text == text);

void main() {
  group('фильтрация', () {
    test('в порции идут только A1 и A2', () {
      final result = _import(
        _csv([
          _row('apple', 'noun', 'A1'),
          _row('slowly', 'adverb', 'A2'),
          _row('achieve', 'verb', 'B1'),
          _row('abolish', 'verb', 'B2'),
        ]),
      );

      expect(_texts(result), ['apple', 'slowly']);
      expect(result.funnel.rows, 4);
      expect(result.funnel.byLevel, 2);
    });

    test('B1 и B2 в отсев не пишутся: это скоуп задачи, а не потеря', () {
      // 5224 строки B1/B2 в skipped.csv похоронили бы в нём настоящий сигнал.
      final result = _import(
        _csv([_row('apple', 'noun', 'A1'), _row('achieve', 'verb', 'B1')]),
      );

      expect(result.skipped, isEmpty);
    });

    test('часть речи вне набора уходит в отсев с причиной', () {
      final result = _import(
        _csv([
          _row('apple', 'noun', 'A1'),
          _row('she', 'pronoun', 'A1'),
          _row('under', 'preposition', 'A1'),
        ]),
      );

      expect(_texts(result), ['apple']);
      expect(result.skipped.map((r) => r.headword), ['she', 'under']);
      expect(
        result.skipped.map((r) => r.reason),
        everyElement(SkipReason.partOfSpeechOutOfScope),
      );
      expect(result.funnel.byPartOfSpeech, 1);
    });

    test('headword не из одних строчных букв уходит в отсев с причиной', () {
      // Их отсекает наш собственный инвариант id == text, а не источник:
      // это хорошая лексика A1/A2, и молча терять её нельзя.
      final result = _import(
        _csv([
          _row('apple', 'noun', 'A1'),
          _row('bus stop', 'noun', 'A1'),
          _row('April', 'noun', 'A1'),
          _row('t-shirt', 'noun', 'A1'),
          _row('airplane/aeroplane', 'noun', 'A1'),
        ]),
      );

      expect(_texts(result), ['apple']);
      expect(result.skipped, hasLength(4));
      expect(
        result.skipped.map((r) => r.reason),
        everyElement(SkipReason.headwordNotSingleLowercaseWord),
      );
      expect(result.funnel.byHeadwordShape, 1);
    });

    test(
      'в отсеве видно, что именно отброшено: слово, часть речи, уровень',
      () {
        final result = _import(_csv([_row('bus stop', 'noun', 'A2')]));

        final row = result.skipped.single;
        expect(row.headword, 'bus stop');
        expect(row.partOfSpeech, 'noun');
        expect(row.level, 'A2');
      },
    );
  });

  group('источник изменил форму — падение, а не тихий пропуск', () {
    test('неизвестный уровень: номер строки и само значение в сообщении', () {
      // Тихий пропуск C1 выглядел бы как «в источнике таких слов нет».
      expect(
        () => _import(
          _csv([_row('apple', 'noun', 'A1'), _row('x', 'noun', 'C1')]),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('3'), contains('C1')),
          ),
        ),
      );
    });

    test('неизвестная часть речи: номер строки и само значение', () {
      expect(
        () => _import(_csv([_row('x', 'gerund', 'A1')])),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('2'), contains('gerund')),
          ),
        ),
      );
    });

    test('неизвестная часть речи ловится и на строке вне нашего уровня', () {
      // Иначе сторож молчал бы про изменения в B1/B2 до самого апгрейда.
      expect(
        () => _import(_csv([_row('x', 'gerund', 'B2')])),
        throwsA(isA<FormatException>()),
      );
    });

    test('обрезанная строка', () {
      expect(
        () => _import(_csv(['apple,noun'])),
        throwsA(isA<FormatException>()),
      );
    });

    test('пустой headword', () {
      expect(
        () => _import(_csv([_row('', 'noun', 'A1')])),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('дедуп против сида', () {
    test('слово из сида в порцию не попадает', () {
      final result = _import(
        _csv([_row('apple', 'noun', 'A1'), _row('bread', 'noun', 'A1')]),
        excluded: {'apple'},
      );

      expect(_texts(result), ['bread']);
      expect(result.funnel.headwords, 2);
      expect(result.funnel.afterDedup, 1);
    });

    test('дедуп по слову, а не по строке: уходят все части речи сразу', () {
      // water в сиде существительное, а в источнике ещё и глагол. Строка
      // глагола не имеет права вернуться отдельным словом.
      final result = _import(
        _csv([_row('water', 'noun', 'A1'), _row('water', 'verb', 'A1')]),
        excluded: {'water'},
      );

      expect(result.portions, isEmpty);
      expect(result.ambiguous, isEmpty, reason: 'ничья своего слова не наша');
    });
  });

  group('схлопывание многозначного headword', () {
    test('одна часть речи, разные уровни — берётся минимальный', () {
      final result = _import(
        _csv([_row('book', 'noun', 'A2'), _row('book', 'noun', 'A1')]),
      );

      expect(result.portions.single.words, hasLength(1));
      expect(_find(result, 'book').level, 'a1');
      expect(_find(result, 'book').partOfSpeech, 'noun');
    });

    test(
      'разные части речи на разных уровнях — берётся часть речи с минимального',
      () {
        final result = _import(
          _csv([_row('light', 'adjective', 'A2'), _row('light', 'noun', 'A1')]),
        );

        expect(_find(result, 'light').partOfSpeech, 'noun');
        expect(_find(result, 'light').level, 'a1');
        expect(_find(result, 'light').isAmbiguous, isFalse);
        expect(result.ambiguous, isEmpty);
      },
    );

    test('ничья на минимальном уровне — часть речи не выбирается', () {
      // Фиксированный приоритет частей речи молча дал бы «ответ» вместо
      // «отвечать»: слово то же, карточка другая.
      final result = _import(
        _csv([_row('answer', 'verb', 'A1'), _row('answer', 'noun', 'A1')]),
      );

      final word = _find(result, 'answer');
      expect(word.partOfSpeech, isNull);
      expect(word.isAmbiguous, isTrue);
      expect(word.ambiguousPartsOfSpeech, ['noun', 'verb']);
      expect(word.level, 'a1');
      expect(result.funnel.ambiguous, 1);
    });

    test('ничья остаётся в порции: вычитывать её всё равно человеку', () {
      final result = _import(
        _csv([_row('answer', 'verb', 'A1'), _row('answer', 'noun', 'A1')]),
      );

      expect(_texts(result), ['answer']);
      expect(result.funnel.afterDedup, 1);
    });

    test(
      'в ambiguous.csv уходят все варианты слова, включая нижние уровни',
      () {
        final result = _import(
          _csv([
            _row('back', 'adverb', 'A1'),
            _row('back', 'noun', 'A1'),
            _row('back', 'verb', 'A2'),
          ]),
        );

        final ambiguous = result.ambiguous.single;
        expect(ambiguous.headword, 'back');
        expect(ambiguous.level, 'a1');
        expect(ambiguous.variants, ['adverb A1', 'noun A1', 'verb A2']);
        // Выбор — только между теми, кто на минимальном уровне.
        expect(_find(result, 'back').ambiguousPartsOfSpeech, ['adv', 'noun']);
      },
    );

    test('дубль строки целиком ничьей не делает', () {
      final result = _import(
        _csv([_row('apple', 'noun', 'A1'), _row('apple', 'noun', 'A1')]),
      );

      expect(_find(result, 'apple').isAmbiguous, isFalse);
      expect(result.ambiguous, isEmpty);
    });
  });

  group('разбиение по 50', () {
    test('60 слов одного уровня — порции 50 и 10', () {
      final result = _import(_csv(_rows(60, 'A1')));

      expect(result.portions.map((p) => p.words.length), [50, 10]);
      expect(result.portions.map((p) => p.number), [1, 2]);
    });

    test('A1 целиком раньше A2, граничная порция короткая, а не смешанная', () {
      // Иначе порция 17 держала бы хвост A1 и голову A2 одновременно, и
      // «сначала весь A1» перестало бы быть правдой.
      final result = _import(
        _csv([..._rows(60, 'A1'), ..._rows(60, 'A2', from: 100)]),
      );

      expect(result.portions.map((p) => p.level), ['a1', 'a1', 'a2', 'a2']);
      expect(result.portions.map((p) => p.words.length), [50, 10, 50, 10]);
      expect(result.portions.map((p) => p.number), [1, 2, 3, 4]);
      for (final portion in result.portions) {
        expect(
          portion.words.map((w) => w.level),
          everyElement(portion.level),
          reason: 'порция ${portion.number} смешала уровни',
        );
      }
    });

    test('при разбиении ни одно слово не потеряно и не задвоено', () {
      final result = _import(_csv(_rows(137, 'A1')));

      final texts = _texts(result);
      expect(texts, hasLength(137));
      expect(texts.toSet(), hasLength(137));
      expect(texts.toSet(), {for (var i = 0; i < 137; i++) _word(i)});
    });

    test('размер порции — параметр, а не константа в коде', () {
      final result = _import(_csv(_rows(7, 'A1')), size: 3);

      expect(result.portions.map((p) => p.words.length), [3, 3, 1]);
    });
  });

  group('перемешивание', () {
    test('порядок не алфавитный', () {
      // Алфавит собрал бы однокоренные слова в одну порцию, а это ровно то,
      // что запрещено обманкам.
      final texts = _texts(_import(_csv(_rows(60, 'A1'))));

      expect(texts, isNot(orderedEquals([...texts]..sort())));
    });

    test('два прогона на одном CSV дают одинаковые порции', () {
      final csv = _csv(_rows(60, 'A1'));

      expect(_texts(_import(csv)), _texts(_import(csv)));
    });

    test('другой seed — другой порядок', () {
      // Без этого «перемешивание» могло бы игнорировать seed вовсе.
      final csv = _csv(_rows(60, 'A1'));
      final byDefault = _texts(importCefrj(csv, excludedIds: const {}));
      final other = _texts(
        importCefrj(csv, excludedIds: const {}, shuffleSeed: 1),
      );

      expect(other, isNot(orderedEquals(byDefault)));
      expect(other.toSet(), byDefault.toSet());
    });
  });

  group('формат рабочих файлов', () {
    Map<String, Object?> decodePortion(Portion portion) =>
        jsonDecode(encodePortion(portion)) as Map<String, Object?>;

    test('порция: слово с пустым переводом и пустыми обманками', () {
      final result = _import(_csv([_row('apple', 'noun', 'A1')]));
      final json = decodePortion(result.portions.single);

      expect(json['portion'], 1);
      expect(json['level'], 'a1');
      final words = json['words']! as List<Object?>;
      expect(words, hasLength(1));
      expect(words.single, {
        'id': 'apple',
        'text': 'apple',
        'translation': '',
        'part_of_speech': 'noun',
        'level': 'a1',
        'distractors': <String>[],
      });
    });

    test('порция: у ничьей часть речи пуста, а кандидаты рядом', () {
      final result = _import(
        _csv([_row('answer', 'verb', 'A1'), _row('answer', 'noun', 'A1')]),
      );
      final words =
          decodePortion(result.portions.single)['words']! as List<Object?>;
      final word = words.single! as Map<String, Object?>;

      expect(word['part_of_speech'], '');
      expect(word['ambiguous_pos'], ['noun', 'verb']);
    });

    test('порция: одно слово — одна строка, иначе её не заполнить руками', () {
      final result = _import(_csv(_rows(3, 'A1')));
      final lines = encodePortion(result.portions.single).split('\n');
      final wordLines = lines.where((l) => l.contains('"id"'));

      expect(wordLines, hasLength(3));
      expect(
        wordLines,
        everyElement(contains('"distractors"')),
        reason: 'запись разъехалась по строкам',
      );
    });

    test('ambiguous.csv: шапка есть и когда ничьих нет', () {
      // «Ничьих нет» и «импортёр про них забыл» обязаны отличаться.
      expect(encodeAmbiguousCsv(const []).trim(), 'headword,level,variants');
    });

    test('ambiguous.csv: варианты одной ячейкой, без ломки колонок', () {
      final csv = encodeAmbiguousCsv(const [
        AmbiguousWord(
          headword: 'answer',
          level: 'a1',
          variants: ['noun A1', 'verb A1'],
        ),
      ]);
      final row = csv.trim().split('\n').last;

      expect(row.split(',').first, 'answer');
      expect(row, contains('noun A1'));
      expect(row, contains('verb A1'));
    });

    test('skipped.csv: причина текстом, а не кодом', () {
      final csv = encodeSkippedCsv(const [
        SkippedRow(
          headword: 'bus stop',
          partOfSpeech: 'noun',
          level: 'A1',
          reason: SkipReason.headwordNotSingleLowercaseWord,
        ),
      ]);

      expect(csv.trim().split('\n').first, 'headword,pos,CEFR,причина');
      expect(csv, contains(SkipReason.headwordNotSingleLowercaseWord.text));
    });

    test('воронка печатает число на каждом шаге', () {
      final result = _import(
        _csv([
          _row('apple', 'noun', 'A1'),
          _row('bread', 'noun', 'A1'),
          _row('she', 'pronoun', 'A1'),
          _row('bus stop', 'noun', 'A2'),
          _row('achieve', 'verb', 'B1'),
        ]),
        excluded: {'apple'},
      );
      final report = formatFunnel(result.funnel);

      expect(result.funnel.rows, 5);
      expect(result.funnel.byLevel, 4);
      expect(result.funnel.byPartOfSpeech, 3);
      expect(result.funnel.byHeadwordShape, 2);
      expect(result.funnel.headwords, 2);
      expect(result.funnel.afterDedup, 1);
      for (final number in [5, 4, 3, 2, 1]) {
        expect(report, contains('$number'));
      }
    });
  });

  group('страж инварианта: импортёр не пишет в assets', () {
    test('каталог вывода внутри assets запрещён', () {
      for (final path in [
        'assets',
        'assets/',
        'assets/out',
        './assets/out',
        r'assets\out',
        'C:/dev/arcadelingo-content/assets',
      ]) {
        expect(
          () => assertOutDirAllowed(path),
          throwsArgumentError,
          reason: 'путь "$path" пропущен',
        );
      }
    });

    test('обычный каталог вывода разрешён', () {
      expect(() => assertOutDirAllowed('tool/out'), returnsNormally);
      expect(() => assertOutDirAllowed(r'tool\out'), returnsNormally);
    });
  });
}
