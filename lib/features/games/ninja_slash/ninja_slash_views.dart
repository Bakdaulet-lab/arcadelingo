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
/// своё здесь — `NinjaField`, `FlyingObject` и весь блок украшений реза.
/// Список копируемого лежит в плане Фазы 4: это кандидаты в общее, которые
/// выделит третья игра.
///
/// Физика украшений — в `ninja_slash_fx.dart`; здесь только краска.
///
/// Читаемость под давлением — требование, а не вкусовщина: размеры берутся
/// из `textTheme` и переживают системное увеличение шрифта, а верный и
/// неверный рез различимы иконкой, не только цветом (дальтонизм — 8%
/// мужчин).
library;

import 'dart:math';

import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

import 'ninja_slash_fx.dart';
import 'ninja_slash_juice.dart';
import 'ninja_trajectory.dart';

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

/// Альфа подсветки верха поля на чистой серии и на потолке.
const double topLightMin = 0.10;
const double topLightMax = 0.24;

/// До какой доли высоты подсветка верха сходит к нулю. Ровно там, где
/// начинается полоса тона: сложись они, на потолке серии смешение к
/// `primary` перевалило бы за 0.45, где `onSurface` теряет 4.5:1.
const double topLightSpan = comboGradientEdge;

/// С какой доли высоты низ поля темнеет и до какой альфы у кромки.
const double bottomDarkFrom = 0.55;
const double bottomDarkAlpha = 0.5;

/// Виньетка: альфа по углам и радиус, до которого её нет.
const double vignetteAlpha = 0.45;
const double vignetteInner = 0.65;

/// Альфа подсветки верха по длине серии: от [topLightMin] до [topLightMax]
/// по той же шкале, что и тон поля.
double topLightAlpha(int combo) =>
    topLightMin + (topLightMax - topLightMin) * comboDepth(combo);

/// Тон поля по длине серии.
///
/// Единственная функция джуса, которой нужна палитра, — поэтому она здесь,
/// а не в `ninja_slash_juice.dart`: иначе Flutter приехал бы вместе с ней и
/// в `NinjaRun`, который держится без него намеренно.
Color comboTint(ColorScheme scheme, int combo) {
  // Ранний выход, а не lerp с нулём: чистое поле обязано быть тем же самым
  // цветом, что и surface, иначе «поле не тронуто» пришлось бы проверять с
  // допуском, и настоящий блёклый тон прошёл бы под такой допуск.
  if (!comboIsHot(combo)) return scheme.surface;
  return Color.lerp(
    scheme.surface,
    scheme.primary,
    comboTintMax * comboDepth(combo),
  )!;
}

/// Насколько разогрета серия, 0…1: ноль до порога, единица на потолке.
///
/// Одна шкала на тон поля и на подсветку верха: две шкалы разошлись бы в
/// день, когда кто-то подвинет один порог.
double comboDepth(int combo) =>
    ((combo - comboTintStart) / (comboTintEnd - comboTintStart)).clamp(
      0.0,
      1.0,
    );

/// Загорелась ли серия — то есть видно ли уже тон на поле.
///
/// Одна функция на два ответа: подкрашивать ли поле и гореть ли множителю в
/// HUD. Порог живёт здесь и нигде больше, поэтому разъехаться они не могут
/// даже случайно.
bool comboIsHot(int combo) => combo > comboTintStart;

/// Тон поля по длине серии — вертикальным градиентом, а не заливкой.
LinearGradient comboGradient(ColorScheme scheme, int combo) =>
    comboGradientFor(scheme, comboTint(scheme, combo));

/// Тот же градиент, но от готового горячего цвета.
LinearGradient comboGradientFor(ColorScheme scheme, Color hot) =>
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [scheme.surface, hot, hot, scheme.surface],
      stops: [0, comboGradientEdge, 1 - comboGradientEdge, 1],
    );

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

  /// Летящий к счёту прирост очков.
  static const Key scorePop = Key('ninja_slash.score_pop');

  /// Метка «×1.5» рядом с приростом.
  static const Key nearMissBadge = Key('ninja_slash.near_miss_badge');

  /// След свайпа.
  static const Key trail = Key('ninja_slash.trail');

  /// Искры из точки реза.
  static const Key sparks = Key('ninja_slash.sparks');

  /// Кольцо-вспышка в точке удара.
  static const Key flash = Key('ninja_slash.flash');

  /// Подсветка, затемнение и виньетка поля.
  static const Key fieldLight = Key('ninja_slash.field_light');

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
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          Semantics(
            label: 'Жизни: $lives из $maxLives',
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < maxLives; i++)
                  Icon(
                    i < lives ? Icons.favorite : Icons.favorite_border,
                    color: i < lives ? scheme.error : scheme.outline,
                    size: 24,
                    applyTextScaling: true,
                  ),
              ],
            ),
          ),
          Text(
            '$current/$total',
            key: NinjaKeys.progress,
            style: textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Text(
            '×$multiplier',
            key: NinjaKeys.combo,
            style: textTheme.titleMedium?.copyWith(
              color:
                  comboIsHot(combo) ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
          // Transform, а не изменение кегля: раздувание размером сдвинуло бы
          // соседние счётчики, и HUD дёргался бы на каждом верном резе.
          Transform.scale(
            scale: 1 + 0.25 * scorePulse.clamp(0.0, 1.0),
            child: Text(
              '$score',
              key: NinjaKeys.score,
              style: withWeight(textTheme.titleLarge!, FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Один объект волны — круг с переводом внутри.
class FlyingObject extends StatelessWidget {
  const FlyingObject({required this.label, required this.state, super.key});

  final String label;
  final ObjectState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Пары те же, что у кнопок падающих слов: контраст у них уже замерен, и
    // заводить вторую палитру ради круглой формы было бы не решением, а
    // риском.
    // Обод — второй акцент: без него объект в полёте был серым кругом на
    // тёмном поле, и вердикт «серо, нет красок» был именно про это. На
    // разрезанном обод и свечение берут цвет вердикта.
    final (
      Color background,
      Color foreground,
      Color rim,
      IconData? icon,
    ) = switch (state) {
      ObjectState.idle || ObjectState.dimmed => (
        scheme.surfaceContainerHighest,
        scheme.onSurface,
        scheme.tertiary.withValues(alpha: 0.75),
        null,
      ),
      ObjectState.correct => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        scheme.primary,
        Icons.check,
      ),
      ObjectState.wrong => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        scheme.error,
        Icons.close,
      ),
    };
    return Opacity(
      opacity: state == ObjectState.dimmed ? 0.5 : 1,
      child: Container(
        width: objectRadius * 2,
        height: objectRadius * 2,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: rim, width: icon == null ? 2 : 3),
          boxShadow: [
            BoxShadow(
              color: rim.withValues(alpha: icon == null ? 0.3 : 0.6),
              blurRadius: icon == null ? 10 : 16,
            ),
          ],
        ),
        // Содержимое обязано помещаться в круг: размер объекта — часть
        // геометрии реза, и растягиваться под перевод он не может. При
        // системном шрифте 2× две строки плюс иконка дают 80 dp на 68 dp
        // круга (замерено тестом), поэтому уменьшается всё целиком, как
        // полоса недели в стрик-карточке, а не ломается ряд.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: objectRadius * 2 - 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) Icon(icon, color: foreground, size: 18),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: withWeight(
                    Theme.of(context).textTheme.bodyMedium!,
                    FontWeight.bold,
                  ).copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    this.sliced,
    this.sliceAngle = 0,
    this.sliceProgress = 0,
    this.sliceVelocity = Offset.zero,
    this.tilts = const [],
    this.scale = 1,
  });

  /// Английское слово наверху.
  final String word;

  /// Объекты волны в порядке дорожек; пустой список — взвод.
  final List<WaveObject> objects;

  final double progress;

  /// Стоп-кадр промаха: объекты гаснут, чтобы пара по центру читалась.
  ///
  /// На нём же перестаёт рисоваться слово наверху: оно уже стоит в паре по
  /// центру, и два одинаковых слова на экране — это шум, а не подсказка.
  final bool faded;

  /// Дорожка разрезанного объекта; null — резать было нечего либо джус
  /// выключен, и тогда объект остаётся целым.
  final int? sliced;

  /// Направление реза в радианах.
  final double sliceAngle;

  /// Доля подсветки, по которой расходятся половинки.
  final double sliceProgress;

  /// Скорость полёта разрезанного объекта в момент реза — её наследуют
  /// половинки.
  final Offset sliceVelocity;

  /// Наклон каждого объекта в этом кадре, радианы; короче списка объектов
  /// — остальные стоят прямо.
  final List<double> tilts;

  /// Масштаб объектов в этом кадре: scale-pop при вылете.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final positions = wavePositions(
          count: objects.length,
          t: progress,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );
        return Stack(
          children: [
            if (!faded)
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Text(
                  word,
                  key: NinjaKeys.word,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: withWeight(
                    Theme.of(context).textTheme.displaySmall!,
                    FontWeight.bold,
                  ).copyWith(color: scheme.onSurface),
                ),
              ),
            Positioned.fill(
              key: NinjaKeys.objects,
              child: Opacity(
                // Гаснут, а не исчезают: стоп-кадр обязан остаться
                // стоп-кадром, но пара по центру читается поверх него.
                opacity: faded ? 0.25 : 1,
                child: Stack(
                  children: [
                    for (var i = 0; i < objects.length; i++)
                      Positioned(
                        left: positions[i].dx - objectRadius,
                        top: positions[i].dy - objectRadius,
                        // Поворот и масштаб — вокруг центра объекта, поэтому
                        // центр, по которому считается рез, не двигается:
                        // украшение не трогает геометрию.
                        child: Transform.rotate(
                          angle: i < tilts.length ? tilts[i] : 0,
                          child: Transform.scale(
                            scale: scale,
                            child:
                                i == sliced
                                    ? SlicedObject(
                                      key: NinjaKeys.objectAt(i),
                                      label: objects[i].label,
                                      state: objects[i].state,
                                      angle: sliceAngle,
                                      velocity: sliceVelocity,
                                      progress: sliceProgress,
                                    )
                                    : FlyingObject(
                                      key: NinjaKeys.objectAt(i),
                                      label: objects[i].label,
                                      state: objects[i].state,
                                    ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = withWeight(
      Theme.of(context).textTheme.displaySmall!,
      FontWeight.bold,
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.close,
                  color: scheme.error,
                  size: 32,
                  applyTextScaling: true,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    word,
                    key: NinjaKeys.word,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: style.copyWith(color: scheme.error),
                  ),
                ),
              ],
            ),
            Icon(
              Icons.arrow_downward,
              color: scheme.outline,
              size: 28,
              applyTextScaling: true,
            ),
            Text(
              answer,
              key: NinjaKeys.revealAnswer,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: style.copyWith(color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final note = footer;
    // Прокрутка, а не фиксированная колонка: при системном шрифте 2×
    // содержимое не помещается на 360×640. Пока помещается — Center держит
    // его по центру.
    return Center(
      key: NinjaKeys.summary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              outOfLives ? 'Жизни кончились' : 'Раунд окончен',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            Text('Счёт: $score', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Лучшая серия: $bestCombo', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Верных ответов: $correctCount из $answeredCount',
              style: textTheme.titleLarge,
            ),
            if (note != null) ...[
              const SizedBox(height: 16),
              Text(
                note,
                key: NinjaKeys.summaryFooter,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 32),
            EndButton(
              key: NinjaKeys.playAgain,
              label: 'Ещё раз',
              onPressed: onPlayAgain,
            ),
            const SizedBox(height: 8),
            EndButton(
              key: NinjaKeys.exit,
              label: 'Выйти',
              primary: false,
              onPressed: onExit,
            ),
          ],
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size(220, 56)),
      textStyle: WidgetStateProperty.all(
        Theme.of(context).textTheme.titleMedium,
      ),
    );
    final text = Text(label, textAlign: TextAlign.center);
    return primary
        ? FilledButton(onPressed: onPressed, style: style, child: text)
        : OutlinedButton(onPressed: onPressed, style: style, child: text);
  }
}

/// Сессия не дала ни одного слова.
class NothingTodayView extends StatelessWidget {
  const NothingTodayView({required this.onExit, super.key});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      key: NinjaKeys.nothingToday,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            Text('На сегодня всё', style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Слова к повторению кончились. Возвращайся завтра.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            EndButton(key: NinjaKeys.exit, label: 'Выйти', onPressed: onExit),
          ],
        ),
      ),
    );
  }
}

/// Прирост очков, улетающий к счётчику.
///
/// Летит внутри поля, а не поверх всего экрана: стартовая точка — в
/// точности место реза, и её не приходится пересчитывать между двумя
/// системами координат.
class ScorePop extends StatelessWidget {
  const ScorePop({
    required this.points,
    required this.from,
    required this.progress,
    required this.nearMiss,
    required this.hot,
    super.key,
  });

  /// Сколько очков принёс рез. Прирост, а не весь счёт.
  final int points;

  /// Откуда летит — точка реза в координатах поля.
  final Offset from;

  /// Доля полёта, 0…1.
  final double progress;

  /// Показать ли метку множителя рядом с приростом.
  final bool nearMiss;

  /// Серия горячая: «+N» крупнее и со свечением.
  final bool hot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final phase = progress.clamp(0.0, 1.0);
    // Растворяется на последней трети пути: раньше — не успеть прочитать,
    // позже — «+N» доживёт до следующей волны.
    final fade = ((1 - phase) / 0.35).clamp(0.0, 1.0);
    // На горячей серии — крупнее и со свечением: награда растёт вместе с
    // серией, а не только число в ней.
    final base = hot ? textTheme.headlineMedium! : textTheme.headlineSmall!;
    final style = withWeight(base, FontWeight.bold).copyWith(
      color: scheme.primary,
      shadows:
          hot
              ? [
                Shadow(
                  color: scheme.primary.withValues(alpha: 0.8),
                  blurRadius: 12,
                ),
              ]
              : null,
    );
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final finish = Offset(constraints.maxWidth - 24, 24);
          final at = Offset.lerp(from, finish, scorePopFlight(phase))!;
          return Stack(
            children: [
              Positioned(
                left: at.dx,
                top: at.dy,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -0.5),
                  child: Transform.scale(
                    scale: scorePopScale(phase),
                    child: Opacity(
                      opacity: fade,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '+$points',
                            key: NinjaKeys.scorePop,
                            style: style,
                          ),
                          if (nearMiss) ...[
                            const SizedBox(width: 6),
                            Text(
                              // Множитель берётся из тех же констант, что и
                              // начисление: метка, разошедшаяся с
                              // арифметикой, — обман в чистом виде.
                              '×${nearMissBonusNumerator / nearMissBonusDenominator}',
                              key: NinjaKeys.nearMissBadge,
                              style: withWeight(
                                textTheme.titleMedium!,
                                FontWeight.bold,
                              ).copyWith(color: scheme.tertiary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// След клинка: сглаженная кривая по точкам жеста, тающая с хвоста.
///
/// Точки приходят с отметками времени по часам полёта, [now] — те же часы
/// сейчас: что старше [trailLife], в след не попадает. Во время полёта
/// это живой жест, после реза — замороженный, и гаснут они одинаково.
class BladeTrail extends StatelessWidget {
  const BladeTrail({required this.points, required this.now, super.key});

  /// Точки жеста в координатах поля.
  final List<TrailPoint> points;

  /// Момент по часам полёта.
  final Duration now;

  @override
  Widget build(BuildContext context) {
    final samples = smoothTrail(trailAlive(points, now));
    if (samples.length < 2) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _BladePainter(
          samples: samples,
          glow: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _BladePainter extends CustomPainter {
  const _BladePainter({required this.samples, required this.glow});

  final List<TrailSample> samples;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    // Два слоя, потому что один даёт либо палку, либо туман: свечение —
    // широкое, полупрозрачное, размытое; ядро — узкое и раскалённо-белое.
    canvas.drawPath(
      _ribbon(trailGlowWidth),
      Paint()
        ..color = glow.withValues(alpha: trailGlowAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, trailGlowBlur),
    );
    canvas.drawPath(
      _ribbon(trailCoreWidth),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.95),
    );
  }

  /// Лента переменной ширины вдоль кривой: у каждой пробы по точке слева и
  /// справа на половине её ширины, контур замыкается через хвост.
  Path _ribbon(double widthScale) {
    final last = samples.length - 1;
    final left = <Offset>[];
    final right = <Offset>[];
    var normal = const Offset(0, 1);
    for (var k = 0; k <= last; k++) {
      final tangent = samples[min(k + 1, last)].at - samples[max(k - 1, 0)].at;
      if (tangent.distance > 0) {
        normal = Offset(-tangent.dy, tangent.dx) / tangent.distance;
      }
      final half =
          widthScale *
          trailWidthAt(freshness: samples[k].freshness, along: k / last) /
          2;
      left.add(samples[k].at + normal * half);
      right.add(samples[k].at - normal * half);
    }
    final path = Path()..moveTo(left.first.dx, left.first.dy);
    for (final point in left.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    for (final point in right.reversed) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_BladePainter old) =>
      old.samples != samples || old.glow != glow;
}

/// Разрезанный объект: две половинки, расходящиеся перпендикулярно линии
/// реза.
class SlicedObject extends StatelessWidget {
  const SlicedObject({
    required this.label,
    required this.state,
    required this.angle,
    required this.progress,
    this.velocity = Offset.zero,
    super.key,
  });

  final String label;
  final ObjectState state;

  /// Направление реза в радианах: по нему делится круг.
  final double angle;

  /// Доля подсветки, 0…1.
  final double progress;

  /// Скорость полёта в момент реза, dp/с: половинки её наследуют.
  final Offset velocity;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: objectRadius * 2,
    height: objectRadius * 2,
    // Без обрезки: половинки разлетаются за пределы круга, в котором жил
    // объект, — в том и смысл.
    child: Stack(clipBehavior: Clip.none, children: [_half(1), _half(-1)]),
  );

  /// Половинка [side]: смещение по нормали, унаследованная скорость,
  /// гравитация, поворот и прозрачность — всё из одной функции физики.
  Widget _half(double side) {
    final motion = halfMotion(
      side: side,
      angle: angle,
      velocity: velocity,
      phase: progress.clamp(0.0, 1.0),
    );
    return Transform.translate(
      offset: motion.offset,
      child: Transform.rotate(
        angle: motion.rotation,
        child: Opacity(
          opacity: motion.alpha,
          child: ClipPath(
            clipper: _HalfClipper(angle: angle, side: side),
            child: FlyingObject(label: label, state: state),
          ),
        ),
      ),
    );
  }
}

/// Половина круга по одну сторону от линии реза.
class _HalfClipper extends CustomClipper<Path> {
  const _HalfClipper({required this.angle, required this.side});

  final double angle;
  final double side;

  @override
  Path getClip(Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final along = Offset(cos(angle), sin(angle));
    final across = Offset(-along.dy, along.dx) * side;
    final far = size.longestSide * 2;
    final head = centre + along * far;
    final tail = centre - along * far;
    return Path()
      ..moveTo(head.dx, head.dy)
      ..lineTo(tail.dx, tail.dy)
      ..lineTo((tail + across * far).dx, (tail + across * far).dy)
      ..lineTo((head + across * far).dx, (head + across * far).dy)
      ..close();
  }

  @override
  bool shouldReclip(_HalfClipper old) => old.angle != angle || old.side != side;
}

/// Искры из точки реза.
class SparkBurst extends StatelessWidget {
  const SparkBurst({
    required this.origin,
    required this.sparks,
    required this.progress,
    super.key,
  });

  /// Точка реза в координатах поля.
  final Offset origin;

  /// Искры этого реза.
  final List<Spark> sparks;

  /// Доля жизни, 0…1.
  final double progress;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: Size.infinite,
      painter: _SparkPainter(
        origin: origin,
        sparks: sparks,
        accent: Theme.of(context).colorScheme.primary,
        phase: progress.clamp(0.0, 1.0),
      ),
    ),
  );
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter({
    required this.origin,
    required this.sparks,
    required this.accent,
    required this.phase,
  });

  final Offset origin;
  final List<Spark> sparks;
  final Color accent;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (phase >= 1) return;
    final alpha = sparkAlpha(phase);
    for (final spark in sparks) {
      // Каждая искра своего оттенка: акцент, подмешанный к белому на её долю
      // яркости. Один цвет на всех читался бы как один кружок, повторённый.
      final color =
          Color.lerp(accent, const Color(0xFFFFFFFF), spark.brightness)!;
      canvas.drawCircle(
        sparkPosition(spark, origin: origin, phase: phase),
        sparkSizeAt(spark, phase),
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.phase != phase || old.origin != origin || old.sparks != sparks;
}

/// Кольцо-ударная волна в точке удара.
class ImpactRing extends StatelessWidget {
  const ImpactRing({
    required this.origin,
    required this.progress,
    required this.color,
    super.key,
  });

  /// Точка удара в координатах поля.
  final Offset origin;

  /// Доля жизни кольца, 0…1.
  final double progress;

  /// `primary` на верном резе, `error` на промахе.
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: Size.infinite,
      painter: _RingPainter(
        origin: origin,
        phase: progress.clamp(0.0, 1.0),
        color: color,
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.origin,
    required this.phase,
    required this.color,
  });

  final Offset origin;
  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (phase >= 1) return;
    final radius = ringRadius(phase);
    final alpha = ringAlpha(phase);
    // Размытая копия под кольцом: удар без свечения читается как обводка,
    // а не как волна.
    canvas.drawCircle(
      origin,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringStroke(phase) * 3
        ..color = color.withValues(alpha: alpha * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      origin,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringStroke(phase)
        ..color = color.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.phase != phase || old.origin != origin || old.color != color;
}

/// Подсветка верха, затемнение низа и виньетка поля.
///
/// Это состояние, а не движение: под системным «убрать анимации» остаётся.
class FieldLighting extends StatelessWidget {
  const FieldLighting({required this.combo, super.key});

  /// Длина серии — от неё зависит альфа подсветки верха.
  final int combo;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: Size.infinite,
      painter: _LightingPainter(
        accent: Theme.of(context).colorScheme.primary,
        topAlpha: topLightAlpha(combo),
      ),
    ),
  );
}

class _LightingPainter extends CustomPainter {
  const _LightingPainter({required this.accent, required this.topAlpha});

  final Color accent;
  final double topAlpha;

  static const Color _black = Color(0xFF000000);
  static const Color _clear = Color(0x00000000);

  @override
  void paint(Canvas canvas, Size size) {
    // Верх — чуть подсвечен акцентом: поле перестаёт быть серым, а слово
    // наверху остаётся на тёмном. Сходит к нулю ровно там, где начинается
    // полоса тона серии, чтобы смешение к primary не складывалось.
    final top = Rect.fromLTWH(0, 0, size.width, size.height * topLightSpan);
    canvas.drawRect(
      top,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: topAlpha),
            accent.withValues(alpha: 0),
          ],
        ).createShader(top),
    );
    // Низ — глубже: объекты вылетают из темноты.
    final bottom = Rect.fromLTWH(
      0,
      size.height * bottomDarkFrom,
      size.width,
      size.height * (1 - bottomDarkFrom),
    );
    canvas.drawRect(
      bottom,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_clear, _black.withValues(alpha: bottomDarkAlpha)],
        ).createShader(bottom),
    );
    // Виньетка: центр остаётся чистым, углы уходят в черноту.
    final all = Offset.zero & size;
    canvas.drawRect(
      all,
      Paint()
        ..shader = RadialGradient(
          radius: 1.1,
          colors: [_clear, _black.withValues(alpha: vignetteAlpha)],
          stops: const [vignetteInner, 1],
        ).createShader(all),
    );
  }

  @override
  bool shouldRepaint(_LightingPainter old) =>
      old.topAlpha != topAlpha || old.accent != accent;
}
