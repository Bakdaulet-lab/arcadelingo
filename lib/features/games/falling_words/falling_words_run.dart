/// Ход игры «падающие слова»: фазы, счёт, жизни и протокол с ядром.
///
/// Класс намеренно без Flutter: весь смысл игры — ровно один `report()` на
/// слово, жизни, комбо и реальный лимит времени — проверяется без дерева
/// виджетов. Виджет над ним отвечает только за время и рисование, и это
/// разделение держит главный инвариант контракта: страж «уже отвечено»
/// живёт здесь, а не в обработчике тапа, где его обойдёт второй тап в том
/// же кадре.
///
/// Правила — `SPEC.md`; связь с ядром — `.claude/skills/game-contract`.
library;

import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';

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
  FallingWordsRun({required ReviewSession session, required Random random})
    : _session = session,
      _random = random;

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

  final ReviewSession _session;
  final Random _random;

  /// До [start] слова нет — это и есть «на сегодня всё», пока сессия не
  /// доказала обратное.
  FallingPhase _phase = FallingPhase.nothingToday;

  ReviewItem? _item;
  List<String> _options = const [];
  int _correctIndex = 0;
  Duration _timeLimit = baseFallTime;
  Verdict? _verdict;
  int? _chosenIndex;
  int _lives = startLives;
  int _score = 0;
  int _combo = 0;
  int _bestCombo = 0;
  int _correctCount = 0;
  int _answeredCount = 0;

  FallingPhase get phase => _phase;

  /// Слово на экране; null вне фаз [FallingPhase.falling] и
  /// [FallingPhase.reveal].
  ReviewItem? get item => _item;

  /// Варианты ответа в порядке показа: перевод и все дистракторы слова.
  List<String> get options => _options;

  /// Позиция верного варианта в [options].
  int get correctIndex => _correctIndex;

  /// Сколько времени дано на текущее слово. Реальный лимит, а не
  /// константа: по нему SRS нормализует скорость между играми.
  Duration get timeLimit => _timeLimit;

  /// Итог последнего ответа; null, пока ответа не было.
  Verdict? get verdict => _verdict;

  /// Нажатая кнопка; null при таймауте.
  int? get chosenIndex => _chosenIndex;

  /// Сколько держать подсветку по [verdict]. Таймаут — тот же неверный
  /// ответ: верный вариант надо успеть прочитать.
  Duration get revealTime =>
      _verdict == Verdict.correct ? correctReveal : wrongReveal;

  int get lives => _lives;

  int get score => _score;

  /// Текущая серия верных ответов подряд.
  int get combo => _combo;

  /// На что умножатся очки за следующий верный ответ.
  ///
  /// Серия плюс один, а не серия: SPEC говорит «+очки × множитель комбо,
  /// комбо +1», то есть очки считаются до инкремента. Формула живёт здесь
  /// одна: HUD, показывающий голое [combo], обещал бы игроку ×0 за ответ,
  /// который принесёт 10 очков.
  int get scoreMultiplier => _combo + 1;

  int get bestCombo => _bestCombo;

  int get correctCount => _correctCount;

  /// Сколько ответов доложено; слово с повтором даёт два.
  int get answeredCount => _answeredCount;

  /// Был ли последний ответ дан в последние 15% лимита. Промах и таймаут
  /// последним моментом не считаются, каким бы поздним ни был ответ:
  /// бонус — награда за верный ответ, а не за то, что время вышло.
  bool get nearMiss {
    throw UnimplementedError();
  }

  /// Сколько очков принёс последний ответ; ноль при промахе и таймауте.
  /// Нужен экрану: `+N` показывает именно прирост, а не весь счёт.
  int get lastPoints {
    throw UnimplementedError();
  }

  /// Берёт первое слово. Пустая сессия → [FallingPhase.nothingToday].
  void start() {
    final first = _session.nextItem();
    if (first != null) _show(first);
  }

  /// Ответ кнопкой [index] за [elapsed]. Вне фазы падения возвращает false
  /// и ничего не докладывает — этим держится «ровно один report() на
  /// слово» при двойном тапе: второй тап приходит в ещё не перестроенное
  /// дерево, и остановить его может только состояние, а не виджет.
  bool choose(int index, Duration elapsed) {
    if (_phase != FallingPhase.falling) return false;
    if (index < 0 || index >= _options.length) {
      throw ArgumentError.value(index, 'index', 'нет такого варианта ответа');
    }
    _checkElapsed(elapsed);
    _chosenIndex = index;
    _finish(index == _correctIndex ? Verdict.correct : Verdict.wrong, elapsed);
    return true;
  }

  /// Слово коснулось низа: неверный ответ с responseTime == [timeLimit].
  bool timeout() {
    if (_phase != FallingPhase.falling) return false;
    _chosenIndex = null;
    _finish(Verdict.timeout, _timeLimit);
    return true;
  }

  /// Конец подсветки: следующее слово, итоги или конец по жизням.
  void advance() {
    if (_phase != FallingPhase.reveal) return;
    if (_lives == 0) {
      _phase = FallingPhase.over;
      return;
    }
    final next = _session.nextItem();
    if (next == null) {
      _item = null;
      _phase = FallingPhase.over;
      return;
    }
    _show(next);
  }

  /// Игрок вышел из игры с невыданным ответом: докладывает неответ за
  /// [elapsed]. Вне фазы падения не делает ничего.
  ///
  /// Третьего варианта у game-contract нет: либо доложи неответ, либо не
  /// бери item. Молчание порвало бы протокол — следующий `nextItem()`
  /// упал бы со `StateError` о неотвеченном слове. Что брошенное слово
  /// уходит в коробку 1 — решение продуктовое, `docs/dev/context.md`.
  void abandon(Duration elapsed) {
    if (_phase != FallingPhase.falling) return;
    _checkElapsed(elapsed);
    _phase = FallingPhase.over;
    _answeredCount++;
    _combo = 0;
    _report(correct: false, elapsed: elapsed);
  }

  /// Ставит [item] на экран: новый лимит по текущему комбо и перемешанные
  /// варианты.
  ///
  /// Перемешиваются позиции, а не строки: если обманка совпала с
  /// переводом (дефект контента, игра его не чинит), `indexOf` по тексту
  /// показал бы на чужую кнопку.
  void _show(ReviewItem item) {
    final variants = [item.word.translation, ...item.distractors];
    final order = List<int>.generate(variants.length, (i) => i)
      ..shuffle(_random);
    _item = item;
    _options = List.unmodifiable([for (final i in order) variants[i]]);
    _correctIndex = order.indexOf(0);
    _timeLimit = _fallTime();
    _verdict = null;
    _chosenIndex = null;
    _phase = FallingPhase.falling;
  }

  /// Время падения по текущему комбо: 6 с минус 0.25 с за уровень, но не
  /// быстрее 3 с.
  Duration _fallTime() {
    final reduced = baseFallTime - fallTimeStep * _combo;
    return reduced < minFallTime ? minFallTime : reduced;
  }

  /// Закрывает показ: считает очки и жизни, затем докладывает.
  ///
  /// Фаза меняется первой строкой — до доклада и до любого `setState` в
  /// виджете: пока она не сменилась, второй тап того же кадра ещё считался
  /// бы ответом.
  void _finish(Verdict verdict, Duration elapsed) {
    _phase = FallingPhase.reveal;
    _verdict = verdict;
    _answeredCount++;
    if (verdict == Verdict.correct) {
      _score += pointsPerCombo * scoreMultiplier;
      _combo++;
      if (_combo > _bestCombo) _bestCombo = _combo;
      _correctCount++;
    } else {
      _combo = 0;
      _lives--;
    }
    _report(correct: verdict == Verdict.correct, elapsed: elapsed);
  }

  /// Единственное место, где строится [ReviewOutcome].
  ///
  /// Неотрицательность `responseTime` сторожит [_checkElapsed]: domain её
  /// не проверяет — шапка `lib/domain/srs/grade_outcome.dart`. Подсказок в
  /// этой игре нет, поэтому `hintsUsed` остаётся нулём по умолчанию.
  void _report({required bool correct, required Duration elapsed}) {
    _session.report(
      ReviewOutcome(
        correct: correct,
        responseTime: elapsed,
        timeLimit: _timeLimit,
      ),
    );
  }

  /// Время ответа вне 0..[timeLimit] — баг вызывающего, а не исход игры:
  /// такие данные обязан был отсеять тот, кто их построил.
  void _checkElapsed(Duration elapsed) {
    if (elapsed < Duration.zero || elapsed > _timeLimit) {
      throw ArgumentError.value(
        elapsed,
        'elapsed',
        'время ответа вне 0..$_timeLimit',
      );
    }
  }
}
