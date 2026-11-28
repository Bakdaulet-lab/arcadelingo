/// Контракт между ядром обучения и любой аркадной игрой.
///
/// ЗАКОН: игра не знает, как планируются повторы. Она спрашивает следующее
/// слово, показывает его как хочет, и докладывает результат. Всё.
///
/// В этом файле и во всём lib/domain/ нет импортов Flutter. Это проверяется
/// скриптом scripts/arch_check.sh.
library;

/// Уровень владения языком по CEFR.
enum CefrLevel { a1, a2, b1, b2, c1, c2 }

/// Слово, которое учим.
class Word {
  const Word({
    required this.id,
    required this.text,
    required this.translation,
    this.level = CefrLevel.a1,
    this.partOfSpeech,
    this.example,
    this.article,
  });

  final String id;

  /// Написание изучаемого слова без отдельного артикля.
  final String text;

  /// Перевод на исходный язык курса.
  final String translation;

  /// Уровень слова для отбора карточек перед началом партии.
  final CefrLevel level;

  /// Часть речи — нужна генератору дистракторов, чтобы обманки были правдоподобны.
  final String? partOfSpeech;

  /// Пример употребления.
  final String? example;

  /// Артикль словарного заголовка, когда курс его предоставляет.
  final String? article;

  String get headword => article == null ? text : '$article $text';
}

/// Единица показа: слово плюс правдоподобные обманки для игр с выбором.
///
/// Дистракторы приходят готовыми из ядра. Игра их не придумывает: качество
/// обманок определяет сложность, и это ответственность контент-пайплайна.
class ReviewItem {
  const ReviewItem({required this.word, this.distractors = const []});

  final Word word;
  final List<String> distractors;
}

/// Что игра докладывает обратно после ответа пользователя.
///
/// Игра сообщает сырой факт. Перевод факта в оценку для планировщика —
/// работа domain/srs, не игры.
class ReviewOutcome {
  const ReviewOutcome({
    required this.correct,
    required this.responseTime,
    required this.timeLimit,
    this.hintsUsed = 0,
    this.selectedAnswer,
    this.timedOut = false,
  }) : isUntimed = false;

  const ReviewOutcome.untimed({
    required this.correct,
    required this.responseTime,
    this.hintsUsed = 0,
    this.selectedAnswer,
  }) : timeLimit = Duration.zero,
       isUntimed = true,
       timedOut = false;

  /// Время ответа записывается, но не участвует в оценке.
  final bool isUntimed;

  /// Ответил ли пользователь верно. Истёкшее время — это false.
  final bool correct;

  /// Сколько ушло на ответ. При таймауте равно [timeLimit].
  final Duration responseTime;

  /// Сколько времени игра давала на ответ. Нужно, чтобы нормализовать
  /// скорость между играми с разным темпом: медленный ответ в быстрой игре
  /// и быстрый ответ в медленной не должны оцениваться одинаково.
  final Duration timeLimit;

  /// Сколько подсказок использовано. Понижает оценку.
  final int hintsUsed;

  /// Точный вариант, выбранный игроком. У неответа варианта нет.
  final String? selectedAnswer;

  /// Время истекло. Выход посреди партии — отдельный вид неответа.
  final bool timedOut;
}

/// Единственная точка сопряжения игры и ядра обучения.
///
/// Жизненный цикл внутри игры:
/// ```dart
/// final item = session.nextItem();
/// if (item == null) {
///   // сессия исчерпана — показать итоги
/// } else {
///   // показать item, дождаться ответа
///   session.report(outcome);
/// }
/// ```
///
/// [report] вызывается ровно один раз на каждый непустой [nextItem].
abstract class ReviewSession {
  /// Следующее слово или null, если сессия исчерпана.
  ReviewItem? nextItem();

  /// Результат по последнему выданному item.
  void report(ReviewOutcome outcome);

  bool get isFinished;

  /// Прогресс для HUD.
  int get answered;

  /// Сколько показов запланировано в сессии; слово, вернувшееся на повтор,
  /// занимает два. Может быть меньше цели, если к повторению готово мало
  /// слов. Не меняется до конца сессии.
  int get total;
}

/// Review for a field showing several items at once.
abstract interface class BoardReviewSession implements ReviewSession {
  /// Unplayed items in schedule order. Reading the list makes no reservation.
  List<ReviewItem> get remainingItems;

  /// Reports one completed pair, in any order, using its item from the list.
  /// The board gives immediate retries, so this item returns on a later
  /// session according to its grade.
  void reportPair(ReviewItem item, ReviewOutcome outcome);
}
