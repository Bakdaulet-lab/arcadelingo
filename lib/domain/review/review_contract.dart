/// Контракт между ядром обучения и любой аркадной игрой.
///
/// ЗАКОН: игра не знает, как планируются повторы. Она спрашивает следующее
/// слово, показывает его как хочет, и докладывает результат. Всё.
///
/// В этом файле и во всём lib/domain/ нет импортов Flutter. Это проверяется
/// скриптом scripts/arch_check.sh.
library;

/// Слово, которое учим.
class Word {
  const Word({
    required this.id,
    required this.text,
    required this.translation,
    this.partOfSpeech,
    this.example,
  });

  final String id;

  /// Английское слово.
  final String text;

  /// Перевод на язык интерфейса.
  final String translation;

  /// Часть речи — нужна генератору дистракторов, чтобы обманки были правдоподобны.
  final String? partOfSpeech;

  /// Пример употребления.
  final String? example;
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
  });

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

  /// Сколько слов запланировано в сессии. Может быть меньше цели,
  /// если к повторению готово мало слов.
  int get total;
}
