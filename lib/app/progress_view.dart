/// Экран прогресса: сколько пройдено за всё время.
///
/// `ROADMAP.md` требует экран, «показывающий рост, а не только сегодняшний
/// счёт». Отсюда отбор: ни одного числа про сегодня — их человек видит на
/// домашнем экране, а сюда приходят посмотреть на пройденное. Что именно
/// показывается и почему — `SPEC.md`, раздел «Экран прогресса».
///
/// Первый потребитель журнала ответов. Данные читаются при открытии экрана, а
/// не при старте приложения: три запроса ради экрана, который открывают раз в
/// несколько дней, на каждом запуске — работа впустую.
library;

import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/ports/answer_log.dart';
import 'package:arcadelingo/domain/ports/card_store.dart';
import 'package:arcadelingo/domain/ports/streak_store.dart';
import 'package:arcadelingo/domain/progress/day_series.dart';
import 'package:arcadelingo/domain/progress/word_progress.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_page.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:arcadelingo/ui/streak_label.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

/// Ключи экрана: тест ищет по ним то, что не опознать по тексту.
abstract final class ProgressKeys {
  static const Key view = Key('progress.view');

  /// Приглашение вместо блоков, когда журнал пуст.
  static const Key empty = Key('progress.empty');

  static const Key words = Key('progress.words');
  static const Key answers = Key('progress.answers');
  static const Key days = Key('progress.days');

  /// Полоса ответов по дням.
  static const Key series = Key('progress.series');
}

/// Сколько дней показывает полоса, считая сегодняшний.
const int progressDays = 14;

/// Ширина столбика полосы, dp.
const double seriesBarWidth = 12;

/// Зазор между столбиками, dp.
const double seriesBarGap = 6;

/// Высота поля полосы, dp.
const double seriesHeight = 80;

/// Самый низкий видимый столбик: день с одним ответом обязан отличаться от
/// дня без единого.
const double seriesMinBar = 3;

/// Всё, что экрану нужно показать.
class ProgressData {
  const ProgressData({
    required this.words,
    required this.totals,
    required this.bestStreak,
    required this.series,
  });

  final WordCounts words;
  final AnswerTotals totals;
  final int bestStreak;

  /// Ровно [progressDays] дней в календарном порядке, включая пустые.
  final List<DayTally> series;

  /// Показывать нечего: журнал ещё ничего не видел.
  bool get isEmpty => totals.answers == 0;
}

/// Экран целиком: читает порты и отдаёт числа виду.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    required this.answers,
    required this.cards,
    required this.streaks,
    required this.now,
    this.onDictionary,
    super.key,
  });

  final AnswerLog answers;
  final CardStore cards;
  final StreakStore streaks;
  final DateTime Function() now;
  final VoidCallback? onDictionary;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  /// Future заводится один раз, а не в `build`: собранный в `build`, он
  /// пересоздавался бы на каждую перестройку, и экран моргал бы загрузкой
  /// при повороте или смене темы. Тот же приём, что в `AttributionScreen`.
  late final Future<ProgressData> _data = _load();

  Future<ProgressData> _load() async {
    final today = StreakDay.of(widget.now());
    var from = today;
    for (var i = 1; i < progressDays; i++) {
      from = from.previous;
    }
    final totals = await widget.answers.totals();
    final tallies = await widget.answers.perDay(from: from, to: today);
    // Битые документы прогресса до экрана не доходят: на тапе «Играть» они
    // уже дали бы экран ошибки. Здесь `Err` значит «показывать нечего», и
    // молчать об этом правильнее, чем ронять экран, открытый посмотреть.
    final Map<String, LeitnerCard> cards = switch (widget.cards.load()) {
      Ok(:final value) => value,
      Err() => const {},
    };
    final best = switch (widget.streaks.load()) {
      Ok(:final value) => value.best,
      Err() => 0,
    };
    return ProgressData(
      words: countWords(cards),
      totals: totals,
      bestStreak: best,
      series: fillDays(tallies: tallies, from: from, to: today),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<ProgressData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ProgressNotice(
            icon: Icons.sync_problem_rounded,
            title: context.strings.progressLoadFailed,
            message: context.strings.reopenProgress,
            error: true,
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  semanticsLabel: context.strings.loadingProgress,
                ),
                const SizedBox(height: 16),
                Text(context.strings.loadingProgress),
              ],
            ),
          );
        }
        return ProgressBody(data: data);
      },
    );
    return ArcadePage(
      title: context.strings.progress,
      child:
          widget.onDictionary == null
              ? content
              : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: OutlinedButton.icon(
                      onPressed: widget.onDictionary,
                      icon: const Icon(Icons.menu_book_rounded),
                      label: Text(
                        context.strings.personalDictionary,
                        textAlign: TextAlign.center,
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ),
                  Expanded(child: content),
                ],
              ),
    );
  }
}

/// Вид без единого обращения к хранилищу: всё приходит параметром.
class ProgressBody extends StatelessWidget {
  const ProgressBody({required this.data, super.key});

  final ProgressData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    if (data.isEmpty) {
      return _ProgressNotice(
        key: ProgressKeys.empty,
        icon: Icons.auto_graph_rounded,
        message: context.strings.firstRoundProgress,
      );
    }

    final accuracy = accuracyPercent(
      answers: data.totals.answers,
      correct: data.totals.correct,
    );

    return SingleChildScrollView(
      key: ProgressKeys.view,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.strings.allTime,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _Block(
            viewKey: ProgressKeys.words,
            title: context.strings.words,
            icon: Icons.school_rounded,
            accent: scheme.primary,
            rows: [
              (context.strings.learned, '${data.words.learned}'),
              (context.strings.learning, '${data.words.learning}'),
              (context.strings.hardWords, '${data.words.hard}'),
            ],
          ),
          const SizedBox(height: 16),
          ArcadePanel(
            accent: scheme.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PanelHeading(
                  title: context.strings.twoWeeks,
                  icon: Icons.bar_chart_rounded,
                  accent: scheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  context.strings.answersByDay,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                _Series(days: data.series),
                if (data.series.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _dateLabel(context, data.series.first.day),
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _dateLabel(context, data.series.last.day),
                          textAlign: TextAlign.end,
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Block(
            viewKey: ProgressKeys.answers,
            title: context.strings.answers,
            icon: Icons.check_circle_outline_rounded,
            accent: const Color(0xFFBFA2FF),
            rows: [
              (context.strings.total, '${data.totals.answers}'),
              if (accuracy != null)
                (context.strings.correctCount, '$accuracy%'),
            ],
          ),
          const SizedBox(height: 16),
          _Block(
            viewKey: ProgressKeys.days,
            title: context.strings.days,
            icon: Icons.local_fire_department_rounded,
            accent: scheme.tertiary,
            rows: [
              (context.strings.daysWithAnswers, '${data.totals.days}'),
              (
                context.strings.bestStreak,
                '${data.bestStreak} ${dayWord(data.bestStreak)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressNotice extends StatelessWidget {
  const _ProgressNotice({
    required this.icon,
    required this.message,
    super.key,
    this.title,
    this.error = false,
  });

  final IconData icon;
  final String? title;
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = error ? theme.colorScheme.error : theme.colorScheme.primary;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ArcadePanel(
          accent: accent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, size: 48, color: accent),
              ),
              const SizedBox(height: 24),
              if (title case final heading?) ...[
                Text(
                  heading,
                  textAlign: TextAlign.center,
                  style: withWeight(
                    theme.textTheme.headlineSmall!,
                    FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.viewKey,
    required this.title,
    required this.icon,
    required this.accent,
    required this.rows,
  });

  final Key viewKey;
  final String title;
  final IconData icon;
  final Color accent;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return ArcadePanel(
      key: viewKey,
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeading(title: title, icon: icon, accent: accent),
          const SizedBox(height: 16),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _MetricRow(label: label, value: value, accent: accent),
            ),
        ],
      ),
    );
  }
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading({
    required this.title,
    required this.icon,
    required this.accent,
  });

  final String title;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 22, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: withWeight(theme.textTheme.titleLarge!, FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
    final labelText = Text(
      label,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final valueText = Text(
      value,
      textAlign: TextAlign.end,
      style: withWeight(
        theme.textTheme.titleLarge!,
        FontWeight.bold,
      ).copyWith(color: accent),
    );

    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            largeText
                ? [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        labelText,
                        const SizedBox(height: 6),
                        valueText,
                      ],
                    ),
                  ),
                ]
                : [
                  Expanded(flex: 3, child: labelText),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: valueText),
                ],
      ),
    );
  }
}

String _dateLabel(BuildContext context, StreakDay day) =>
    context.strings.isEnglish
        ? MaterialLocalizations.of(
          context,
        ).formatShortMonthDay(DateTime(day.year, day.month, day.day))
        : '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}';

class _Series extends StatelessWidget {
  const _Series({required this.days});

  final List<DayTally> days;

  @override
  Widget build(BuildContext context) {
    final peak = days.fold(
      0,
      (best, day) => day.answers > best ? day.answers : best,
    );

    // Крупный системный шрифт полосу не ломает: столбики заданы в dp, а вся
    // полоса уменьшается целиком. Тот же приём, что у недели ритуала.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        key: ProgressKeys.series,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (index, day) in days.indexed) ...[
            if (index > 0) const SizedBox(width: seriesBarGap),
            SeriesBar(day: day, peak: peak),
          ],
        ],
      ),
    );
  }
}

/// Один столбик полосы.
///
/// Отдельным публичным виджетом, а не вложенным `Container`, ровно ради
/// проверяемости: «в полосе четырнадцать столбиков, и вот с какими числами»
/// иначе выражается перебором анонимных `SizedBox`, то есть не выражается.
/// Мутация «сократить отрезок до недели» до этого оставалась зелёной.
class SeriesBar extends StatelessWidget {
  const SeriesBar({required this.day, required this.peak, super.key});

  final DayTally day;

  /// Самый высокий день отрезка: по нему берётся доля.
  final int peak;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: context.strings.answersForDay(
        _dateLabel(context, day.day),
        day.answers,
      ),
      child: SizedBox(
        width: seriesBarWidth,
        height: seriesHeight,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: seriesBarWidth,
            height: barHeight(answers: day.answers, peak: peak),
            decoration: BoxDecoration(
              color:
                  day.answers == 0
                      ? scheme.outline.withValues(alpha: .3)
                      : scheme.primary,
              borderRadius: BorderRadius.circular(seriesBarWidth / 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// Высота столбика: доля от самого высокого дня отрезка, но не меньше
/// [seriesMinBar], если ответы были. День без ответов — дорожка во всю
/// высоту, чтобы полоса не рассыпалась на разрозненные палочки.
double barHeight({required int answers, required int peak}) {
  if (answers == 0) return seriesHeight;
  final share = seriesHeight * answers / peak;
  return share < seriesMinBar ? seriesMinBar : share;
}
