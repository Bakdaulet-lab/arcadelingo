/// Ход партии в ниндзя-слэш: фазы, счёт, жизни и протокол с ядром.
///
/// Класс намеренно без Flutter — как `FallingWordsRun` и по той же причине:
/// весь смысл игры (ровно один `report()` на слово, жизни, комбо, реальный
/// лимит времени) проверяется без дерева виджетов. Виджет над ним отвечает
/// только за время, жест и рисование, и это разделение держит главный
/// инвариант контракта: страж «уже отвечено» живёт здесь, а не в
/// обработчике жеста, где его обойдёт вторая точка того же свайпа.
///
/// Правила — `SPEC.md`, раздел «Ниндзя-слэш»; связь с ядром —
/// `.claude/skills/game-contract`.
library;

import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';

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
  NinjaRun({required ReviewSession session, required Random random});

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

  NinjaPhase get phase => throw UnimplementedError();

  /// Слово на экране; null вне фаз [NinjaPhase.flying] и
  /// [NinjaPhase.reveal].
  ReviewItem? get item => throw UnimplementedError();

  /// Переводы объектов волны в порядке дорожек.
  List<String> get options => throw UnimplementedError();

  /// Позиция верного объекта в [options].
  int get correctIndex => throw UnimplementedError();

  /// Сколько времени дано на текущую волну. Реальный лимит, а не
  /// константа: по нему SRS нормализует скорость между играми.
  Duration get timeLimit => throw UnimplementedError();

  /// Итог последнего показа; null, пока показа не было.
  Verdict? get verdict => throw UnimplementedError();

  /// Разрезанный объект; null при таймауте.
  int? get slicedIndex => throw UnimplementedError();

  /// Сколько держать подсветку по [verdict]. Таймаут — тот же промах:
  /// верный перевод надо успеть прочитать.
  Duration get revealTime => throw UnimplementedError();

  int get lives => throw UnimplementedError();

  int get score => throw UnimplementedError();

  /// Текущая серия верных резов подряд.
  int get combo => throw UnimplementedError();

  /// На что умножатся очки за следующий верный рез: серия плюс один.
  int get scoreMultiplier => throw UnimplementedError();

  int get bestCombo => throw UnimplementedError();

  int get correctCount => throw UnimplementedError();

  /// Сколько ответов доложено; слово с повтором даёт два.
  int get answeredCount => throw UnimplementedError();

  /// Был ли последний рез сделан в последние 15% полёта. Промах и таймаут
  /// последним моментом не считаются, каким бы поздним ни был жест.
  bool get nearMiss => throw UnimplementedError();

  /// Сколько очков принёс последний рез; ноль при промахе и таймауте.
  int get lastPoints => throw UnimplementedError();

  /// Берёт первое слово. Пустая сессия → [NinjaPhase.nothingToday].
  void start() => throw UnimplementedError();

  /// Разрезан объект [index] за [elapsed]. Вне фазы полёта возвращает false
  /// и ничего не докладывает — этим держится «ровно один report() на
  /// слово»: следующая точка того же свайпа приходит в ещё не
  /// перестроенное дерево, и остановить её может только состояние.
  bool slice(int index, Duration elapsed) => throw UnimplementedError();

  /// Все объекты упали: промах с responseTime == [timeLimit].
  bool timeout() => throw UnimplementedError();

  /// Конец подсветки: следующая волна, итоги или конец по жизням.
  void advance() => throw UnimplementedError();

  /// Игрок вышел из игры с невыданным ответом: докладывает неответ за
  /// [elapsed]. Вне фазы полёта не делает ничего.
  void abandon(Duration elapsed) => throw UnimplementedError();
}
