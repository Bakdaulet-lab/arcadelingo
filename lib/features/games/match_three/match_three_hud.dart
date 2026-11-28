import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

import 'match_three_run.dart';

/// The charge has a stable place between the score and the move budget.
/// Filled and hollow gems remain distinguishable without color.
class MatchThreeHud extends StatelessWidget {
  const MatchThreeHud({required this.run, super.key});

  final MatchThreeRun run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final strings = context.strings;
    final progress = run.chargeProgress;
    final duration = Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 170,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Counter(
                label: strings.matchScoreLabel,
                value: run.score,
                duration: duration,
                color: colors.primary,
              ),
            ),
            Expanded(
              flex: 2,
              child: Semantics(
                label: strings.matchChargeLabel,
                value: '$progress / ${MatchThreeRun.chargeGoal}',
                excludeSemantics: true,
                child: Column(
                  children: [
                    Text(
                      strings.matchChargeLabel,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      children: [
                        for (var i = 0; i < MatchThreeRun.chargeGoal; i++)
                          AnimatedSwitcher(
                            duration: duration,
                            transitionBuilder:
                                (child, animation) => ScaleTransition(
                                  scale: Tween(
                                    begin: .8,
                                    end: 1.0,
                                  ).animate(animation),
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                ),
                            child: Icon(
                              i < progress
                                  ? Icons.diamond_rounded
                                  : Icons.diamond_outlined,
                              key: ValueKey(i < progress),
                              size: 21,
                              color:
                                  i < progress
                                      ? colors.tertiary
                                      : colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _Counter(
                label: strings.matchMovesLabel,
                value: run.moves,
                duration: duration,
                alignEnd: true,
                color: run.moves <= 3 ? colors.error : colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.label,
    required this.value,
    required this.duration,
    required this.color,
    this.alignEnd = false,
  });

  final String label;
  final int value;
  final Duration duration;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: label,
      value: '$value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          AnimatedSwitcher(
            duration: duration,
            child: Text(
              '$value',
              key: ValueKey(value),
              style: withWeight(
                theme.textTheme.titleLarge!,
                FontWeight.bold,
              ).copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
