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
  throw UnimplementedError();
}

/// Порция → текст файла `portion_NN.json`: те же имена полей, что в сиде,
/// плюс пустые `translation` и `distractors` под руку человека.
String encodePortion(Portion portion) {
  throw UnimplementedError();
}

/// Ничьи → CSV. Пустой список даёт файл с одной шапкой, а не отсутствие
/// файла: «ничьих нет» и «импортёр про них забыл» обязаны отличаться.
String encodeAmbiguousCsv(List<AmbiguousWord> words) {
  throw UnimplementedError();
}

/// Отсев → CSV, с причиной строкой.
String encodeSkippedCsv(List<SkippedRow> rows) {
  throw UnimplementedError();
}

/// Воронка → человекочитаемый отчёт для stdout.
String formatFunnel(ImportFunnel funnel) {
  throw UnimplementedError();
}

/// Страж инварианта: писать под `assets/` импортёру запрещено.
///
/// Проверка не про безопасность, а про дисциплину пайплайна: `--out assets`
/// набирается опечаткой, а перезаписанный сид уносит с собой вычитанные
/// переводы, которых в CSV нет и не будет.
void assertOutDirAllowed(String path) {
  throw UnimplementedError();
}

/// Читает CSV и сид, пишет порции, `ambiguous.csv` и `skipped.csv`, печатает
/// воронку. Единственное место в файле, которое трогает диск.
Future<void> main(List<String> args) async {
  throw UnimplementedError();
}
