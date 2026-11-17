import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

/// Презентация счётчиков. Значения и состояние серии задаёт вызывающая игра.
class ArcadeHud extends StatelessWidget {
  const ArcadeHud({
    required this.lives,
    required this.maxLives,
    required this.score,
    required this.multiplier,
    required this.current,
    required this.total,
    required this.hot,
    required this.progressKey,
    required this.comboKey,
    required this.scoreKey,
    this.scorePulse = 0,
    super.key,
  });

  final int lives;
  final int maxLives;
  final int score;
  final int multiplier;
  final int current;
  final int total;
  final bool hot;
  final Key progressKey;
  final Key comboKey;
  final Key scoreKey;
  final double scorePulse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: ArcadePanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
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
                      color: i < lives ? colors.error : colors.outline,
                      size: 22,
                      applyTextScaling: true,
                    ),
                ],
              ),
            ),
            Text(
              '$current/$total',
              key: progressKey,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            Text(
              '×$multiplier',
              key: comboKey,
              style: withWeight(
                theme.textTheme.titleMedium!,
                FontWeight.w600,
              ).copyWith(color: hot ? colors.primary : colors.onSurfaceVariant),
            ),
            Transform.scale(
              scale: 1 + .25 * scorePulse.clamp(0, 1),
              child: Text(
                '$score',
                key: scoreKey,
                style: withWeight(theme.textTheme.titleLarge!, FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
