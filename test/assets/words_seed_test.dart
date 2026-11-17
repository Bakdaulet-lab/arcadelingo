// Проверка формы и инвариантов сида слов.
//
// Сами правила живут в `tool/seed_rules.dart` и здесь только применяются к
// живому ассету: второй список правил, набранный отдельно в тесте, разошёлся
// бы с тем, по которому сводятся порции, — и разошёлся бы молча.
//
// Тест на правило — по тесту: «сид сломан» без указания, чем именно, ничего не
// говорит тому, кто вычитывал порцию вечером.
//
// Качество обманок (не синоним, не однокоренное) тест не ловит — это ручная
// вычитка. Соответствие `level` источнику (CEFR-J или Octanove) — тоже. Зелёный прогон
// означает «форма и инварианты в порядке», а не «контент выверен».

import 'dart:convert';
import 'dart:io';

import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/confusables.dart';
import '../../tool/seed_rules.dart';

List<Object?> _wordsOf(Object? document) => switch (document) {
  {'words': final List<Object?> words} => words,
  _ => const [],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Object? combined;
  late List<SeedProblem> problems;
  late List<Object?> words;
  late List<Object?> c1Words;
  late String registeredPairs;

  // rootBundle, а не dart:io: заодно проверяет регистрацию ассета в pubspec.yaml.
  setUpAll(() async {
    final base = jsonDecode(await rootBundle.loadString(wordsSeedAssetPath));
    final c1 = jsonDecode(await rootBundle.loadString(wordsC1AssetPath));
    words = _wordsOf(base);
    c1Words = _wordsOf(c1);
    combined = {
      'version': 1,
      'source_lang': 'en',
      'target_lang': 'ru',
      'words': [...words, ...c1Words],
    };
    problems = [
      ...validateSeed(base),
      ...validateSeed(c1),
      ...validateSeed(combined),
    ];
    final basePairs = File(confusablesPath).readAsStringSync().trimRight();
    final c1Pairs = File('tool/c1/confusables.csv').readAsLinesSync().skip(1);
    registeredPairs = [basePairs, ...c1Pairs].join('\n');
  });

  test('865 карточек в отдельном ассете, все уровня C1', () {
    expect(c1Words, hasLength(865));
    expect(c1Words, everyElement(containsPair('level', 'c1')));
  });

  void ruleTest(String name, SeedRule rule) {
    test(name, () {
      expect(problems.where((problem) => problem.rule == rule), isEmpty);
    });
  }

  ruleTest('корень: version 1, en → ru', SeedRule.document);
  ruleTest('id, text, translation непустые; id == text', SeedRule.identity);
  ruleTest('id и text уникальны', SeedRule.uniqueIds);
  ruleTest('part_of_speech из закрытого набора', SeedRule.partOfSpeech);
  ruleTest('level присутствует и из закрытого набора', SeedRule.level);
  ruleTest(
    'ровно три дистрактора, уникальны, не равны переводу',
    SeedRule.distractors,
  );
  ruleTest(
    'перевод и дистракторы — кириллица, text — латиница',
    SeedRule.script,
  );
  ruleTest(
    'два слова с одним переводом: игрок наказан за верный ответ',
    SeedRule.translationCollision,
  );
  ruleTest(
    'у двух слов совпал весь набор из четырёх вариантов',
    SeedRule.identicalOptions,
  );

  test('ровно 5801 слово: 685 A1, 1017 A2, 1902 B1 и 2197 B2', () {
    // Жёсткость намеренная: правка числа — часть коммита порции, набранная
    // руками. Сведение порции её не автоматизирует и автоматизировать не будет.
    //
    // Счётчиков в репозитории ДВА: этот и «единиц показа» в
    // test/data/words/words_seed_loader_test.dart. Правятся оба и в одном
    // коммите — порция 1 приехала красной ровно потому, что второй забыли.
    expect(words, hasLength(5801));
    final levels = words.whereType<Map<String, Object?>>().map(
      (word) => word['level'],
    );
    expect(levels.where((level) => level == 'a1'), hasLength(685));
    expect(levels.where((level) => level == 'a2'), hasLength(1017));
    expect(levels.where((level) => level == 'b1'), hasLength(1902));
    expect(levels.where((level) => level == 'b2'), hasLength(2197));
  });

  test('каждое слово из файла ловушек есть в сиде', () {
    // Ловит опечатку в id и запись «на будущее»: пара вносится тем же
    // коммитом, что и второе слово пары, — шаг из чеклиста порции.
    expect(checkConfusablesExist(combined, registeredPairs), isEmpty);
  });

  test('каждая зеркальная пара внесена в файл ловушек', () {
    // Сама пара нарушением не является. Нарушение — что о ней некому будет
    // узнать: правило сессии Б1 читает файл, а не отчёт прогона.
    // dart:io, а не rootBundle: файл ловушек не ассет, в приложение не едет.
    expect(checkMirrorPairsListed(combined, registeredPairs), isEmpty);
  });

  test('зеркальные пары известны и не запрещены', () {
    // `open` ↔ `close` в сиде сделаны намеренно. Лечит их правило сессии
    // «не показывать оба слова пары в один день» (Б1), а не запрет в контенте.
    final pairs = findMirrorPairs(combined);

    expect(pairs.map((pair) => pair.toString()), contains('open ↔ close'));
    expect(
      problems,
      isEmpty,
      reason: 'зеркальная пара не имеет права быть нарушением',
    );
  });
}
