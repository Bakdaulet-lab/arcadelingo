/// Импортёр CEFR-J A1/A2 → рабочие порции по 50 слов для ручной вычитки.
///
/// ИНВАРИАНТ ПАЙПЛАЙНА: этот файл никогда не пишет в `assets/`. Туда попадает
/// только вычитанное — переводом и обманками занимается человек, а сводит их
/// в ассет отдельный инструмент. Инвариант не только записан здесь словами,
/// но и сторожится [assertOutDirAllowed].
///
/// Запуск:
///
///     dart run tool/import_cefrj.dart <cefrj-vocabulary-profile-1.5.csv>
///         [--out tool/out] [--seed assets/words_seed.json]
///         [--rejected tool/out/rejected.json]
///
/// Сам CSV в репозитории не лежит: он не наш, а условия CEFR-J требуют
/// цитирования, а не перепубликации. Откуда его взять и на каких условиях —
/// `docs/dev/content_sources.md`, цитата — `assets/ATTRIBUTION.md`.
///
/// Что делает и чего не делает:
///
/// * берёт строки уровней A1 и A2 и только четыре части речи, с которыми
///   умеет работать игра;
/// * схлопывает многозначный headword по минимальному уровню — но **только
///   уровень**. Если на минимальном уровне у слова больше одной части речи
///   (`answer` — noun и verb, оба A1), импортёр не выбирает: часть речи
///   остаётся пустой, слово уходит в порцию как есть и попадает в
///   `ambiguous.csv`. Фиксированный приоритет частей речи молча превратил бы
///   «отвечать» в «ответ»;
/// * ничего не отсеивает молча: всё, что отброшено после фильтра по уровню,
///   лежит в `skipped.csv` с причиной, а воронка печатается в конце прогона.
///   Единственное исключение — сами уровни B1/B2: это скоуп задачи, и 5224
///   строки в `skipped.csv` похоронили бы в нём сигнал;
/// * порядок порций: сначала весь A1, потом весь A2; внутри уровня —
///   перемешивание с фиксированным seed. Алфавит собрал бы однокоренные слова
///   в одну порцию, а это ровно то, что запрещено обманкам.
library;

import 'dart:convert';
import 'dart:io';

import 'rejected.dart';

/// Размер порции. Одна порция = один вечер вычитки = один коммит.
const int defaultPortionSize = 50;

/// Seed перемешивания. Число произвольное, но зафиксированное: два человека,
/// запустившие импортёр на одном CSV, обязаны получить одинаковые порции.
const int defaultShuffleSeed = 20260824;

/// Уровни, которые импортируем, в порядке ввода: сначала весь A1, потом A2.
const List<String> importedLevels = ['a1', 'a2'];

/// Все уровни, которые может содержать источник. Значение вне набора — не
/// «пропустить», а падение: источник обновился, и решать это человеку.
const Set<String> knownLevels = {'A1', 'A2', 'B1', 'B2'};

/// Части речи источника → наши. Остальные известные части речи игра не
/// показывает: у местоимений и предлогов нет перевода, годного в кнопку.
const Map<String, String> partOfSpeechMap = {
  'noun': 'noun',
  'verb': 'verb',
  'adjective': 'adj',
  'adverb': 'adv',
};

/// Все части речи, встречающиеся в CEFR-J Wordlist 1.5. Как и [knownLevels] —
/// сторож на случай обновления источника, а не список к фильтрации.
const Set<String> knownPartsOfSpeech = {
  'noun',
  'verb',
  'adjective',
  'adverb',
  'pronoun',
  'preposition',
  'determiner',
  'conjunction',
  'number',
  'modal auxiliary',
  'be-verb',
  'do-verb',
  'have-verb',
  'interjection',
  'infinitive-to',
};

/// Причина, по которой строка не дошла до порции.
enum SkipReason {
  /// Часть речи известна источнику, но игре с ней делать нечего.
  partOfSpeechOutOfScope('часть речи вне набора'),

  /// `bus stop`, `April`, `T-shirt`, `airplane/aeroplane`. Не мусор, а живая
  /// лексика A1/A2, которую отсекает наш собственный инвариант `id == text`
  /// и «одно слово из строчных латинских букв».
  headwordNotSingleLowercaseWord('headword не одно слово из строчных букв');

  const SkipReason(this.text);

  final String text;
}

/// Слово, дошедшее до порции. Перевод и обманки не заполняет никто, кроме
/// человека, — их здесь нет вовсе.
class ImportedWord {
  const ImportedWord({
    required this.text,
    required this.level,
    required this.partOfSpeech,
    this.ambiguousPartsOfSpeech = const [],
  });

  /// Оно же `id`: инвариант сида — `id == text` в нижнем регистре.
  final String text;

  /// `a1` или `a2`, нижним регистром — как в сиде.
  final String level;

  /// `null` — ничья на минимальном уровне, часть речи выбирает человек.
  final String? partOfSpeech;

  /// Кандидаты при ничьей, по алфавиту. Пусто, если часть речи однозначна.
  final List<String> ambiguousPartsOfSpeech;

  /// Часть речи не выбрана импортёром намеренно.
  bool get isAmbiguous => partOfSpeech == null;
}

/// Порция: файл `portion_NN.json`, один уровень, до [defaultPortionSize] слов.
class Portion {
  const Portion({
    required this.number,
    required this.level,
    required this.words,
  });

  final int number;
  final String level;
  final List<ImportedWord> words;
}

/// Строка источника, не дошедшая до порции, с причиной.
class SkippedRow {
  const SkippedRow({
    required this.headword,
    required this.partOfSpeech,
    required this.level,
    required this.reason,
  });

  final String headword;
  final String partOfSpeech;
  final String level;
  final SkipReason reason;
}

/// Headword, у которого на минимальном уровне больше одной части речи.
class AmbiguousWord {
  const AmbiguousWord({
    required this.headword,
    required this.level,
    required this.variants,
  });

  final String headword;
  final String level;

  /// Все варианты источника, вида `noun A1`, по алфавиту.
  final List<String> variants;
}

/// Сколько строк пережило каждый шаг. Печатается в конце прогона: «отсеяли N»
/// без числа — это и есть молчаливый отсев.
class ImportFunnel {
  const ImportFunnel({
    required this.rows,
    required this.byLevel,
    required this.byPartOfSpeech,
    required this.byHeadwordShape,
    required this.headwords,
    required this.afterDedup,
    required this.ambiguous,
  });

  final int rows;
  final int byLevel;
  final int byPartOfSpeech;
  final int byHeadwordShape;
  final int headwords;
  final int afterDedup;
  final int ambiguous;
}

/// Всё, что импортёр узнал из CSV. Ни одного касания диска: писать файлы —
/// дело [main], и только под каталог вывода.
class ImportResult {
  const ImportResult({
    required this.portions,
    required this.ambiguous,
    required this.skipped,
    required this.funnel,
  });

  final List<Portion> portions;
  final List<AmbiguousWord> ambiguous;
  final List<SkippedRow> skipped;
  final ImportFunnel funnel;
}

/// CSV источника → порции, ничьи, отсев и воронка.
///
/// [excludedIds] — то, что уже есть в сиде: импортёр не должен предлагать
/// вычитывать слово дважды. Когда появится инструмент сведения порций, сюда
/// же добавятся id, отклонённые при вычитке.
///
/// Бросает [FormatException] с номером строки, если источник изменил форму:
/// неизвестный уровень, неизвестная часть речи, обрезанная строка. Тихо
/// пропустить такую строку значило бы потерять слова при обновлении CEFR-J.
ImportResult importCefrj(
  String csv, {
  required Set<String> excludedIds,
  int portionSize = defaultPortionSize,
  int shuffleSeed = defaultShuffleSeed,
}) {
  final rows = _parseRows(csv);
  final skipped = <SkippedRow>[];

  // Шаг 1: уровень. Единственный фильтр, который не пишет в отсев: B1/B2 —
  // это скоуп задачи, а не потеря, и 5224 строки утопили бы в отсеве сигнал.
  final byLevel = [
    for (final row in rows)
      if (importedLevels.contains(row.level.toLowerCase())) row,
  ];

  // Шаг 2: часть речи.
  final byPartOfSpeech = <_Row>[];
  for (final row in byLevel) {
    if (partOfSpeechMap.containsKey(row.partOfSpeech)) {
      byPartOfSpeech.add(row);
    } else {
      skipped.add(row.skip(SkipReason.partOfSpeechOutOfScope));
    }
  }

  // Шаг 3: форма headword. Отсекает наш собственный инвариант `id == text`.
  final byShape = <_Row>[];
  for (final row in byPartOfSpeech) {
    if (_singleLowercaseWord.hasMatch(row.headword)) {
      byShape.add(row);
    } else {
      skipped.add(row.skip(SkipReason.headwordNotSingleLowercaseWord));
    }
  }

  // Шаг 4: группировка по слову, в порядке первого появления — прогон должен
  // быть воспроизводим и до перемешивания.
  final groups = <String, List<_Row>>{};
  for (final row in byShape) {
    (groups[row.headword] ??= <_Row>[]).add(row);
  }
  final headwords = groups.length;

  // Шаг 5: дедуп против сида — по слову, а не по строке: если слово уже наше,
  // уходят разом все его части речи, и ничьёй оно тоже не считается.
  groups.removeWhere((headword, _) => excludedIds.contains(headword));

  // Шаг 6: схлопывание. По минимальному уровню — и только по уровню.
  final words = <ImportedWord>[];
  final ambiguous = <AmbiguousWord>[];
  for (final entry in groups.entries) {
    final level = entry.value
        .map((row) => row.level.toLowerCase())
        .reduce(_lowerLevel);
    final candidates =
        <String>{
            for (final row in entry.value)
              if (row.level.toLowerCase() == level)
                partOfSpeechMap[row.partOfSpeech]!,
          }.toList()
          ..sort();

    if (candidates.length == 1) {
      words.add(
        ImportedWord(
          text: entry.key,
          level: level,
          partOfSpeech: candidates.single,
        ),
      );
      continue;
    }
    // Ничья. Часть речи не выбирается здесь ни при каких условиях: приоритет
    // молча превратил бы «отвечать» в «ответ».
    words.add(
      ImportedWord(
        text: entry.key,
        level: level,
        partOfSpeech: null,
        ambiguousPartsOfSpeech: candidates,
      ),
    );
    ambiguous.add(
      AmbiguousWord(
        headword: entry.key,
        level: level,
        // Все варианты источника, включая другие уровни: человек решает,
        // глядя на слово целиком, а не на срез минимального уровня.
        variants:
            <String>{
                for (final row in entry.value)
                  '${row.partOfSpeech} ${row.level}',
              }.toList()
              ..sort(),
      ),
    );
  }

  return ImportResult(
    portions: _splitIntoPortions(words, portionSize, shuffleSeed),
    ambiguous: ambiguous,
    skipped: skipped,
    funnel: ImportFunnel(
      rows: rows.length,
      byLevel: byLevel.length,
      byPartOfSpeech: byPartOfSpeech.length,
      byHeadwordShape: byShape.length,
      headwords: headwords,
      afterDedup: groups.length,
      ambiguous: ambiguous.length,
    ),
  );
}

/// Строка источника: нужны только первые три колонки.
class _Row {
  const _Row(this.headword, this.partOfSpeech, this.level);

  final String headword;
  final String partOfSpeech;
  final String level;

  SkippedRow skip(SkipReason reason) => SkippedRow(
    headword: headword,
    partOfSpeech: partOfSpeech,
    level: level,
    reason: reason,
  );
}

/// Инвариант сида: `id == text`, одно слово из строчных латинских букв.
final RegExp _singleLowercaseWord = RegExp(r'^[a-z]+$');

/// CSV → строки. Первая строка — шапка. Разбор `split(',')`, а не CSV-пакетом:
/// в CEFR-J 1.5 кавычки есть в 699 строках, но ни разу в первых трёх колонках
/// (проверено 2026-08-24), а новая зависимость требует согласования.
List<_Row> _parseRows(String csv) {
  final lines = const LineSplitter().convert(csv);
  final rows = <_Row>[];
  for (var index = 1; index < lines.length; index++) {
    final line = lines[index];
    if (line.trim().isEmpty) continue;
    // Нумерация человеческая: шапка — строка 1, чтобы номер из сообщения
    // можно было набрать в редакторе и попасть в ту же строку.
    final number = index + 1;
    final fields = line.split(',');
    if (fields.length < 3) {
      throw FormatException(
        'CEFR-J: строка $number: меньше трёх колонок: "$line"',
      );
    }
    final headword = fields[0].trim();
    final partOfSpeech = fields[1].trim();
    final level = fields[2].trim();
    if (headword.isEmpty) {
      throw FormatException('CEFR-J: строка $number: пустой headword');
    }
    // Оба сторожа стоят до фильтров и работают на всех строках, включая
    // B1/B2: иначе обновление источника заметили бы только на апгрейде.
    if (!knownPartsOfSpeech.contains(partOfSpeech)) {
      throw FormatException(
        'CEFR-J: строка $number: неизвестная часть речи "$partOfSpeech". '
        'Источник изменился — решай, что с ней делать, а не пропускай',
      );
    }
    if (!knownLevels.contains(level)) {
      throw FormatException(
        'CEFR-J: строка $number: неизвестный уровень "$level". '
        'Источник изменился — решай, что с ним делать, а не пропускай',
      );
    }
    rows.add(_Row(headword, partOfSpeech, level));
  }
  return rows;
}

/// Меньший из двух уровней по порядку ввода.
String _lowerLevel(String a, String b) =>
    importedLevels.indexOf(a) <= importedLevels.indexOf(b) ? a : b;

/// Слова → порции: сначала весь A1, потом весь A2, внутри уровня —
/// перемешивание. Граничная порция уровня короткая, а не смешанная: иначе
/// «сначала весь A1» переставало бы быть правдой ровно на одной порции.
List<Portion> _splitIntoPortions(
  List<ImportedWord> words,
  int portionSize,
  int shuffleSeed,
) {
  if (portionSize < 1) {
    throw ArgumentError.value(portionSize, 'portionSize', 'должен быть ≥ 1');
  }
  final portions = <Portion>[];
  var number = 1;
  for (final level in importedLevels) {
    final ofLevel = [
      for (final word in words)
        if (word.level == level) word,
    ];
    _shuffleInPlace(ofLevel, shuffleSeed);
    for (var start = 0; start < ofLevel.length; start += portionSize) {
      final end = start + portionSize;
      portions.add(
        Portion(
          number: number++,
          level: level,
          words: ofLevel.sublist(
            start,
            end > ofLevel.length ? ofLevel.length : end,
          ),
        ),
      );
    }
  }
  return portions;
}

/// Фишер—Йетс на собственном линейном конгруэнтном генераторе.
///
/// Не `Random(seed)` из `dart:math`: его последовательность документирована
/// как implementation-specific, а порции обязаны совпасть у двух человек на
/// разных версиях SDK. Качество случайности здесь ни на что не влияет: важно
/// только, чтобы порядок не был алфавитным и был воспроизводимым.
void _shuffleInPlace(List<ImportedWord> words, int seed) {
  var state = (seed & 0x7fffffff) | 1;
  int next(int bound) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    return state % bound;
  }

  for (var i = words.length - 1; i > 0; i--) {
    final j = next(i + 1);
    final swapped = words[i];
    words[i] = words[j];
    words[j] = swapped;
  }
}

/// Что человеку делать с этим файлом. Лежит внутри порции, потому что
/// открывают её, а не документацию.
const String _portionNote =
    'Заполни translation и три distractors. Где part_of_speech пуст — выбери '
    'из ambiguous_pos. Отказ от слова — поле "reject" с причиной.';

/// Порция → текст файла `portion_NN.json`: те же имена полей, что в сиде,
/// плюс пустые `translation` и `distractors` под руку человека.
String encodePortion(Portion portion) {
  final buffer =
      StringBuffer()
        ..writeln('{')
        ..writeln('  "portion": ${portion.number},')
        ..writeln('  "level": ${jsonEncode(portion.level)},')
        ..writeln('  "source": "CEFR-J Wordlist 1.5",')
        ..writeln('  "note": ${jsonEncode(_portionNote)},')
        ..writeln('  "words": [');
  for (var i = 0; i < portion.words.length; i++) {
    final word = portion.words[i];
    // Одна запись — одна строка: порцию заполняют руками, и перевод набирают
    // рядом со словом, а не через пять строк от него.
    final fields = <String>[
      '"id": ${jsonEncode(word.text)}',
      '"text": ${jsonEncode(word.text)}',
      '"translation": ""',
      '"part_of_speech": ${jsonEncode(word.partOfSpeech ?? '')}',
      '"level": ${jsonEncode(word.level)}',
      if (word.isAmbiguous)
        '"ambiguous_pos": ${jsonEncode(word.ambiguousPartsOfSpeech)}',
      '"distractors": []',
    ];
    final comma = i == portion.words.length - 1 ? '' : ',';
    buffer.writeln('    { ${fields.join(', ')} }$comma');
  }
  return (buffer
        ..writeln('  ]')
        ..writeln('}'))
      .toString();
}

/// Ничьи → CSV. Пустой список даёт файл с одной шапкой, а не отсутствие
/// файла: «ничьих нет» и «импортёр про них забыл» обязаны отличаться.
String encodeAmbiguousCsv(List<AmbiguousWord> words) {
  final buffer = StringBuffer()..writeln('headword,level,variants');
  for (final word in words) {
    // Варианты через «;» — запятая развалила бы колонки.
    buffer.writeln(
      '${_cell(word.headword)},${_cell(word.level)},'
      '${_cell(word.variants.join('; '))}',
    );
  }
  return buffer.toString();
}

/// Отсев → CSV, с причиной строкой.
String encodeSkippedCsv(List<SkippedRow> rows) {
  final buffer = StringBuffer()..writeln('headword,pos,CEFR,причина');
  for (final row in rows) {
    buffer.writeln(
      '${_cell(row.headword)},${_cell(row.partOfSpeech)},'
      '${_cell(row.level)},${_cell(row.reason.text)}',
    );
  }
  return buffer.toString();
}

/// Ячейка CSV. В первых трёх колонках источника запятых нет, но отсев печатает
/// данные источника как есть, и полагаться на это не стоит.
String _cell(String value) =>
    value.contains(',') || value.contains('"')
        ? '"${value.replaceAll('"', '""')}"'
        : value;

/// Воронка → человекочитаемый отчёт для stdout.
String formatFunnel(ImportFunnel funnel) => [
  'строк в источнике:            ${funnel.rows}',
  'уровни A1 и A2:               ${funnel.byLevel}',
  'четыре части речи:            ${funnel.byPartOfSpeech}',
  'headword одним словом:        ${funnel.byHeadwordShape}',
  'уникальных слов:              ${funnel.headwords}',
  'после дедупа против сида:     ${funnel.afterDedup}',
  'из них ничьих по части речи:  ${funnel.ambiguous}',
].join('\n');

/// Страж инварианта: писать под `assets/` импортёру запрещено.
///
/// Проверка не про безопасность, а про дисциплину пайплайна: `--out assets`
/// набирается опечаткой, а перезаписанный сид уносит с собой вычитанные
/// переводы, которых в CSV нет и не будет.
void assertOutDirAllowed(String path) {
  final segments = path
      .replaceAll(r'\', '/')
      .split('/')
      .where((segment) => segment.isNotEmpty && segment != '.');
  if (segments.contains('assets')) {
    throw ArgumentError.value(
      path,
      'out',
      'импортёр в assets/ не пишет: туда попадает только вычитанное',
    );
  }
}

const String _usage =
    'Импорт CEFR-J A1/A2 в рабочие порции.\n'
    '\n'
    '  dart run tool/import_cefrj.dart <cefrj-vocabulary-profile-1.5.csv> '
    '[--out tool/out] [--seed assets/words_seed.json] '
    '[--rejected tool/out/rejected.json]\n'
    '\n'
    'CSV в репозитории нет намеренно: см. docs/dev/content_sources.md';

/// Читает CSV и сид, пишет порции, `ambiguous.csv` и `skipped.csv`, печатает
/// воронку. Единственное место в файле, которое трогает диск.
void main(List<String> args) {
  final positional = <String>[];
  var outDir = 'tool/out';
  var seedPath = 'assets/words_seed.json';

  String? rejectedPath;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg != '--out' && arg != '--seed' && arg != '--rejected') {
      positional.add(arg);
      continue;
    }
    if (i + 1 >= args.length) {
      _fail('$arg без значения');
      return;
    }
    final value = args[++i];
    switch (arg) {
      case '--out':
        outDir = value;
      case '--seed':
        seedPath = value;
      default:
        rejectedPath = value;
    }
  }
  if (positional.length != 1) {
    _fail('нужен ровно один путь к CSV, получено ${positional.length}');
    return;
  }

  assertOutDirAllowed(outDir);
  // Отказы исключаются наравне с сидом. Файла может не быть — это первый
  // прогон, а не ошибка; битый файл роняет прогон в excludedFrom.
  final rejectedFile = File(rejectedPath ?? '$outDir/rejected.json');
  final fromSeed = excludedFrom(seedJson: File(seedPath).readAsStringSync());
  final fromRejected = excludedFrom(
    rejectedJson:
        rejectedFile.existsSync() ? rejectedFile.readAsStringSync() : null,
  );
  final result = importCefrj(
    File(positional.single).readAsStringSync(),
    excludedIds: {...fromSeed, ...fromRejected},
  );

  final directory = Directory(outDir)..createSync(recursive: true);
  for (final portion in result.portions) {
    final name = 'portion_${portion.number.toString().padLeft(2, '0')}.json';
    File('${directory.path}/$name').writeAsStringSync(encodePortion(portion));
  }
  File(
    '${directory.path}/ambiguous.csv',
  ).writeAsStringSync(encodeAmbiguousCsv(result.ambiguous));
  File(
    '${directory.path}/skipped.csv',
  ).writeAsStringSync(encodeSkippedCsv(result.skipped));

  stdout
    ..writeln(formatFunnel(result.funnel))
    ..writeln('')
    ..writeln('порций: ${result.portions.length} → ${directory.path}')
    ..writeln('ничьих: ${result.ambiguous.length} → ambiguous.csv')
    ..writeln('отсев:  ${result.skipped.length} → skipped.csv')
    ..writeln(
      'исключено заранее: сид ${fromSeed.length}, '
      'отказы ${fromRejected.length}',
    );
}

void _fail(String message) {
  stderr
    ..writeln('import_cefrj: $message')
    ..writeln('')
    ..writeln(_usage);
  exitCode = 64;
}

/// Что импортёр не имеет права предложить заново: слова, уже лежащие в сиде,
/// и слова, отклонённые при вычитке. Отказы исключаются ровно так же, как сид, —
/// иначе выброшенное на порции 3 слово вернулось бы в порцию 30.
///
/// Оба источника необязательны: на первом прогоне нет файла отказов, а сид
/// теоретически может быть пуст. Битые — [FormatException], не пустое множество:
/// молчаливое «отказов нет» стоило бы вечера повторной вычитки.
Set<String> excludedFrom({String? seedJson, String? rejectedJson}) => {
  if (seedJson != null) ..._seedIds(seedJson),
  ...rejectedIds(rejectedJson),
};

/// id слов, которые уже в сиде. Нужны только они: остальное — дело вычитки.
Set<String> _seedIds(String json) {
  final root = jsonDecode(json);
  if (root is! Map<String, Object?>) {
    throw const FormatException('сид слов: корень не объект');
  }
  final words = root['words'];
  if (words is! List<Object?>) {
    throw const FormatException('сид слов: нет списка words');
  }
  final ids = <String>{};
  for (final word in words) {
    if (word is! Map<String, Object?>) {
      throw const FormatException('сид слов: запись не объект');
    }
    final id = word['id'];
    if (id is! String) {
      throw const FormatException('сид слов: id не строка');
    }
    ids.add(id);
  }
  return ids;
}
