import 'package:arcadelingo/domain/streak/streak_view.dart';
import 'package:arcadelingo/ui/ritual_labels.dart';
import 'package:arcadelingo/ui/streak_card.dart';
import 'package:arcadelingo/ui/streak_flame.dart';
import 'package:arcadelingo/ui/streak_label.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:arcadelingo/ui/week_strip.dart';
import 'package:flutter/material.dart';

const Key homeTodayKey = Key('app.today');
const Key homeFreezeKey = Key('app.freeze');

/// Компактная серия с настоящими состояниями календарной недели.
class HomeRitualCard extends StatelessWidget {
  const HomeRitualCard({required this.ritual, super.key, this.week});

  final StreakView ritual;
  final List<WeekDay>? week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final caption = ritualStreakLabel(ritual);
    final freeze = ritualFreezeLabel(ritual);
    final tier = flameTier(ritual.days);
    final mood = flameMood(ritual);
    final flameExtent =
        flameHeights[tier]! * (tier == FlameTier.inferno ? flameHaloRadius : 1);

    return Container(
      key: streakCardKey,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surfaceContainerHighest,
            Color.lerp(scheme.surfaceContainerHighest, scheme.surface, 0.4)!,
          ],
        ),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth >= 280 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.3;
          final header = Semantics(
            label:
                '${ritual.days == 0 ? 'Серии нет' : streakLabel(ritual.days)}. '
                '${ritualTodayLabel(ritual)}',
            excludeSemantics: true,
            child: Row(
              children: [
                SizedBox(
                  width: compact ? 28 : 36,
                  height: compact ? 28 : 36,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: CustomPaint(
                      size: Size.square(flameExtent),
                      painter: FlamePainter(
                        tier: tier,
                        mood: mood,
                        scheme: scheme,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: compact ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: compact ? 5 : 7,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (caption != null) ...[
                            Text(
                              '${ritual.days}',
                              key: flameDigitKey,
                              style: withWeight(
                                theme.textTheme.headlineSmall!.copyWith(
                                  fontSize: compact ? 20 : null,
                                ),
                                FontWeight.bold,
                              ),
                            ),
                            Text(
                              caption,
                              key: streakCaptionKey,
                              style: withWeight(
                                theme.textTheme.titleSmall!.copyWith(
                                  fontSize: compact ? 12 : null,
                                ),
                                FontWeight.w600,
                              ),
                            ),
                          ] else
                            Text(
                              'Начни свою серию',
                              style: withWeight(
                                theme.textTheme.titleSmall!.copyWith(
                                  fontSize: compact ? 13 : null,
                                ),
                                FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        ritualTodayLabel(ritual),
                        key: homeTodayKey,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: compact ? 11 : null,
                          color:
                              ritual.playedToday
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
          final weekStrip = SizedBox(
            height: compact ? 32 : 38,
            child:
                week == null
                    ? null
                    : Row(
                      key: weekStripKey,
                      children: [
                        for (final day in week!)
                          Expanded(
                            child: _HomeWeekDay(day: day, compact: compact),
                          ),
                      ],
                    ),
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (compact)
                Row(
                  children: [
                    Expanded(child: header),
                    const SizedBox(width: 8),
                    SizedBox(width: 138, child: weekStrip),
                  ],
                )
              else ...[
                header,
                const SizedBox(height: 8),
                weekStrip,
              ],
              if (freeze != null) ...[
                const SizedBox(height: 8),
                Text(
                  freeze,
                  key: homeFreezeKey,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: compact ? 11.5 : null,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HomeWeekDay extends StatelessWidget {
  const _HomeWeekDay({required this.day, required this.compact});

  final WeekDay day;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final played = day.state == WeekDayState.played;
    final fill =
        played ? scheme.primary : scheme.outline.withValues(alpha: 0.4);

    return Semantics(
      label: '${day.letter}: ${weekDayDescription(day)}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                day.letter,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: compact ? 11 : null,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 3 : 5),
          Container(
            width: compact ? 16 : 22,
            height: compact ? 16 : 22,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border:
                  day.isToday
                      ? Border.all(color: scheme.primary, width: 1.5)
                      : null,
            ),
            child: switch (day.state) {
              WeekDayState.played => Icon(
                Icons.check,
                size: compact ? 12 : 16,
                color: scheme.onPrimary,
              ),
              WeekDayState.frozen => Icon(
                Icons.shield,
                size: compact ? 12 : 14,
                color: scheme.tertiary,
              ),
              _ => null,
            },
          ),
        ],
      ),
    );
  }
}
