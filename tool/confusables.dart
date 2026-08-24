/// Файл ловушек `tool/confusables.csv` — пары слов, которые нельзя показывать
/// в один день.
///
/// Зачем он есть. Зеркальные пары (`open` ↔ `close`) валидатор находит сам:
/// взаимность обманок видна механически. А почти-синонимы на разных карточках
/// («шагать» и «ходить») и однокоренные переводы («приходить» и «ходить»)
/// механически не видны вообще — их замечает только тот, кто вычитывает
/// порцию. Без файла это знание уходит вместе с сессией, ровно как ушли бы
/// причины отказов без `rejected.json`.
///
/// Поэтому правило одностороннее: **найденное обязано быть записано**, но
/// записанное не обязано находиться. Автонаходки и ручные находки живут в
/// одном файле, и потребитель у них один — правило сессии Б1.
///
/// Формат: `first,second,reason`. Первые две колонки — id, всё остальное до
/// конца строки — причина: её пишет человек, и запятых в ней сколько угодно.
library;

import 'seed_rules.dart';

/// Путь к файлу от корня репозитория. Не ассет: в приложение он не едет.
const String confusablesPath = 'tool/confusables.csv';

/// Пара слов, которые не должны встретиться игроку в один день.
class ConfusablePair {
  const ConfusablePair({
    required this.first,
    required this.second,
    required this.reason,
  });

  final String first;
  final String second;

  /// Почему пара опасна. Пустой быть не может: без причины файл — просто
  /// список, и через месяц по нему нечего будет понять.
  final String reason;

  /// Ключ, не зависящий от порядка слов в паре.
  String get key => confusableKey(first, second);

  @override
  String toString() => '$first ↔ $second';
}

/// Канонический ключ пары: порядок слов в файле и в находке валидатора
/// совпадать не обязан.
String confusableKey(String a, String b) =>
    a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';

/// Текст файла → пары. Битая строка роняет разбор: пропустить её значило бы
/// молча потерять ловушку, ради записи которой файл и заведён.
List<ConfusablePair> parseConfusables(String csv) {
  final pairs = <ConfusablePair>[];
  final lines = csv.split('\n');
  for (var index = 1; index < lines.length; index++) {
    final line = lines[index].trim();
    if (line.isEmpty) continue;
    final number = index + 1;
    // Колонки разделяют только первые две запятые: остальные — часть причины,
    // а причину пишет человек, и запятых в ней сколько угодно.
    final fields = line.split(',');
    if (fields.length < 3) {
      throw FormatException(
        'ловушки: строка $number: нужно три колонки, а не ${fields.length}: '
        '"$line"',
      );
    }
    final first = fields[0].trim();
    final second = fields[1].trim();
    final reason = fields.sublist(2).join(',').trim();
    if (first.isEmpty || second.isEmpty) {
      throw FormatException('ловушки: строка $number: пустой id в паре');
    }
    if (first == second) {
      throw FormatException(
        'ловушки: строка $number: слово "$first" в паре с самим собой',
      );
    }
    if (reason.isEmpty) {
      throw FormatException(
        'ловушки: строка $number: пара $first / $second без причины',
      );
    }
    pairs.add(ConfusablePair(first: first, second: second, reason: reason));
  }
  return pairs;
}

/// Ключи всех записанных пар.
Set<String> confusableKeys(String csv) => {
  for (final pair in parseConfusables(csv)) pair.key,
};

/// Каждое слово из файла обязано существовать в сиде.
///
/// Сверяется **после** сведения: пара, у которой второе слово приезжает той же
/// порцией, законна, и до сведения её id в сиде ещё нет. А запись «на будущее»
/// (слово из несведённой порции) запрещена — пара вносится тем же коммитом,
/// что и второе слово пары.
List<SeedProblem> checkConfusablesExist(Object? root, String csv) {
  throw UnimplementedError();
}

/// Каждая найденная зеркальная пара обязана быть в файле.
///
/// Обратное неверно и проверяться не может: почти-синонимы валидатор не найдёт
/// никогда, на то файл и ведётся руками.
List<SeedProblem> checkMirrorPairsListed(Object? root, String csv) {
  final listed = confusableKeys(csv);
  return [
    for (final pair in findMirrorPairs(root))
      if (!listed.contains(confusableKey(pair.first, pair.second)))
        SeedProblem(
          SeedRule.mirrorPairNotListed,
          'зеркальная пара "${pair.first}" / "${pair.second}" не внесена в '
          '$confusablesPath: пару нашли, а записать забыли',
        ),
  ];
}
