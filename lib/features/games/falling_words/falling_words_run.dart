/// Ход игры «падающие слова»: фазы, счёт, жизни и протокол с ядром.
///
/// Реализации здесь ещё нет — только сигнатуры, на которых компилируются
/// тесты задачи 0.7. Тело появляется в той же задаче следующим коммитом,
/// тесты в этот момент не трогаются.
///
/// Класс намеренно без Flutter: весь смысл игры — один report() на слово,
/// жизни, комбо и лимит времени — проверяется без дерева виджетов. Виджет
/// над ним отвечает только за время и рисование.
library;

import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';

const String _todo = 'игра «падающие слова» не реализована — задача 0.7';

/// Что происходит на экране прямо сейчас.
enum FallingPhase {
  /// Слово падает, кнопки живые.
  falling,

  /// Ответ дан (или время вышло), показываем верный вариант.
  reveal,

  /// Сессия исчерпана или жизни кончились — экран итогов.
  over,

  /// Сессия не дала ни одного слова — экран «на сегодня всё».
  nothingToday,
}

/// Чем кончился последний показ.
enum Verdict { correct, wrong, timeout }

/// Одна партия: спросила слово, показала, доложила результат.
class FallingWordsRun {
  /// Слова берутся только из [session]; [random] перемешивает варианты.
  FallingWordsRun({required ReviewSession session, required Random random});

  /// Время падения слова без комбо.
  static const Duration baseFallTime = Duration(seconds: 6);

  /// Сколько времени снимает каждый уровень комбо.
  static const Duration fallTimeStep = Duration(milliseconds: 250);

  /// Быстрее этого слово не падает, каким бы длинным ни было комбо.
  static const Duration minFallTime = Duration(seconds: 3);

  /// Жизней на партию.
  static const int startLives = 3;

  /// Сколько держится подсветка верного варианта после ошибки (SPEC).
  static const Duration wrongReveal = Duration(milliseconds: 800);

  /// Сколько рассыпается верно отвеченное слово.
  static const Duration correctReveal = Duration(milliseconds: 300);

  /// Очки за верный ответ при множителе 1.
  static const int pointsPerCombo = 10;

  FallingPhase get phase => throw UnimplementedError(_todo);

  /// Слово на экране; null вне фаз [FallingPhase.falling] и
  /// [FallingPhase.reveal].
  ReviewItem? get item => throw UnimplementedError(_todo);

  /// Варианты ответа в порядке показа: перевод и все дистракторы слова.
  List<String> get options => throw UnimplementedError(_todo);

  /// Позиция верного варианта в [options].
  int get correctIndex => throw UnimplementedError(_todo);

  /// Сколько времени дано на текущее слово. Реальный лимит, а не
  /// константа: по нему SRS нормализует скорость между играми.
  Duration get timeLimit => throw UnimplementedError(_todo);

  /// Итог последнего ответа; null, пока ответа не было.
  Verdict? get verdict => throw UnimplementedError(_todo);

  /// Нажатая кнопка; null при таймауте.
  int? get chosenIndex => throw UnimplementedError(_todo);

  /// Сколько держать подсветку по [verdict].
  Duration get revealTime => throw UnimplementedError(_todo);

  int get lives => throw UnimplementedError(_todo);

  int get score => throw UnimplementedError(_todo);

  /// Текущая серия верных ответов подряд.
  int get combo => throw UnimplementedError(_todo);

  int get bestCombo => throw UnimplementedError(_todo);

  int get correctCount => throw UnimplementedError(_todo);

  /// Сколько ответов доложено; слово с повтором даёт два.
  int get answeredCount => throw UnimplementedError(_todo);

  /// Берёт первое слово. Пустая сессия → [FallingPhase.nothingToday].
  void start() => throw UnimplementedError(_todo);

  /// Ответ кнопкой [index] за [elapsed]. Вне фазы падения возвращает false
  /// и ничего не докладывает — этим держится «ровно один report() на
  /// слово» при двойном тапе.
  bool choose(int index, Duration elapsed) => throw UnimplementedError(_todo);

  /// Слово коснулось низа: неверный ответ с responseTime == [timeLimit].
  bool timeout() => throw UnimplementedError(_todo);

  /// Конец подсветки: следующее слово, итоги или конец по жизням.
  void advance() => throw UnimplementedError(_todo);

  /// Игрок вышел с невыданным ответом: докладывает неответ за [elapsed].
  /// Вне фазы падения не делает ничего.
  void abandon(Duration elapsed) => throw UnimplementedError(_todo);
}
