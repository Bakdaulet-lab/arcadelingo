/// Части экрана игры «падающие слова» и ключи, по которым их находят
/// тесты и голдены.
///
/// Здесь нет ни таймеров, ни состояния: всё, что видно, приходит
/// параметрами. Так экран можно собрать в голдене на любой момент партии,
/// не проигрывая её.
///
/// Читаемость под давлением — требование, а не вкусовщина: размеры берутся
/// из `textTheme` и переживают системное увеличение шрифта, а верный и
/// неверный ответ различимы иконкой, не только цветом (дальтонизм — 8%
/// мужчин).
library;

import 'package:flutter/material.dart';

import 'falling_words_juice.dart';

/// До этой серии фон чистый: ранний тон был бы шумом, а не наградой.
const int comboTintStart = 2;

/// С этой серии тон больше не густеет.
const int comboTintEnd = 8;

/// Насколько глубоко фон уходит к `primaryContainer` на потолке. Выше —
/// `onSurface` на подкрашенном фоне уходит под контраст 4.5:1, а он в
/// тестах уже стоит (`textContrastGuideline`).
const double comboTintMax = 0.35;

/// Сколько переливается фон при смене серии.
const Duration comboTintFade = Duration(milliseconds: 400);

/// Тон фона по длине серии.
///
/// Единственная функция джуса, которой нужна палитра, — поэтому она здесь,
/// а не в `falling_words_juice.dart`: иначе Flutter приехал бы вместе с ней
/// и в `FallingWordsRun`, который держится без него намеренно.
Color comboTint(ColorScheme scheme, int combo) {
  final depth = ((combo - comboTintStart) / (comboTintEnd - comboTintStart))
      .clamp(0.0, 1.0);
  // Ранний выход, а не lerp с нулём: чистый фон обязан быть тем же самым
  // цветом, что и surface, иначе «фон не тронут» пришлось бы проверять с
  // допуском, и настоящий блёклый тон прошёл бы под такой допуск.
  if (depth == 0) return scheme.surface;
  return Color.lerp(scheme.surface, scheme.primary, comboTintMax * depth)!;
}

/// Ключи частей экрана. Тест ищет по ним то, что не опознать по тексту:
/// падающее слово (текст у него меняется каждый раунд) и счётчики HUD.
abstract final class FallingWordsKeys {
  /// Падающее слово. По нему же тест меряет, сдвинулось ли оно.
  static const Key word = Key('falling_words.word');

  /// Верный перевод в паре, которая показывается на промахе и таймауте.
  static const Key revealAnswer = Key('falling_words.reveal_answer');

  static const Key score = Key('falling_words.score');

  static const Key combo = Key('falling_words.combo');

  /// «сколько показано / сколько запланировано».
  static const Key progress = Key('falling_words.progress');

  /// Поле падения вместе с его фоном. По нему тест читает тон серии.
  static const Key playfield = Key('falling_words.playfield');

  /// Ряд кнопок ответа целиком. По нему тест меряет тряску: сами кнопки
  /// находятся по тексту, а ряд — единственное, что можно померить, не
  /// зная, какой из вариантов куда попал.
  static const Key answers = Key('falling_words.answers');

  /// Летящий к счёту прирост очков.
  static const Key scorePop = Key('falling_words.score_pop');

  /// Метка «×1.5» рядом с приростом.
  static const Key nearMissBadge = Key('falling_words.near_miss_badge');

  static const Key summary = Key('falling_words.summary');

  /// Строка под статистикой итогов; её текст считает хост.
  static const Key summaryFooter = Key('falling_words.summary_footer');

  /// «Ещё раз» — новую сессию строит хост, не игра.
  static const Key playAgain = Key('falling_words.play_again');

  /// «Выйти» — есть и на итогах, и на «на сегодня всё».
  static const Key exit = Key('falling_words.exit');

  static const Key nothingToday = Key('falling_words.nothing_today');
}

/// Как выглядит кнопка ответа. Различие между [correct] и [wrong] —
/// не только цвет: у каждой ещё иконка.
enum AnswerState {
  /// Обычная, нажимаемая.
  idle,

  /// Верный вариант в фазе подсветки.
  correct,

  /// Ошибочно нажатая.
  wrong,

  /// Остальные в фазе подсветки: приглушены, чтобы не спорить за внимание.
  dimmed,
}

/// Счётчики поверх поля: жизни, прогресс, серия, счёт.
///
/// [Wrap], а не [Row]: при системном шрифте вдвое крупнее четыре счётчика
/// в строку не помещаются, и перенос честнее обрезания.
class GameHud extends StatelessWidget {
  const GameHud({
    required this.lives,
    required this.maxLives,
    required this.score,
    required this.multiplier,
    required this.current,
    required this.total,
    super.key,
    this.scorePulse = 0,
  });

  final int lives;
  final int maxLives;
  final int score;

  /// На что умножатся очки за следующий верный ответ — не длина серии:
  /// «×0» на старте обещало бы ноль очков за ответ, который даёт десять.
  final int multiplier;

  /// Какое по счёту слово показывается сейчас.
  final int current;

  /// Сколько показов запланировала сессия.
  final int total;

  /// Насколько раздут счёт в этом кадре, 0…1. Ноль — обычный размер.
  /// Украшение: при системном «убрать анимации» сюда приходит ноль всегда.
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
            key: FallingWordsKeys.progress,
            style: textTheme.titleMedium,
          ),
          Text(
            '×$multiplier',
            key: FallingWordsKeys.combo,
            style: textTheme.titleMedium,
          ),
          // Transform, а не изменение кегля: раздувание размером сдвинуло бы
          // соседние счётчики, и HUD дёргался бы на каждом верном ответе.
          Transform.scale(
            scale: 1 + 0.25 * scorePulse.clamp(0.0, 1.0),
            child: Text(
              '$score',
              key: FallingWordsKeys.score,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Поле, по которому падает слово.
///
/// [progress] — доля прожитого времени: 0 — слово вверху, 1 — коснулось
/// низа. [fadeProgress] — рассыпание верного ответа: слово растёт и
/// растворяется. Промах и таймаут сюда не приходят, там поле занимает
/// [RevealPair].
class FallingField extends StatelessWidget {
  const FallingField({
    required this.text,
    required this.progress,
    required this.fadeProgress,
    super.key,
  });

  final String text;
  final double progress;
  final double fadeProgress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget word = Text(
      text,
      key: FallingWordsKeys.word,
      textAlign: TextAlign.center,
      maxLines: 2,
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: scheme.onSurface,
      ),
    );
    if (fadeProgress > 0) {
      word = Opacity(
        opacity: (1 - fadeProgress).clamp(0.0, 1.0),
        child: Transform.scale(scale: 1 + 0.3 * fadeProgress, child: word),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment(0, -1 + 2 * progress.clamp(0.0, 1.0)),
        child: word,
      ),
    );
  }
}

/// Связка «слово → перевод» на промахе и таймауте.
///
/// Занимает всё поле и стоит по центру. Это единственный момент, когда
/// человек чему-то учится, и связка обязана читаться одним взглядом:
/// подсветка одной из кнопок внизу требовала саккады через две трети
/// экрана и обратно, а времени на всё 800 мс (SPEC, «Механика»).
///
/// Столбцом, а не строкой: девятибуквенный перевод рядом с английским
/// словом при системном шрифте 2× в ширину телефона не помещается.
class RevealPair extends StatelessWidget {
  const RevealPair({required this.word, required this.answer, super.key});

  final String word;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(
      context,
    ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold);
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
                    key: FallingWordsKeys.word,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: style?.copyWith(color: scheme.error),
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
              key: FallingWordsKeys.revealAnswer,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: style?.copyWith(color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Кнопка с вариантом перевода.
class AnswerButton extends StatelessWidget {
  const AnswerButton({
    required this.label,
    required this.state,
    super.key,
    this.onTap,
  });

  final String label;
  final AnswerState state;

  /// null в фазе подсветки: тап уже не считается.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (
      Color background,
      Color foreground,
      IconData? icon,
    ) = switch (state) {
      AnswerState.idle || AnswerState.dimmed => (
        scheme.surfaceContainerHighest,
        scheme.onSurface,
        null,
      ),
      AnswerState.correct => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.check,
      ),
      AnswerState.wrong => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.close,
      ),
    };
    final radius = BorderRadius.circular(12);
    return Opacity(
      opacity: state == AnswerState.dimmed ? 0.5 : 1,
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: icon == null ? Colors.transparent : foreground,
                width: icon == null ? 0 : 3,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: foreground,
                    size: 24,
                    applyTextScaling: true,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Прирост очков, улетающий к счётчику.
///
/// Летит внутри поля падения, а не поверх всего экрана. Так стартовая точка
/// — в точности место, где стояло слово, и её не приходится пересчитывать
/// между двумя системами координат; финиш — верхний правый угол поля, ровно
/// под счётом в HUD. Точность здесь важнее пары лишних пикселей полёта:
/// «+N», вылетающий не оттуда, где было слово, читается как посторонний
/// элемент.
///
/// Счёт в HUD к этому моменту уже правдив. Полёт — украшение над числом, а
/// не способ его узнать: при системном «убрать анимации» его нет вовсе.
class ScorePop extends StatelessWidget {
  const ScorePop({
    required this.points,
    required this.from,
    required this.progress,
    required this.nearMiss,
    super.key,
  });

  /// Сколько очков принёс ответ. Прирост, а не весь счёт.
  final int points;

  /// Где стояло слово: доля пути сверху вниз, 0…1.
  final double from;

  /// Доля полёта, 0…1.
  final double progress;

  /// Показать ли метку множителя рядом с приростом.
  final bool nearMiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final flown = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final start = Alignment(0, -1 + 2 * from.clamp(0.0, 1.0));
    // Растворяется на последней трети пути: раньше — не успеть прочитать,
    // позже — «+N» доживёт до следующего слова.
    final fade = ((1 - progress) / 0.35).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Align(
        alignment: Alignment.lerp(start, Alignment.topRight, flown)!,
        child: Opacity(
          opacity: fade,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '+$points',
                key: FallingWordsKeys.scorePop,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              if (nearMiss) ...[
                const SizedBox(width: 6),
                Text(
                  // Множитель берётся из тех же констант, что и начисление:
                  // метка, разошедшаяся с арифметикой, — обман в чистом виде.
                  '×${nearMissBonusNumerator / nearMissBonusDenominator}',
                  key: FallingWordsKeys.nearMissBadge,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.tertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Итоги партии.
///
/// [footer] — строка «что дальше», её считает хост: остались ли слова к
/// повторению, знает он, а не игра. Игра про размер сессии (`target`)
/// ничего не знает по SPEC и обещать «возвращайся завтра» от своего имени
/// не может.
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

  /// Партия оборвана жизнями, а не исчерпанной очередью. Заголовок разный:
  /// пройденная сессия и проигранная — разные исходы, и одинаковое
  /// «Раунд окончен» на обоих скрывало бы, что именно случилось.
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
    // заголовок, три строки статистики, строка хоста и две кнопки занимают
    // 779 dp — на 360×780 впритык, на 360×640 переполнение. Пока содержимое
    // помещается, Center держит его по центру, как и раньше.
    return Center(
      key: FallingWordsKeys.summary,
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
                key: FallingWordsKeys.summaryFooter,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 32),
            EndButton(
              key: FallingWordsKeys.playAgain,
              label: 'Ещё раз',
              onPressed: onPlayAgain,
            ),
            const SizedBox(height: 8),
            EndButton(
              key: FallingWordsKeys.exit,
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
///
/// Столбцом друг под другом, а не в строку: при системном шрифте 2× две
/// кнопки рядом в ширину телефона не помещаются. Высота 56 — тот же
/// минимум, что у кнопок ответа, и он же покрывает требование к размеру
/// цели нажатия.
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
///
/// Это награда, а не ошибка: слова на сегодня кончились, потому что
/// человек их повторил.
/// Кнопки «Ещё раз» здесь нет намеренно: сессия не дала ни одного слова, и
/// переигрывать нечего — вторая попытка дала бы этот же экран.
class NothingTodayView extends StatelessWidget {
  const NothingTodayView({required this.onExit, super.key});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      key: FallingWordsKeys.nothingToday,
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
            EndButton(
              key: FallingWordsKeys.exit,
              label: 'Выйти',
              onPressed: onExit,
            ),
          ],
        ),
      ),
    );
  }
}
