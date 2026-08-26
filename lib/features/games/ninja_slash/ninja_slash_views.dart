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

import 'dart:math';

import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

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
  final depth = ((combo - comboTintStart) / (comboTintEnd - comboTintStart))
      .clamp(0.0, 1.0);
  return Color.lerp(scheme.surface, scheme.primary, comboTintMax * depth)!;
}

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
    final (
      Color background,
      Color foreground,
      IconData? icon,
    ) = switch (state) {
      ObjectState.idle || ObjectState.dimmed => (
        scheme.surfaceContainerHighest,
        scheme.onSurface,
        null,
      ),
      ObjectState.correct => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.check,
      ),
      ObjectState.wrong => (
        scheme.errorContainer,
        scheme.onErrorContainer,
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
          border: Border.all(
            color: icon == null ? Colors.transparent : foreground,
            width: icon == null ? 0 : 3,
          ),
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
                        child: FlyingObject(
                          key: NinjaKeys.objectAt(i),
                          label: objects[i].label,
                          state: objects[i].state,
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

/// Толщина следа свайпа.
const double trailWidth = 4;

/// На сколько расходятся половинки разрезанного объекта.
const double halfSpread = 24;

/// Сколько искр даёт рез.
const int sparkCount = 8;

/// Радиус искры.
const double sparkRadius = 3;

/// Ближняя и дальняя граница разлёта искр.
const double sparkMinReach = 40;
const double sparkMaxReach = 70;

/// Восемь искр из точки реза: направление и дальность.
///
/// Круг делится на [sparkCount] секторов, и внутри сектора направление
/// гуляет: ровные восемь лучей читаются как нарисованная звёздочка, а не
/// как брызги. [random] сидирован — без этого голден не снять.
List<Offset> sparkBurst(Random random) => throw UnimplementedError();

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

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// След свайпа: ломаная по точкам жеста, гаснущая за подсветку.
class SliceTrail extends StatelessWidget {
  const SliceTrail({required this.points, required this.progress, super.key});

  /// Точки жеста в координатах поля.
  final List<Offset> points;

  /// Доля подсветки, 0…1: на единице следа уже нет.
  final double progress;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Разрезанный объект: две половинки, расходящиеся перпендикулярно линии
/// реза.
class SlicedObject extends StatelessWidget {
  const SlicedObject({
    required this.label,
    required this.state,
    required this.angle,
    required this.progress,
    super.key,
  });

  final String label;
  final ObjectState state;

  /// Направление реза в радианах: по нему делится круг.
  final double angle;

  /// Доля подсветки, 0…1.
  final double progress;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
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

  /// Смещение каждой искры на полном разлёте.
  final List<Offset> sparks;

  /// Доля подсветки, 0…1.
  final double progress;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
