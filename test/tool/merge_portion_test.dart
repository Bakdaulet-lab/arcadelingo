// Тесты сведения порции в сид.
//
// Всё на строках: план сведения строится из текста сида и текста порции и
// возвращает новый текст. Диска здесь нет — им занимается main инструмента.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/merge_portion.dart';
import '../../tool/seed_rules.dart';

/// Сид в том же виде, в каком он лежит в репозитории: одна запись — одна
/// строка, перенос `\n`.
const String _seed = '''
{
  "version": 1,
  "source_lang": "en",
  "target_lang": "ru",
  "words": [
    { "id": "apple", "text": "apple", "translation": "яблоко", "part_of_speech": "noun", "level": "a1", "distractors": ["груша", "слива", "вишня"] },
    { "id": "bread", "text": "bread", "translation": "хлеб", "part_of_speech": "noun", "level": "a1", "distractors": ["сыр", "масло", "каша"] }
  ]
}
''';

/// Дата отказа приходит параметром: иначе тест зависел бы от системных часов.
final DateTime _now = DateTime.utc(2026, 8, 25, 21, 30);

Map<String, Object?> _word(
  String id, {
  Object? translation = 'слово',
  Object? partOfSpeech = 'noun',
  Object? distractors,
  String? reject,
  List<String>? ambiguousPos,
}) => {
  'id': id,
  'text': id,
  'translation': translation,
  'part_of_speech': partOfSpeech,
  'level': 'a1',
  if (ambiguousPos != null) 'ambiguous_pos': ambiguousPos,
  'distractors': distractors ?? ['один', 'два', 'три'],
  if (reject != null) 'reject': reject,
};

String _portion(List<Map<String, Object?>> words, {int number = 7}) =>
    jsonEncode({
      'portion': number,
      'level': 'a1',
      'source': 'CEFR-J Wordlist 1.5',
      'words': words,
    });

MergePlan _plan(List<Map<String, Object?>> words, {String seed = _seed}) =>
    planMerge(seedText: seed, portionJson: _portion(words), now: _now);

Matcher _failsWith(Object matcher) => throwsA(
  isA<FormatException>().having((e) => e.message, 'message', matcher),
);

void main() {
  group('стражи: полузаполненное не проходит молча', () {
    test('пустая часть речи — нерешённая ничья импортёра', () {
      // Импортёр не выбирает часть речи за человека; если человек тоже не
      // выбрал, слово нельзя показать игроку и нельзя свести.
      expect(
        () => _plan([_word('answer', partOfSpeech: '')]),
        _failsWith(allOf(contains('answer'), contains('part_of_speech'))),
      );
    });

    test('часть речи отсутствует вовсе', () {
      expect(
        () => _plan([_word('answer', partOfSpeech: null)]),
        _failsWith(contains('answer')),
      );
    });

    test('пустой перевод', () {
      expect(
        () => _plan([_word('answer', translation: '')]),
        _failsWith(allOf(contains('answer'), contains('translation'))),
      );
    });

    test('обманок меньше трёх', () {
      expect(
        () => _plan([
          _word('answer', distractors: ['один', 'два']),
        ]),
        _failsWith(allOf(contains('answer'), contains('distractors'))),
      );
    });

    test('обманок больше трёх', () {
      expect(
        () => _plan([
          _word('answer', distractors: ['один', 'два', 'три', 'четыре']),
        ]),
        _failsWith(contains('answer')),
      );
    });

    test('в сообщении сразу все плохие записи, а не первая', () {
      // Иначе вычитку правят по одной записи за прогон.
      expect(
        () => _plan([
          _word('one', translation: ''),
          _word('two', partOfSpeech: ''),
          _word('three', distractors: const <String>[]),
        ]),
        _failsWith(allOf(contains('one'), contains('two'), contains('three'))),
      );
    });

    test('отказ без причины', () {
      // Причина — единственное, ради чего файл отказов существует.
      expect(
        () => _plan([_word('adult', reject: '')]),
        _failsWith(allOf(contains('adult'), contains('reject'))),
      );
    });

    test('слово уже есть в сиде: повторное сведение той же порции', () {
      // Проверяется именно страж, а не правило uniqueIds: без сверки с сидом
      // падение всё равно будет, но со словами «id повторяется», из которых
      // не видно, что порция сведена дважды.
      expect(
        () => _plan([_word('apple', translation: 'яблочко')]),
        _failsWith(allOf(contains('apple'), contains('уже есть в сиде'))),
      );
    });

    test('правила сида проверяются до записи: столкновение переводов', () {
      // Страж заполненности тут ни при чём — запись полная. Ловит правило.
      expect(
        () => _plan([_word('pear', translation: 'яблоко')]),
        _failsWith(contains('яблоко')),
      );
    });
  });

  group('отказ', () {
    test('отклонённая запись не обязана быть заполненной', () {
      final plan = _plan([
        _word(
          'adult',
          translation: '',
          partOfSpeech: '',
          reject: 'нет одного главного значения',
        ),
        _word('apricot', translation: 'абрикос'),
      ]);

      expect(plan.accepted, ['apricot']);
      expect(plan.rejected.map((r) => r.id), ['adult']);
    });

    test('отклонённое в сид не попадает', () {
      final plan = _plan([_word('adult', reject: 'причина')]);

      expect(plan.seedText, isNot(contains('adult')));
      expect(plan.wordsAfter, plan.wordsBefore);
    });

    test('в записи отказа причина, дата из now и номер порции', () {
      final entry =
          _plan([
            _word('adult', reject: 'нет одного главного значения'),
          ]).rejected.single;

      expect(entry.id, 'adult');
      expect(entry.reason, 'нет одного главного значения');
      expect(entry.date, '2026-08-25');
      expect(entry.portion, 7);
    });
  });

  group('сведение', () {
    test('принятые дописаны в порядке порции', () {
      final plan = _plan([
        _word('pear', translation: 'груша'),
        _word('plum', translation: 'слива'),
      ]);

      expect(plan.accepted, ['pear', 'plum']);
      expect(plan.wordsBefore, 2);
      expect(plan.wordsAfter, 4);
      expect(
        plan.seedText.indexOf('"id": "pear"'),
        lessThan(plan.seedText.indexOf('"id": "plum"')),
      );
    });

    test('ни один существующий байт не переписан, кроме одной запятой', () {
      // git diff порции обязан быть «+N строк», а не «файл изменён целиком».
      final plan = _plan([_word('pear', translation: 'груша')]);
      final before = const LineSplitter().convert(_seed);
      final after = const LineSplitter().convert(plan.seedText);
      final last = before.indexWhere((line) => line.contains('"id": "bread"'));

      expect(after, hasLength(before.length + 1));
      expect(after.sublist(0, last), before.sublist(0, last));
      expect(
        after[last],
        '${before[last]},',
        reason: 'бывшей последней записи добавляется только запятая',
      );
      expect(after[last + 1], contains('"id": "pear"'));
      expect(after.sublist(last + 2), before.sublist(last + 1));
    });

    test('файл заканчивается переводом строки, как и заканчивался', () {
      expect(
        _plan([_word('pear', translation: 'груша')]).seedText,
        endsWith('\n'),
      );
    });

    test('рабочие поля порции в сид не уезжают', () {
      final plan = _plan([
        _word('answer', translation: 'ответ', ambiguousPos: ['noun', 'verb']),
        _word('adult', reject: 'причина'),
      ]);

      expect(plan.seedText, isNot(contains('ambiguous_pos')));
      expect(plan.seedText, isNot(contains('reject')));
    });

    test('результат — валидный JSON, проходящий правила сида', () {
      // Обманки нарочно не те же, что у apple: одинаковый набор из четырёх
      // вариантов — отдельное нарушение, и оно проверяется своим тестом.
      final plan = _plan([
        _word(
          'pear',
          translation: 'груша',
          distractors: ['персик', 'слива', 'вишня'],
        ),
      ]);

      final root = jsonDecode(plan.seedText);
      expect(validateSeed(root), isEmpty);
      expect(
        (root as Map<String, Object?>)['words']! as List<Object?>,
        hasLength(3),
      );
    });

    test('перенос строк берётся из файла: CRLF не ломается', () {
      // На Windows рабочая копия приходит с CRLF, и склейка через \\n порвала
      // бы файл в невидимом месте.
      final plan = planMerge(
        seedText: _seed.replaceAll('\n', '\r\n'),
        portionJson: _portion([_word('pear', translation: 'груша')]),
        now: _now,
      );

      expect(plan.seedText, contains('\r\n'));
      expect(plan.seedText.replaceAll('\r\n', '\n'), isNot(contains('\r')));
      expect(validateSeed(jsonDecode(plan.seedText)), isEmpty);
    });

    test('запись сида пишется одной строкой, поля в том же порядке', () {
      // Порядок полей тот же, что в сиде, набранном руками: иначе дописанные
      // строки читались бы как чужие.
      expect(
        encodeSeedWord({
          'id': 'pear',
          'text': 'pear',
          'translation': 'груша',
          'part_of_speech': 'noun',
          'level': 'a1',
          'distractors': ['яблоко', 'слива', 'вишня'],
        }),
        '    { "id": "pear", "text": "pear", "translation": "груша", '
        '"part_of_speech": "noun", "level": "a1", '
        '"distractors": ["яблоко", "слива", "вишня"] }',
      );
    });
  });

  group('дописывание в незнакомый файл', () {
    test('сид без единого слова — падение, а не молчаливая порча', () {
      expect(
        () => appendSeedWords('{ "words": [] }', const ['    { "id": "x" }']),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('отчёт: что будет, если свести', () {
    String report(List<Map<String, Object?>> words, {String seed = _seed}) =>
        dryRunReport(seedText: seed, portionJson: _portion(words), now: _now);

    test('готовая порция: принято, отклонено, каким станет сид', () {
      final text = report([
        _word('pear', translation: 'груша'),
        _word('plum', translation: 'слива'),
        _word('adult', reject: 'нет одного главного значения'),
      ]);

      expect(text, contains('принято 2'));
      expect(text, contains('отклонено 1'));
      expect(text, contains('2 → 4'), reason: 'каким станет сид');
      expect(
        text,
        contains('ничего не записано'),
        reason: 'отчёт обязан сказать, что он только отчёт',
      );
    });

    test('нерешённые ничьи — свой список, с кандидатами', () {
      // Их решает человек, и это не ошибка вычитки, а незакрытый вопрос.
      final text = report([
        _word(
          'answer',
          translation: '',
          partOfSpeech: '',
          ambiguousPos: ['noun', 'verb'],
        ),
        _word('pear', translation: 'груша'),
      ]);

      expect(text, contains('ничь'));
      expect(text, contains('answer'));
      expect(text, contains('noun'));
      expect(text, contains('verb'));
    });

    test('заполненная наполовину запись не путается с ничьёй', () {
      final text = report([
        _word('pear', translation: ''),
        _word('plum', translation: 'слива', distractors: ['один']),
      ]);

      expect(text, contains('pear'));
      expect(text, contains('plum'));
      expect(text, isNot(contains('ничь')), reason: 'ничьих здесь нет');
    });

    test('нарушения правил видны и когда порцию ещё нельзя свести', () {
      // Иначе вычитка узнаёт о столкновении переводов только после того, как
      // человек разберёт все ничьи, — то есть через вечер.
      final text = report([
        _word(
          'answer',
          translation: '',
          partOfSpeech: '',
          ambiguousPos: ['noun', 'verb'],
        ),
        _word('pear', translation: 'яблоко'),
      ]);

      expect(text, contains('answer'));
      expect(text, contains('яблоко'), reason: 'столкновение с apple');
    });

    test('новые зеркальные пары названы, старые не повторяются', () {
      final text = report([
        _word(
          'pear',
          translation: 'груша',
          distractors: ['яблоко', 'персик', 'вишня'],
        ),
      ]);

      // apple → «груша» в обманках, pear → «яблоко»: пара взаимная и новая.
      // Обманки нарочно не совпадают целиком — это было бы другое нарушение.
      expect(text, contains('apple'));
      expect(text, contains('pear'));
      expect(text, contains('зеркал'));
    });
  });
}
