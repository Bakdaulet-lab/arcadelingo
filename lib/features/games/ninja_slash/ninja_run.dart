/// Ход партии в ниндзя-слэш: фазы, счёт, жизни и протокол с ядром.
///
/// Класс намеренно без Flutter — как `FallingWordsRun` и по той же причине:
/// весь смысл игры (ровно один `report()` на слово, жизни, комбо, реальный
/// лимит времени) проверяется без дерева виджетов. Виджет над ним отвечает
/// только за время, жест и рисование, и это разделение держит главный
/// инвариант контракта: страж «уже отвечено» живёт здесь, а не в
/// обработчике жеста, где его обойдёт вторая точка того же свайпа.
///
/// Файл — зеркало `falling_words_run.dart`, а не общий с ним код: игры —
/// острова (правило 5 «Архитектурного закона»), и `arch_check.sh` ловит
/// импорт соседа. Цена дублирования названа в SPEC и в плане Фазы 4;
/// выделять общее будет третья игра, по списку, а не по догадке.
///
/// Правила — `SPEC.md`, раздел «Ниндзя-слэш»; связь с ядром —
/// `.claude/skills/game-contract`.
library;

import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';

import 'ninja_slash_juice.dart';

/// Что происходит на экране прямо сейчас.
enum NinjaPhase {
  /// Объекты в полёте, жест принимается.
  flying,

  /// Рез сделан (или время вышло), показываем итог.
  reveal,

  /// Сессия исчерпана или жизни кончились — экран итогов.
  over,

  /// Сессия не дала ни одного слова — экран «на сегодня всё».
  nothingToday,
}

/// Чем кончился последний показ.
enum Verdict { correct, wrong, timeout }

/// Одна партия: спросила слово, подняла волну, доложила результат.
class NinjaRun {
  /// Слова берутся только из [session]; [random] выбирает обманки и
  /// расставляет объекты по дорожкам.
  NinjaRun({required ReviewSession session, required Random random})
    : _session = session,
      _random = random;

  /// Время полёта волны без комбо.
  static const Duration baseFlightTime = Duration(milliseconds: 3500);

  /// Взвод перед первой волной (`SPEC.md`).
  ///
  /// Как и в падающих словах, фазы у взвода нет: чистый класс про него не
  /// знает вовсе. Взвод — про то, что человек ещё не понял, где поле, а не
  /// про правила игры, и держит его виджет.
  static const Duration windUpTime = Duration(milliseconds: 700);

  /// Сколько времени снимает каждый уровень комбо.
  static const Duration flightTimeStep = Duration(milliseconds: 200);

  /// Быстрее этого волна не летит, каким бы длинным ни было комбо.
  static const Duration minFlightTime = Duration(seconds: 2);

  /// Сколько объектов поднимает волна: верный плюс два дистрактора.
  ///
  /// Три, а не четыре: четыре перевода в полёте на экране 360 dp либо
  /// мелкие, либо налезают друг на друга, и игра из «узнай перевод»
  /// становится «успей прочитать». Цена — третий дистрактор слова остаётся
  /// невостребованным.
  static const int maxObjects = 3;

  /// Жизней на партию.
  static const int startLives = 3;

  /// Сколько держится пара «слово → перевод» после промаха (SPEC).
  static const Duration wrongReveal = Duration(milliseconds: 800);

  /// Сколько разлетаются половинки верно разрезанного объекта.
  static const Duration correctReveal = Duration(milliseconds: 300);

  /// Очки за верный рез при множителе 1.
  static const int pointsPerCombo = 10;

  final ReviewSession _session;
  final Random _random;

  /// До [start] слова нет — это и есть «на сегодня всё», пока сессия не
  /// доказала обратное.
  NinjaPhase _phase = NinjaPhase.nothingToday;

  ReviewItem? _item;
  List<String> _options = const [];
  int _correctIndex = 0;
  Duration _timeLimit = baseFlightTime;
  Verdict? _verdict;
  int? _slicedIndex;
  int _lives = startLives;
  int _score = 0;
  int _combo = 0;
  int _bestCombo = 0;
  int _correctCount = 0;
  int _answeredCount = 0;
  bool _nearMiss = false;
  int _lastPoints = 0;

  NinjaPhase get phase => _phase;

  /// Слово на экране; null вне фаз [NinjaPhase.flying] и
  /// [NinjaPhase.reveal].
  ReviewItem? get item => _item;

  /// Переводы объектов волны в порядке дорожек.
  List<String> get options => _options;

  /// Позиция верного объекта в [options].
  int get correctIndex => _correctIndex;

  /// Сколько времени дано на текущую волну. Реальный лимит, а не
  /// константа: по нему SRS нормализует скорость между играми.
  Duration get timeLimit => _timeLimit;

  /// Итог последнего показа; null, пока показа не было.
  Verdict? get verdict => _verdict;

  /// Разрезанный объект; null при таймауте.
  int? get slicedIndex => _slicedIndex;

  /// Сколько держать подсветку по [verdict]. Таймаут — тот же промах:
  /// верный перевод надо успеть прочитать.
  Duration get revealTime =>
      _verdict == Verdict.correct ? correctReveal : wrongReveal;

  int get lives => _lives;

  int get score => _score;

  /// Текущая серия верных резов подряд.
  int get combo => _combo;

  /// На что умножатся очки за следующий верный рез.
  ///
  /// Серия плюс один, а не серия: очки считаются до инкремента. Формула
  /// живёт здесь одна — HUD, показывающий голое [combo], обещал бы игроку
  /// ×0 за рез, который принесёт 10 очков.
  int get scoreMultiplier => _combo + 1;

  int get bestCombo => _bestCombo;

  int get correctCount => _correctCount;

  /// Сколько ответов доложено; слово с повтором даёт два.
  int get answeredCount => _answeredCount;

  /// Был ли последний рез сделан в последние 15% полёта. Промах и таймаут
  /// последним моментом не считаются, каким бы поздним ни был жест: бонус —
  /// награда за верный рез, а не за то, что время вышло.
  bool get nearMiss => _nearMiss;

  /// Сколько очков принёс последний рез; ноль при промахе и таймауте.
  /// Нужен экрану: `+N` показывает именно прирост, а не весь счёт.
  int get lastPoints => _lastPoints;

  /// Берёт первое слово. Пустая сессия → [NinjaPhase.nothingToday].
  void start() {
    final first = _session.nextItem();
    if (first != null) _show(first);
  }

  /// Разрезан объект [index] за [elapsed]. Вне фазы полёта возвращает false
  /// и ничего не докладывает — этим держится «ровно один report() на
  /// слово»: следующая точка того же свайпа приходит в ещё не
  /// перестроенное дерево, и остановить её может только состояние.
  bool slice(int index, Duration elapsed) {
    if (_phase != NinjaPhase.flying) return false;
    if (index < 0 || index >= _options.length) {
      throw ArgumentError.value(index, 'index', 'нет такого объекта в волне');
    }
    _checkElapsed(elapsed);
    _slicedIndex = index;
    _finish(index == _correctIndex ? Verdict.correct : Verdict.wrong, elapsed);
    return true;
  }

  /// Все объекты упали: промах с responseTime == [timeLimit].
  bool timeout() {
    if (_phase != NinjaPhase.flying) return false;
    _slicedIndex = null;
    _finish(Verdict.timeout, _timeLimit);
    return true;
  }

  /// Конец подсветки: следующая волна, итоги или конец по жизням.
  void advance() {
    if (_phase != NinjaPhase.reveal) return;
    if (_lives == 0) {
      _phase = NinjaPhase.over;
      return;
    }
    final next = _session.nextItem();
    if (next == null) {
      _item = null;
      _phase = NinjaPhase.over;
      return;
    }
    _show(next);
  }

  /// Игрок вышел из игры с невыданным ответом: докладывает неответ за
  /// [elapsed]. Вне фазы полёта не делает ничего.
  ///
  /// Третьего варианта у game-contract нет: либо доложи неответ, либо не
  /// бери item. Молчание порвало бы протокол — следующий `nextItem()` упал
  /// бы со `StateError` о неотвеченном слове.
  void abandon(Duration elapsed) {
    if (_phase != NinjaPhase.flying) return;
    _checkElapsed(elapsed);
    _phase = NinjaPhase.over;
    _answeredCount++;
    _combo = 0;
    _report(correct: false, elapsed: elapsed);
  }

  /// Поднимает волну по [item]: новый лимит по текущему комбо, обманки и
  /// порядок объектов.
  ///
  /// Обманки сначала перемешиваются, потом берутся первые две: иначе
  /// третья дистрактора не участвовала бы в игре никогда, и слово навсегда
  /// сводилось бы к одной и той же паре обманок.
  ///
  /// Перемешиваются позиции, а не строки: если обманка совпала с переводом
  /// (дефект контента, игра его не чинит), `indexOf` по тексту показал бы
  /// на чужой объект.
  void _show(ReviewItem item) {
    final decoys = List.of(item.distractors)..shuffle(_random);
    final variants = [item.word.translation, ...decoys.take(maxObjects - 1)];
    final order = List<int>.generate(variants.length, (i) => i)
      ..shuffle(_random);
    _item = item;
    _options = List.unmodifiable([for (final i in order) variants[i]]);
    _correctIndex = order.indexOf(0);
    _timeLimit = _flightTime();
    _verdict = null;
    _slicedIndex = null;
    _nearMiss = false;
    _lastPoints = 0;
    _phase = NinjaPhase.flying;
  }

  /// Время полёта по текущему комбо: 3.5 с минус 0.2 с за уровень, но не
  /// быстрее 2 с.
  Duration _flightTime() {
    final reduced = baseFlightTime - flightTimeStep * _combo;
    return reduced < minFlightTime ? minFlightTime : reduced;
  }

  /// Закрывает показ: считает очки и жизни, затем докладывает.
  ///
  /// Фаза меняется первой строкой — до доклада и до любого `setState` в
  /// виджете: пока она не сменилась, следующая точка того же свайпа ещё
  /// считалась бы резом.
  void _finish(Verdict verdict, Duration elapsed) {
    _phase = NinjaPhase.reveal;
    _verdict = verdict;
    _answeredCount++;
    if (verdict == Verdict.correct) {
      // Бонус только верному резу: промах и таймаут бывают сколь угодно
      // поздними, и награждать за вышедшее время игра не станет.
      _nearMiss = isNearMiss(responseTime: elapsed, timeLimit: _timeLimit);
      final earned = pointsPerCombo * scoreMultiplier;
      // Целочисленно и от очков с множителем, а не от базовых десяти:
      // умножение идёт до деления, поэтому остатка здесь не бывает вовсе.
      _lastPoints =
          _nearMiss
              ? earned * nearMissBonusNumerator ~/ nearMissBonusDenominator
              : earned;
      _score += _lastPoints;
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

  /// Время реза вне 0..[timeLimit] — баг вызывающего, а не исход игры:
  /// такие данные обязан был отсеять тот, кто их построил.
  void _checkElapsed(Duration elapsed) {
    if (elapsed < Duration.zero || elapsed > _timeLimit) {
      throw ArgumentError.value(
        elapsed,
        'elapsed',
        'время реза вне 0..$_timeLimit',
      );
    }
  }
}
