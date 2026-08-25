/// Части экрана ниндзя-слэша и ключи, по которым их находят тесты и
/// голдены.
///
/// Здесь нет ни таймеров, ни состояния: всё, что видно, приходит
/// параметрами. Так экран можно собрать в голдене на любой момент волны,
/// не проигрывая партию.
///
/// **Это копия `falling_words_views.dart`, а не общий код** — правило 5
/// «Архитектурного закона». Дословно скопированы `GameHud`, `RevealPair`,
/// `SummaryView`, `EndButton`, `NothingTodayView` и весь блок тона поля;
/// своё здесь — `NinjaField` и `FlyingObject`. Список копируемого лежит в
/// плане Фазы 4: это кандидаты в общее, которые выделит третья игра.
///
/// Читаемость под давлением — требование, а не вкусовщина: размеры берутся
/// из `textTheme` и переживают системное увеличение шрифта, а верный и
/// неверный рез различимы иконкой, не только цветом (дальтонизм — 8%
/// мужчин).
library;

import 'package:flutter/material.dart';

/// До этой серии поле чистое: ранний тон был бы шумом, а не наградой.
const int comboTintStart = 2;

/// С этой серии тон больше не густеет.
const int comboTintEnd = 8;

/// Насколько глубоко поле уходит к `primary` на потолке.
const double comboTintMax = 0.35;

/// Сколько переливается поле при смене серии.
const Duration comboTintFade = Duration(milliseconds: 400);

/// Доля высоты поля, на которой тон сходит к фону у каждого края.
const double comboGradientEdge = 0.22;

/// Тон поля по длине серии.
///
/// Единственная функция джуса, которой нужна палитра, — поэтому она здесь,
/// а не в `ninja_slash_juice.dart`: иначе Flutter приехал бы вместе с ней и
/// в `NinjaRun`, который держится без него намеренно.
Color comboTint(ColorScheme scheme, int combo) => throw UnimplementedError();

/// Загорелась ли серия — то есть видно ли уже тон на поле.
///
/// Одна функция на два ответа: подкрашивать ли поле и гореть ли множителю в
/// HUD. Порог живёт здесь и нигде больше, поэтому разъехаться они не могут
/// даже случайно.
bool comboIsHot(int combo) => throw UnimplementedError();

/// Тон поля по длине серии — вертикальным градиентом, а не заливкой.
LinearGradient comboGradient(ColorScheme scheme, int combo) =>
    throw UnimplementedError();

/// Тот же градиент, но от готового горячего цвета.
LinearGradient comboGradientFor(ColorScheme scheme, Color hot) =>
    throw UnimplementedError();

/// Ключи частей экрана.
abstract final class NinjaKeys {
  /// Английское слово наверху поля.
  static const Key word = Key('ninja_slash.word');

  /// Верный перевод в паре, которая показывается на промахе и таймауте.
  static const Key revealAnswer = Key('ninja_slash.reveal_answer');

  static const Key score = Key('ninja_slash.score');

  static const Key combo = Key('ninja_slash.combo');

  /// «сколько показано / сколько запланировано».
  static const Key progress = Key('ninja_slash.progress');

  /// Поле волны вместе с его фоном. По нему тест читает тон серии.
  static const Key playfield = Key('ninja_slash.playfield');

  /// Слой объектов целиком. По нему тест меряет тряску: сами объекты
  /// ездят по параболам, и их сдвиг от тряски не отличить от полёта.
  static const Key objects = Key('ninja_slash.objects');

  static const Key summary = Key('ninja_slash.summary');

  /// Строка под статистикой итогов; её текст считает хост.
  static const Key summaryFooter = Key('ninja_slash.summary_footer');

  static const Key playAgain = Key('ninja_slash.play_again');

  static const Key exit = Key('ninja_slash.exit');

  static const Key nothingToday = Key('ninja_slash.nothing_today');

  /// Объект волны номер [index] — по нему тест читает его позицию.
  static Key objectAt(int index) => ValueKey('ninja_slash.object.$index');
}

/// Как выглядит объект волны. Различие между [correct] и [wrong] — не
/// только цвет: у каждого ещё иконка.
enum ObjectState {
  /// В полёте, режется.
  idle,

  /// Верно разрезанный.
  correct,

  /// Разрезанный по ошибке.
  wrong,

  /// Остальные в фазе подсветки: приглушены, чтобы не спорить за внимание.
  dimmed,
}

/// Один объект волны: перевод и то, что с ним случилось.
typedef WaveObject = ({String label, ObjectState state});

/// Счётчики поверх поля: жизни, прогресс, серия, счёт.
///
/// [Wrap], а не [Row]: при системном шрифте вдвое крупнее четыре счётчика в
/// строку не помещаются, и перенос честнее обрезания.
class GameHud extends StatelessWidget {
  const GameHud({
    required this.lives,
    required this.maxLives,
    required this.score,
    required this.multiplier,
    required this.current,
    required this.total,
    required this.combo,
    super.key,
    this.scorePulse = 0,
  });

  final int lives;
  final int maxLives;
  final int score;

  /// На что умножатся очки за следующий верный рез — не длина серии: «×0»
  /// на старте обещало бы ноль очков за рез, который даёт десять.
  final int multiplier;

  /// Какое по счёту слово показывается сейчас.
  final int current;

  /// Сколько показов запланировала сессия.
  final int total;

  /// Длина серии — не то же, что [multiplier]: множитель загорается на том
  /// же пороге, что и тон поля, а порог задан по серии.
  final int combo;

  /// Насколько раздут счёт в этом кадре, 0…1. Ноль — обычный размер.
  final double scorePulse;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Один объект волны — круг с переводом внутри.
class FlyingObject extends StatelessWidget {
  const FlyingObject({required this.label, required this.state, super.key});

  final String label;
  final ObjectState state;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Поле волны: слово наверху, объекты на параболах.
///
/// [progress] — доля полёта: 0 — объекты под нижней кромкой, 0.5 — в
/// апексах, 1 — снова под кромкой. Позиции считает `wavePositions`, та же
/// функция, по которой игра проверяет попадание реза: рисовать одно, а
/// резать другое здесь невозможно по построению.
class NinjaField extends StatelessWidget {
  const NinjaField({
    required this.word,
    required this.objects,
    required this.progress,
    super.key,
    this.faded = false,
  });

  /// Английское слово наверху.
  final String word;

  /// Объекты волны в порядке дорожек; пустой список — взвод.
  final List<WaveObject> objects;

  final double progress;

  /// Стоп-кадр промаха: объекты гаснут, чтобы пара по центру читалась.
  final bool faded;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Связка «слово → перевод» на промахе и таймауте.
///
/// Стоит по центру поля. Это единственный момент, когда человек чему-то
/// учится, и связка обязана читаться одним взглядом.
class RevealPair extends StatelessWidget {
  const RevealPair({required this.word, required this.answer, super.key});

  final String word;
  final String answer;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Итоги партии.
class SummaryView extends StatelessWidget {
  const SummaryView({
    required this.score,
    required this.bestCombo,
    required this.correctCount,
    required this.answeredCount,
    required this.outOfLives,
    required this.onPlayAgain,
    required this.onExit,
    super.key,
    this.footer,
  });

  final int score;
  final int bestCombo;
  final int correctCount;
  final int answeredCount;

  /// Партия оборвана жизнями, а не исчерпанной очередью.
  final bool outOfLives;

  /// Текст «что дальше» от хоста; null — строки нет.
  final String? footer;

  final VoidCallback onPlayAgain;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Кнопка на экране конца партии.
class EndButton extends StatelessWidget {
  const EndButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.primary = true,
  });

  final String label;
  final VoidCallback onPressed;

  /// Главное действие экрана; остальные — тише.
  final bool primary;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Сессия не дала ни одного слова.
class NothingTodayView extends StatelessWidget {
  const NothingTodayView({required this.onExit, super.key});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
