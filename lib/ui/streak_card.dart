/// Костёр текущей серии и полоса календарной недели.
library;

import 'package:arcadelingo/domain/streak/streak_view.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/campfire_stage.dart';
import 'package:arcadelingo/ui/ritual_labels.dart';
import 'package:arcadelingo/ui/streak_campfire.dart';
import 'package:arcadelingo/ui/streak_flame.dart';
import 'package:arcadelingo/ui/streak_label.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:arcadelingo/ui/week_strip.dart';
import 'package:flutter/material.dart';

export 'package:arcadelingo/ui/campfire_painter.dart'
    show FlamePainter, flamePath;

/// Диаметр кружка дня, dp.
const double weekDotSize = 30;

/// Зазор между кружками, dp.
const double weekDotGap = 8;

/// Толщина кольца «сегодня», dp.
const double weekTodayRing = 2;

/// Прозрачность будущих дней.
const double weekFutureAlpha = 0.4;

/// Карточка серии на домашнем экране.
class StreakCard extends StatelessWidget {
  const StreakCard({required this.ritual, super.key, this.week});

  final StreakView ritual;

  /// Семь дней недели; null — журнал ещё читается. Место под полосу при этом
  /// уже занято, чтобы карточка не прыгала, когда данные приедут.
  final List<WeekDay>? week;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tier = flameTier(ritual.days);
    final mood = flameMood(ritual);
    final caption = ritualStreakLabel(ritual, strings: context.strings);
    final stage = CampfireStage.forDays(ritual.days);

    return Container(
      key: streakCardKey,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label:
                ritual.days == 0
                    ? context.strings.noStreak
                    : streakLabel(ritual.days, strings: context.strings),
            excludeSemantics: true,
            child: _Flame(tier: tier, mood: mood, days: ritual.days),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption,
              key: streakCaptionKey,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (stage != null) ...[
            const SizedBox(height: 4),
            Text(
              context.strings.campfireStageName(stage),
              textAlign: TextAlign.center,
              style: textTheme.titleSmall,
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: weekDotSize + weekTodayRing * 2,
            child:
                week == null
                    ? const SizedBox.shrink()
                    : _WeekStrip(days: week!),
          ),
        ],
      ),
    );
  }
}

/// Ключ карточки: тест ищет по нему то, что не опознать по тексту.
const Key streakCardKey = Key('app.streak_card');

/// Ключ подписи под пламенем.
const Key streakCaptionKey = Key('app.streak');

/// Ключ полосы недели.
const Key weekStripKey = Key('app.week');

class _Flame extends StatelessWidget {
  const _Flame({required this.tier, required this.mood, required this.days});

  final FlameTier tier;
  final FlameMood mood;
  final int days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = flameHeights[tier]!;
    final digitSize = flameDigitSizes[tier];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StreakCampfire(
          days: days,
          tier: tier,
          mood: mood,
          size: Size.square(height),
        ),
        if (digitSize != null)
          Text(
            '$days',
            key: flameDigitKey,
            style: withWeight(
              TextStyle(
                fontSize: digitSize,
                height: 1,
                color: scheme.onSurface,
              ),
              FontWeight.bold,
            ),
          ),
      ],
    );
  }
}

/// Ключ счётчика дней серии.
const Key flameDigitKey = Key('app.flame_digit');

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.days});

  final List<WeekDay> days;

  @override
  Widget build(BuildContext context) {
    // Крупный системный шрифт полосу не ломает: она уменьшается целиком.
    // Кружки при этом остаются кружками — их размер задан в dp, а не текстом.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        key: weekStripKey,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, day) in days.indexed) ...[
            if (index > 0) const SizedBox(width: weekDotGap),
            _WeekDot(day: day),
          ],
        ],
      ),
    );
  }
}

class _WeekDot extends StatelessWidget {
  const _WeekDot({required this.day});

  final WeekDay day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final future = day.state == WeekDayState.future;
    final fill = switch (day.state) {
      WeekDayState.played => scheme.primaryContainer,
      _ => scheme.surfaceContainerHighest,
    };

    return Semantics(
      label:
          '${context.strings.weekday(day.day.weekday, day.letter)}: ${weekDayDescription(day, strings: context.strings)}',
      excludeSemantics: true,
      child: Container(
        width: weekDotSize,
        height: weekDotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: future ? fill.withValues(alpha: weekFutureAlpha) : fill,
          border:
              day.isToday
                  ? Border.all(color: scheme.primary, width: weekTodayRing)
                  : null,
        ),
        alignment: Alignment.center,
        child: switch (day.state) {
          WeekDayState.played => Icon(
            Icons.check,
            size: 16,
            color: scheme.primary,
          ),
          WeekDayState.frozen => Icon(
            Icons.shield,
            size: 15,
            color: scheme.tertiary,
          ),
          _ => Text(
            context.strings.weekday(day.day.weekday, day.letter),
            style: textTheme.bodySmall?.copyWith(
              color:
                  future
                      ? scheme.onSurfaceVariant.withValues(
                        alpha: weekFutureAlpha,
                      )
                      : scheme.onSurfaceVariant,
            ),
          ),
        },
      ),
    );
  }
}

/// Что случилось с днём — словами, для экранного диктора.
String weekDayDescription(WeekDay day, {AppStrings strings = russianStrings}) =>
    switch (day.state) {
      WeekDayState.played => strings.playedDay,
      WeekDayState.frozen => strings.frozenDay,
      WeekDayState.missed => strings.missedDay,
      WeekDayState.pending => strings.pendingDay,
      WeekDayState.future => strings.futureDay,
    };
