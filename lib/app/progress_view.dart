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
    super.key,
  });

  final AnswerLog answers;
  final CardStore cards;
  final StreakStore streaks;
  final DateTime Function() now;

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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Прогресс')),
    body: FutureBuilder<ProgressData>(
      future: _data,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        return ProgressBody(data: data);
      },
    ),
  );
}

/// Вид без единого обращения к хранилищу: всё приходит параметром.
class ProgressBody extends StatelessWidget {
  const ProgressBody({required this.data, super.key});

  final ProgressData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (data.isEmpty) {
      // Экран с четырьмя нулями и пустой полосой выглядит как поломка, а не
      // как начало.
      return Center(
        key: ProgressKeys.empty,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Сыграй первую партию, и здесь появится, сколько пройдено',
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final accuracy = accuracyPercent(
      answers: data.totals.answers,
      correct: data.totals.correct,
    );

    return SingleChildScrollView(
      key: ProgressKeys.view,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Block(
            viewKey: ProgressKeys.words,
            title: 'Слова',
            rows: [
              ('Выучено', '${data.words.learned}'),
              ('В работе', '${data.words.learning}'),
              ('Трудные', '${data.words.hard}'),
            ],
          ),
          const SizedBox(height: 16),
          _Block(
            viewKey: ProgressKeys.answers,
            title: 'Ответы',
            rows: [
              ('Всего', '${data.totals.answers}'),
              if (accuracy != null) ('Верных', '$accuracy%'),
            ],
          ),
          const SizedBox(height: 16),
          _Block(
            viewKey: ProgressKeys.days,
            title: 'Дни',
            rows: [
              ('С ответами', '${data.totals.days}'),
              (
                'Лучшая серия',
                '${data.bestStreak} ${dayWord(data.bestStreak)}',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Две недели',
            style: withWeight(textTheme.titleSmall!, FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _Series(days: data.series),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.viewKey,
    required this.title,
    required this.rows,
  });

  final Key viewKey;
  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: viewKey,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: withWeight(
              textTheme.titleSmall!,
              FontWeight.bold,
            ).copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: textTheme.bodyMedium),
                  Text(
                    value,
                    style: withWeight(
                      textTheme.titleMedium!,
                      FontWeight.bold,
                    ).copyWith(color: scheme.primary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Series extends StatelessWidget {
  const _Series({required this.days});

  final List<DayTally> days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            SizedBox(
              width: seriesBarWidth,
              height: seriesHeight,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: seriesBarWidth,
                  height: _barHeight(day.answers, peak),
                  decoration: BoxDecoration(
                    color:
                        day.answers == 0
                            ? scheme.surfaceContainerHighest
                            : scheme.primary,
                    borderRadius: BorderRadius.circular(seriesBarWidth / 2),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Высота столбика: доля от самого высокого дня отрезка, но не меньше
  /// [seriesMinBar], если ответы были. День без ответов — дорожка во всю
  /// высоту, чтобы полоса не рассыпалась на разрозненные палочки.
  static double _barHeight(int answers, int peak) {
    if (answers == 0) return seriesHeight;
    final share = seriesHeight * answers / peak;
    return share < seriesMinBar ? seriesMinBar : share;
  }
}
