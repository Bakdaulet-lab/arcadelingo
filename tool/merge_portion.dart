/// Сведение вычитанной порции в `assets/words_seed.json`.
///
/// Это единственный инструмент, которому вообще позволено писать в `assets/`, —
/// и позволено ровно потому, что он ничего не сочиняет: он берёт то, что
/// человек уже вычитал, и отказывается брать всё остальное.
///
/// Запуск:
///
///     dart run tool/merge_portion.dart <NN | путь к portion_NN.json>
///         [--seed assets/words_seed.json] [--out tool/out]
///
/// Что делает:
///
/// 1. делит записи порции на принятые и отклонённые (поле `reject`);
/// 2. **жёстко падает**, если принятая запись заполнена наполовину: пустая
///    часть речи (нерешённая ничья импортёра), пустой перевод, число обманок
///    не равно трём. Падает со списком всех таких записей сразу и не пишет
///    ничего: полузаполненное не проходит молча никогда;
/// 3. дописывает принятое в конец сида — **только дописывает**. Ни один
///    существующий байт не переписывается, кроме запятой в конце бывшей
///    последней записи, поэтому `git diff` порции — ровно `+50` строк, а не
///    «файл изменён целиком»;
/// 4. проверяет получившийся документ правилами `tool/seed_rules.dart` **до**
///    записи на диск. Не прошло — на диске ничего не поменялось;
/// 5. дописывает отклонённое в `tool/out/rejected.json` с причиной и датой,
///    откуда импортёр исключит эти слова из будущих порций;
/// 6. прогоняет валидатор по уже записанному файлу и `flutter test test/assets`.
///
/// Чего НЕ делает: не правит `hasLength(N)` в `test/assets/words_seed_test.dart`.
/// Это число — осознанное «я добавил столько-то слов», и оно остаётся частью
/// коммита порции, набранной руками. Инструмент только печатает, какое именно
/// число теперь верное. Поэтому сразу после сведения `flutter test test/assets`
/// красный, и это не поломка, а незакрытый пункт: код выхода честно говорит,
/// что репозиторий ещё не согласован.
library;

import 'dart:convert';
import 'dart:io';

import 'rejected.dart';
import 'seed_rules.dart';

/// Что получится, если свести порцию. Ни одного касания диска: решение о
/// записи принимает [main], и только когда план построен целиком.
class MergePlan {
  const MergePlan({
    required this.seedText,
    required this.accepted,
    required this.rejected,
    required this.wordsBefore,
    required this.wordsAfter,
    required this.portion,
  });

  /// Новый текст ассета: старый плюс дописанные строки.
  final String seedText;

  /// id принятых слов, в порядке порции.
  final List<String> accepted;

  /// Отклонённое — уже в виде записей файла отказов.
  final List<RejectedEntry> rejected;

  final int wordsBefore;
  final int wordsAfter;

  /// Номер порции из самого файла порции.
  final int portion;
}

/// Порция плюс текущий сид → план сведения.
///
/// [now] приходит параметром: дата отказа обязана быть воспроизводимой в тесте.
///
/// Бросает [FormatException] на всём, что нельзя свести молча: полузаполненная
/// принятая запись, отказ без причины, слово, уже лежащее в сиде, нарушение
/// правил `seed_rules.dart` в получившемся документе.
MergePlan planMerge({
  required String seedText,
  required String portionJson,
  required DateTime now,
}) {
  final seedRoot = _decode(seedText, 'сид');
  final seedWords = _wordsOf(seedRoot, 'сид');
  final seedIds = <String>{
    for (final word in seedWords)
      if (word is Map<String, Object?> && word['id'] is String)
        word['id']! as String,
  };

  final portionRoot = _decode(portionJson, 'порция');
  if (portionRoot is! Map<String, Object?>) {
    throw const FormatException('порция: корень не объект');
  }
  final portion = portionRoot['portion'];
  if (portion is! int) {
    throw const FormatException(
      'порция: поле portion отсутствует или не число',
    );
  }
  final portionWords = _wordsOf(portionRoot, 'порция');

  final problems = <String>[];
  final accepted = <Map<String, Object?>>[];
  final rejected = <RejectedEntry>[];
  final date = formatRejectedDate(now);

  for (final (index, raw) in portionWords.indexed) {
    if (raw is! Map<String, Object?>) {
      problems.add('запись #$index не объект');
      continue;
    }
    final id = raw['id'];
    final name = id is String && id.isNotEmpty ? id : 'запись #$index';

    // Отказ разбирается первым: отклонённое слово не обязано быть вычитано,
    // требовать от него перевод бессмысленно.
    if (raw.containsKey('reject')) {
      final reason = raw['reject'];
      if (id is! String || id.isEmpty) {
        problems.add('$name: reject без id');
        continue;
      }
      if (reason is! String || reason.trim().isEmpty) {
        problems.add(
          '$name: reject без причины — причина и есть всё, ради чего файл '
          'отказов существует',
        );
        continue;
      }
      rejected.add(
        RejectedEntry(
          id: id,
          reason: reason.trim(),
          date: date,
          portion: portion,
        ),
      );
      continue;
    }

    // Три стража заполненности. Проверяются все сразу: править вычитку по
    // одной записи за прогон — потерянный вечер.
    var usable = true;
    if (id is! String || id.isEmpty) {
      problems.add('запись #$index: нет id');
      usable = false;
    } else if (seedIds.contains(id)) {
      problems.add('$name: слово уже есть в сиде — порция сведена повторно?');
      usable = false;
    }
    final translation = raw['translation'];
    if (translation is! String || translation.trim().isEmpty) {
      problems.add('$name: пустой translation — запись не вычитана');
      usable = false;
    }
    final partOfSpeech = raw['part_of_speech'];
    if (partOfSpeech is! String || partOfSpeech.trim().isEmpty) {
      problems.add(
        '$name: пустой part_of_speech — нерешённая ничья, часть речи '
        'выбирает человек, а не инструмент',
      );
      usable = false;
    }
    final rawDistractors = raw['distractors'];
    if (rawDistractors is! List<Object?> ||
        rawDistractors.any((value) => value is! String)) {
      problems.add('$name: distractors отсутствует или содержит не строку');
      usable = false;
    } else if (rawDistractors.length != seedDistractorCount) {
      problems.add(
        '$name: distractors ${rawDistractors.length} штук вместо '
        '$seedDistractorCount',
      );
      usable = false;
    }
    if (!usable) continue;

    // Рабочие поля порции (`ambiguous_pos`, `reject`) в ассет не уезжают:
    // запись собирается заново, поле за полем, в порядке сида.
    accepted.add({
      'id': id,
      'text': raw['text'],
      'translation': (translation! as String).trim(),
      'part_of_speech': (partOfSpeech! as String).trim(),
      'level': raw['level'],
      'distractors': [
        for (final value in rawDistractors! as List<Object?>)
          (value! as String).trim(),
      ],
    });
  }

  if (problems.isNotEmpty) {
    throw FormatException(
      'порция $portion: ${problems.length} записей нельзя свести:\n'
      '- ${problems.join("\n- ")}',
    );
  }

  final merged =
      accepted.isEmpty
          ? seedText
          : appendSeedWords(seedText, [
            for (final word in accepted) encodeSeedWord(word),
          ]);

  // Правила проверяются до записи: не прошло — на диске ничего не поменялось.
  final mergedRoot = _decode(merged, 'сид после сведения');
  final ruleProblems = validateSeed(mergedRoot);
  if (ruleProblems.isNotEmpty) {
    throw FormatException(
      'порция $portion: результат нарушает правила сида:\n'
      '- ${ruleProblems.join("\n- ")}',
    );
  }

  return MergePlan(
    seedText: merged,
    accepted: [for (final word in accepted) word['id']! as String],
    rejected: rejected,
    wordsBefore: seedWords.length,
    wordsAfter: _wordsOf(mergedRoot, 'сид после сведения').length,
    portion: portion,
  );
}

/// Что будет, если свести порцию, — текстом и без единой записи на диск.
///
/// Режим отчёта нужен до вычитки, а не после: вычитывающий обязан видеть
/// нерешённые ничьи (их решает он), заполненное наполовину (это его ошибка) и
/// нарушения правил — три разных списка, а не одно «свести нельзя».
///
/// Нарушения правил считаются по тем записям, которые уже готовы, даже когда
/// порцию целиком свести ещё нельзя: иначе про столкновение переводов человек
/// узнал бы только после того, как разберёт все ничьи, то есть через вечер.
String dryRunReport({
  required String seedText,
  required String portionJson,
  required DateTime now,
}) {
  throw UnimplementedError();
}

/// Запись сида → одна строка файла, как их пишут руками.
String encodeSeedWord(Map<String, Object?> word) {
  final distractors = word['distractors'];
  final options =
      distractors is List<Object?>
          ? '[${distractors.map(jsonEncode).join(", ")}]'
          : jsonEncode(distractors);
  final fields = <String>[
    '"id": ${jsonEncode(word['id'])}',
    '"text": ${jsonEncode(word['text'])}',
    '"translation": ${jsonEncode(word['translation'])}',
    '"part_of_speech": ${jsonEncode(word['part_of_speech'])}',
    '"level": ${jsonEncode(word['level'])}',
    '"distractors": $options',
  ];
  return '    { ${fields.join(', ')} }';
}

/// Дописать строки в массив `words`, не тронув ни одного существующего байта,
/// кроме запятой в конце бывшей последней записи.
///
/// Перенос строк берётся из самого файла: на Windows рабочая копия приходит с
/// `CRLF`, и склейка через `\n` порвала бы файл в невидимом месте.
String appendSeedWords(String seedText, List<String> lines) {
  if (lines.isEmpty) return seedText;
  final eol = seedText.contains('\r\n') ? '\r\n' : '\n';
  final endsWithNewline = seedText.endsWith('\n');
  final source = const LineSplitter().convert(seedText);

  var close = -1;
  for (var i = source.length - 1; i >= 0; i--) {
    if (source[i].trim() == ']') {
      close = i;
      break;
    }
  }
  if (close < 0) {
    throw const FormatException(
      'сид: не найдено закрытие массива words отдельной строкой — '
      'дописывать вслепую нельзя',
    );
  }
  var last = -1;
  for (var i = close - 1; i >= 0; i--) {
    if (source[i].trim().isEmpty) continue;
    last = i;
    break;
  }
  if (last < 0 || !source[last].contains('"id"')) {
    throw const FormatException(
      'сид: перед закрытием массива нет записи слова — дописывать не к чему',
    );
  }

  final result = [...source];
  result[last] = '${result[last]},';
  // Запятая после каждой дописанной записи, кроме последней: массив закрывается
  // сразу за ней, и висящая запятая сделала бы файл невалидным JSON.
  result.insertAll(last + 1, [
    for (final (index, line) in lines.indexed)
      index == lines.length - 1 ? line : '$line,',
  ]);
  return result.join(eol) + (endsWithNewline ? eol : '');
}

Object? _decode(String json, String what) {
  try {
    return jsonDecode(json);
  } on FormatException catch (e) {
    throw FormatException('$what: невалидный JSON: ${e.message}');
  }
}

List<Object?> _wordsOf(Object? root, String what) {
  if (root is! Map<String, Object?>) {
    throw FormatException('$what: корень не объект');
  }
  final words = root['words'];
  if (words is! List<Object?>) {
    throw FormatException('$what: поле words отсутствует или не список');
  }
  return words;
}

const String _usage =
    'Сведение вычитанной порции в assets/words_seed.json.\n'
    '\n'
    '  dart run tool/merge_portion.dart <NN | путь к portion_NN.json> '
    '[--seed assets/words_seed.json] [--out tool/out]';

void main(List<String> args) {
  final positional = <String>[];
  var seedPath = 'assets/words_seed.json';
  var outDir = 'tool/out';

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg != '--seed' && arg != '--out') {
      positional.add(arg);
      continue;
    }
    if (i + 1 >= args.length) {
      _fail('$arg без значения');
      return;
    }
    if (arg == '--seed') {
      seedPath = args[++i];
    } else {
      outDir = args[++i];
    }
  }
  if (positional.length != 1) {
    _fail('нужен ровно один аргумент: номер порции или путь к файлу');
    return;
  }

  final number = int.tryParse(positional.single);
  final portionPath =
      number == null
          ? positional.single
          : '$outDir/portion_${number.toString().padLeft(2, '0')}.json';
  final portionFile = File(portionPath);
  if (!portionFile.existsSync()) {
    _fail('порция не найдена: $portionPath');
    return;
  }

  final seedFile = File(seedPath);
  final plan = planMerge(
    seedText: seedFile.readAsStringSync(),
    portionJson: portionFile.readAsStringSync(),
    now: DateTime.now(),
  );

  seedFile.writeAsStringSync(plan.seedText);
  stdout.writeln(
    'принято: ${plan.accepted.length} → $seedPath '
    '(${plan.wordsBefore} → ${plan.wordsAfter} слов)',
  );

  if (plan.rejected.isNotEmpty) {
    final rejectedFile = File('$outDir/rejected.json');
    final existing =
        rejectedFile.existsSync() ? rejectedFile.readAsStringSync() : null;
    final all = withRejected(parseRejected(existing), plan.rejected);
    rejectedFile.writeAsStringSync(encodeRejected(all));
    stdout.writeln(
      'отклонено: ${plan.rejected.length} → ${rejectedFile.path} '
      '(всего ${all.length})',
    );
  }

  // Валидатор — уже по записанному файлу, а не по построенному в памяти.
  stdout.writeln('\n=== валидатор ===');
  final writtenRoot = jsonDecode(seedFile.readAsStringSync());
  final problems = validateSeed(writtenRoot);
  if (problems.isEmpty) {
    stdout.writeln('нарушений нет');
  } else {
    for (final problem in problems) {
      stdout.writeln('- $problem');
    }
  }
  final pairs = findMirrorPairs(writtenRoot);
  stdout.writeln(
    'зеркальных пар: ${pairs.length}'
    '${pairs.isEmpty ? '' : ' (${pairs.join(', ')})'} — не нарушение, '
    'лечится правилом сессии Б1',
  );

  stdout.writeln(
    '\nОсталось руками: в test/assets/words_seed_test.dart '
    'hasLength(${plan.wordsBefore}) → hasLength(${plan.wordsAfter}). '
    'Инструмент этого не делает: число — часть коммита порции.',
  );

  stdout.writeln('\n=== flutter test test/assets ===');
  const command = ['test', 'test/assets'];
  // Кодировки явно: без них вывод дочернего процесса декодируется кодировкой
  // консоли (на Windows cp1251), и падение теста про русское слово приходит
  // нечитаемым — то есть ровно тогда, когда его и надо читать.
  final done = Process.runSync(
    'flutter',
    command,
    runInShell: true,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  stdout.write(done.stdout);
  stderr.write(done.stderr);
  if (done.exitCode != 0) {
    stdout.writeln(
      'Тест ассета красный. Если единственная жалоба — на число слов, '
      'это и есть незакрытый пункт выше.',
    );
  }
  exitCode = done.exitCode;
}

void _fail(String message) {
  stderr
    ..writeln('merge_portion: $message')
    ..writeln('')
    ..writeln(_usage);
  exitCode = 64;
}
