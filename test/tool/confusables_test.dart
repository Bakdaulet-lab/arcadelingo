// Тесты файла ловушек `tool/confusables.csv`.
//
// Зеркальные пары валидатор находит сам (взаимность обманок). Почти-синонимы
// и однокоренные переводы механически не видны — их видит только вычитывающий,
// и без файла это знание испаряется вместе с сессией. Тот же принцип, что у
// `rejected.json`.

import 'package:flutter_test/flutter_test.dart';

import '../../tool/confusables.dart';
import '../../tool/seed_rules.dart';

const String _csv = '''
first,second,reason
open,close,взаимные обманки: у open «закрывать», у close «открывать»
step,walk,«шагать» и «ходить» — почти синонимы на разных карточках
''';

/// Документ с зеркальной парой: у каждого слова в обманках перевод другого.
Map<String, Object?> _docWithPair(String first, String second) => {
  'version': seedFormatVersion,
  'source_lang': 'en',
  'target_lang': 'ru',
  'words': [
    {
      'id': first,
      'text': first,
      'translation': 'открывать',
      'part_of_speech': 'verb',
      'level': 'a1',
      'distractors': ['закрывать', 'ломать', 'толкать'],
    },
    {
      'id': second,
      'text': second,
      'translation': 'закрывать',
      'part_of_speech': 'verb',
      'level': 'a1',
      'distractors': ['открывать', 'прятать', 'держать'],
    },
  ],
};

void main() {
  group('разбор файла', () {
    test('пара и причина', () {
      final pairs = parseConfusables(_csv);

      expect(pairs, hasLength(2));
      expect(pairs.first.first, 'open');
      expect(pairs.first.second, 'close');
      expect(pairs.last.reason, contains('почти синонимы'));
    });

    test('запятая внутри причины не ломает колонки', () {
      // Причину пишет человек, и запятых в ней сколько угодно: id — только
      // первые две колонки, остальное целиком причина.
      expect(
        parseConfusables(_csv).first.reason,
        'взаимные обманки: у open «закрывать», у close «открывать»',
      );
    });

    test('пустой файл и файл из одной шапки', () {
      expect(parseConfusables(''), isEmpty);
      expect(parseConfusables('first,second,reason\n'), isEmpty);
    });

    test('битая строка роняет разбор, а не пропускается', () {
      expect(
        () => parseConfusables('first,second,reason\nopen\n'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseConfusables('first,second,reason\nopen,,причина\n'),
        throwsA(isA<FormatException>()),
      );
    });

    test('пара без причины — как отказ без причины', () {
      // Файл существует ради причин: без них он просто список.
      expect(
        () => parseConfusables('first,second,reason\nopen,close,\n'),
        throwsA(isA<FormatException>()),
      );
    });

    test('слово в паре с самим собой', () {
      expect(
        () => parseConfusables('first,second,reason\nopen,open,причина\n'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ключ пары не зависит от порядка', () {
    test('open,close и close,open — одна и та же пара', () {
      expect(confusableKey('open', 'close'), confusableKey('close', 'open'));
    });

    test('разные пары — разные ключи', () {
      expect(
        confusableKey('open', 'close'),
        isNot(confusableKey('open', 'water')),
      );
    });
  });

  group('сверка файла с сидом: каждый id обязан существовать', () {
    // Опечатку в id иначе не заметит никто и никогда: ручные пары по
    // определению не находятся автоматически, сверять их не с чем.
    Map<String, Object?> seedOf(List<String> ids) => {
      'version': seedFormatVersion,
      'source_lang': 'en',
      'target_lang': 'ru',
      'words': [
        for (final id in ids)
          {
            'id': id,
            'text': id,
            'translation': 'слово',
            'part_of_speech': 'noun',
            'level': 'a1',
            'distractors': const ['один', 'два', 'три'],
          },
      ],
    };

    test('оба слова пары в сиде — нарушения нет', () {
      expect(
        checkConfusablesExist(seedOf(['open', 'close', 'step', 'walk']), _csv),
        isEmpty,
      );
    });

    test('слова нет в сиде — нарушение называет и слово, и пару', () {
      final problems = checkConfusablesExist(
        seedOf(['open', 'close', 'step']),
        _csv,
      );

      expect(problems, hasLength(1));
      expect(problems.single.rule, SeedRule.confusableWordMissing);
      expect(
        problems.single.message,
        allOf(contains('walk'), contains('step')),
      );
    });

    test('нет обоих слов пары — два нарушения, а не одно', () {
      // Иначе вторую опечатку в той же строке нашли бы только следующим
      // прогоном.
      expect(
        checkConfusablesExist(
          seedOf(const []),
          'first,second,reason\nopen,close,причина\n',
        ),
        hasLength(2),
      );
    });

    test('пустой файл ловушек — проверять нечего', () {
      expect(checkConfusablesExist(seedOf(['open']), ''), isEmpty);
    });
  });

  group('сверка найденных зеркальных пар с файлом', () {
    test('пара внесена — нарушения нет', () {
      expect(
        checkMirrorPairsListed(_docWithPair('open', 'close'), _csv),
        isEmpty,
      );
    });

    test('внесена в обратном порядке — тоже нарушения нет', () {
      expect(
        checkMirrorPairsListed(
          _docWithPair('close', 'open'),
          'first,second,reason\nopen,close,причина\n',
        ),
        isEmpty,
      );
    });

    test('пара не внесена — нарушение с обоими словами в сообщении', () {
      final problems = checkMirrorPairsListed(
        _docWithPair('give', 'take'),
        _csv,
      );

      expect(problems, hasLength(1));
      expect(problems.single.rule, SeedRule.mirrorPairNotListed);
      expect(
        problems.single.message,
        allOf(contains('give'), contains('take')),
      );
    });

    test('зеркальных пар нет — проверять нечего', () {
      const empty = <String, Object?>{
        'version': seedFormatVersion,
        'source_lang': 'en',
        'target_lang': 'ru',
        'words': <Object?>[],
      };

      expect(checkMirrorPairsListed(empty, _csv), isEmpty);
    });

    test('лишняя запись в файле нарушением не является', () {
      // Правило одностороннее: найденное обязано быть записано, но записанное
      // не обязано находиться — почти-синонимы валидатор и не найдёт.
      expect(
        checkMirrorPairsListed(_docWithPair('open', 'close'), _csv),
        isEmpty,
        reason: 'пара step↔walk в файле есть, а в документе её нет',
      );
    });
  });
}
