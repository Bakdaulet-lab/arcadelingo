import 'package:arcadelingo/domain/streak/streak_view.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/campfire_stage.dart';
import 'package:arcadelingo/ui/ritual_labels.dart';
import 'package:arcadelingo/ui/streak_campfire.dart';
import 'package:arcadelingo/ui/streak_card.dart';
import 'package:arcadelingo/ui/streak_flame.dart';
import 'package:arcadelingo/ui/streak_label.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:arcadelingo/ui/week_strip.dart';
import 'package:flutter/material.dart';

const Key homeTodayKey = Key('app.today');
const Key homeFreezeKey = Key('app.freeze');
const Key homeCampfireBadgeKey = Key('app.campfire_badge');
const Key homeCampfireOpenKey = Key('app.campfire_open');
const Key homeCampfireLandscapeKey = Key('app.campfire_landscape');
const Key homeCampfireStageKey = Key('app.campfire_stage');
const Key homeCampfireReplayKey = Key('app.campfire_replay');

/// Компактная серия с настоящими состояниями календарной недели.
class HomeRitualCard extends StatefulWidget {
  const HomeRitualCard({required this.ritual, super.key, this.week});

  final StreakView ritual;
  final List<WeekDay>? week;

  @override
  State<HomeRitualCard> createState() => _HomeRitualCardState();
}

class _HomeRitualCardState extends State<HomeRitualCard> {
  ModalRoute<void>? _sheet;
  bool _opening = false;

  @override
  void didUpdateWidget(HomeRitualCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ritual.days != oldWidget.ritual.days ||
        flameMood(widget.ritual) != flameMood(oldWidget.ritual)) {
      _dismissSheet();
    }
  }

  void _dismissSheet() {
    final route = _sheet;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isCurrent) route.navigator?.pop();
    });
  }

  @override
  void dispose() {
    _dismissSheet();
    super.dispose();
  }

  Future<void> _open(CampfireStage stage) async {
    if (_opening) return;
    _opening = true;
    final ritual = widget.ritual;
    try {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        constraints: const BoxConstraints(maxWidth: 560),
        sheetAnimationStyle:
            MediaQuery.disableAnimationsOf(context)
                ? AnimationStyle.noAnimation
                : null,
        builder: (context) {
          _sheet = ModalRoute.of<void>(context);
          if (!mounted ||
              widget.ritual.days != ritual.days ||
              flameMood(widget.ritual) != flameMood(ritual)) {
            _dismissSheet();
            return const SizedBox.shrink();
          }
          return _HomeCampfireLandscape(
            days: ritual.days,
            stageName: context.strings.campfireStageName(stage),
            tier: flameTier(ritual.days),
            mood: flameMood(ritual),
          );
        },
      );
    } finally {
      _sheet = null;
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ritual = widget.ritual;
    final week = widget.week;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final paper = theme.brightness == Brightness.light;
    final caption = ritualStreakLabel(ritual, strings: context.strings);
    final freeze = ritualFreezeLabel(ritual, strings: context.strings);
    final tier = flameTier(ritual.days);
    final mood = flameMood(ritual);
    final stage = CampfireStage.forDays(ritual.days);

    final radius = BorderRadius.circular(paper ? 12 : 20);
    final card = Container(
      key: streakCardKey,
      padding: EdgeInsets.all(paper ? 8 : 12),
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
        borderRadius: radius,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth >= 280 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.3;
          final header = Semantics(
            label:
                '${ritual.days == 0 ? context.strings.noStreak : streakLabel(ritual.days, strings: context.strings)}. '
                '${ritualTodayLabel(ritual, strings: context.strings)}',
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: StreakCampfire(
                    key: homeCampfireBadgeKey,
                    size: Size.square(compact && stage == null ? 28 : 36),
                    days: ritual.days,
                    tier: tier,
                    mood: mood,
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
                              context.strings.startStreak,
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
                        ritualTodayLabel(ritual, strings: context.strings),
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
                        for (final day in week)
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
                    SizedBox(width: paper ? 119 : 138, child: weekStrip),
                  ],
                )
              else ...[
                header,
                const SizedBox(height: 8),
                weekStrip,
              ],
              if (stage != null || freeze != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 3,
                        alignment:
                            stage == null
                                ? WrapAlignment.center
                                : WrapAlignment.start,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (stage != null)
                            Text(
                              context.strings.campfireStageName(stage),
                              key: homeCampfireStageKey,
                              style: withWeight(
                                theme.textTheme.labelMedium!,
                                FontWeight.w600,
                              ),
                            ),
                          if (freeze != null)
                            Text(
                              freeze,
                              key: homeFreezeKey,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: compact ? 11.5 : null,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (stage != null)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
    return Semantics(
      hint: stage == null ? null : context.strings.openCampfire,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: stage == null ? null : homeCampfireOpenKey,
          borderRadius: radius,
          onTap: stage == null ? null : () => _open(stage),
          child: card,
        ),
      ),
    );
  }
}

class _HomeCampfireLandscape extends StatefulWidget {
  const _HomeCampfireLandscape({
    required this.days,
    required this.stageName,
    required this.tier,
    required this.mood,
  });

  final int days;
  final String stageName;
  final FlameTier tier;
  final FlameMood mood;

  @override
  State<_HomeCampfireLandscape> createState() => _HomeCampfireLandscapeState();
}

class _HomeCampfireLandscapeState extends State<_HomeCampfireLandscape> {
  int _replayToken = 0;

  void _replay() => setState(() => ++_replayToken);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canReplay = !MediaQuery.disableAnimationsOf(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        streakLabel(widget.days, strings: context.strings),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        widget.stageName,
                        style: withWeight(
                          theme.textTheme.titleLarge!,
                          FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const CloseButton(),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 12 / 5,
                child: StreakCampfire(
                  key: homeCampfireLandscapeKey,
                  days: widget.days,
                  tier: widget.tier,
                  mood: widget.mood,
                  landscape: true,
                  replayToken: _replayToken,
                ),
              ),
            ),
            if (canReplay) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: homeCampfireReplayKey,
                  onPressed: _replay,
                  icon: const Icon(Icons.replay_rounded),
                  label: Text(context.strings.replayCampfire),
                ),
              ),
            ],
          ],
        ),
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
      label:
          '${context.strings.weekday(day.day.weekday, day.letter)}: ${weekDayDescription(day, strings: context.strings)}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                context.strings.weekday(day.day.weekday, day.letter),
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
