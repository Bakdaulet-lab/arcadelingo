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

import 'falling_words_run.dart';

/// Ключи частей экрана. Тест ищет по ним то, что не опознать по тексту:
/// падающее слово (текст у него меняется каждый раунд) и счётчики HUD.
abstract final class FallingWordsKeys {
  /// Падающее слово. По нему же тест меряет, сдвинулось ли оно.
  static const Key word = Key('falling_words.word');

  static const Key score = Key('falling_words.score');

  static const Key combo = Key('falling_words.combo');

  /// «сколько показано / сколько запланировано».
  static const Key progress = Key('falling_words.progress');

  static const Key summary = Key('falling_words.summary');

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
          Text(
            '$score',
            key: FallingWordsKeys.score,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// Поле, по которому падает слово.
///
/// [progress] — доля прожитого времени: 0 — слово вверху, 1 — коснулось
/// низа. [revealProgress] нужен только верному ответу: слово растёт и
/// растворяется.
class FallingField extends StatelessWidget {
  const FallingField({
    required this.text,
    required this.progress,
    required this.verdict,
    required this.revealProgress,
    super.key,
  });

  final String text;
  final double progress;
  final Verdict? verdict;
  final double revealProgress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = verdict == Verdict.wrong || verdict == Verdict.timeout;
    Widget word = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (failed) ...[
          Icon(Icons.close, color: scheme.error, size: 32),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            text,
            key: FallingWordsKeys.word,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: failed ? scheme.error : scheme.onSurface,
            ),
          ),
        ),
      ],
    );
    if (verdict == Verdict.correct) {
      word = Opacity(
        opacity: (1 - revealProgress).clamp(0.0, 1.0),
        child: Transform.scale(scale: 1 + 0.3 * revealProgress, child: word),
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
                  Icon(icon, color: foreground, size: 24),
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

/// Итоги партии.
class SummaryView extends StatelessWidget {
  const SummaryView({
    required this.score,
    required this.bestCombo,
    required this.correctCount,
    required this.answeredCount,
    super.key,
  });

  final int score;
  final int bestCombo;
  final int correctCount;
  final int answeredCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: FallingWordsKeys.summary,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Раунд окончен', style: textTheme.headlineMedium),
            const SizedBox(height: 24),
            Text('Счёт: $score', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Лучшая серия: $bestCombo', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Верных ответов: $correctCount из $answeredCount',
              style: textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}

/// Сессия не дала ни одного слова.
///
/// Это награда, а не ошибка: слова на сегодня кончились, потому что
/// человек их повторил.
class NothingTodayView extends StatelessWidget {
  const NothingTodayView({super.key});

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
          ],
        ),
      ),
    );
  }
}
