import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:arcadelingo/ui/arcade_status_layout.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

/// Одинаковое представление результатов двух игр, полученных от их сессий.
class ArcadeRoundSummary extends StatelessWidget {
  const ArcadeRoundSummary({
    required this.score,
    required this.bestCombo,
    required this.correctCount,
    required this.answeredCount,
    required this.outOfLives,
    required this.actions,
    this.footer,
    this.challengeRecord,
    this.footerKey,
    super.key,
  });

  final int score;
  final int bestCombo;
  final int correctCount;
  final int answeredCount;
  final bool outOfLives;
  final Widget actions;
  final String? footer;
  final Widget? challengeRecord;
  final Key? footerKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ArcadeStatusLayout(
      icon:
          outOfLives
              ? Icons.favorite_border_rounded
              : Icons.emoji_events_rounded,
      accent: outOfLives ? colors.error : colors.tertiary,
      title:
          outOfLives
              ? context.strings.outOfLives
              : context.strings.roundComplete,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArcadePanel(
            accent: colors.primary,
            padding: const EdgeInsets.all(16),
            child: Text(
              context.strings.score(score),
              textAlign: TextAlign.center,
              style: withWeight(
                theme.textTheme.headlineMedium!,
                FontWeight.bold,
              ).copyWith(color: colors.primary),
            ),
          ),
          const SizedBox(height: 12),
          ArcadePanel(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ResultLine(
                  icon: Icons.local_fire_department_rounded,
                  text: context.strings.bestCombo(bestCombo),
                  color: colors.tertiary,
                ),
                const SizedBox(height: 12),
                _ResultLine(
                  icon: Icons.check_circle_outline_rounded,
                  text: context.strings.correctAnswers(
                    correctCount,
                    answeredCount,
                  ),
                  color: colors.primary,
                ),
              ],
            ),
          ),
          if (challengeRecord case final record?) ...[
            const SizedBox(height: 16),
            record,
          ],
          if (footer != null) ...[
            const SizedBox(height: 16),
            Text(
              footer!,
              key: footerKey,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
      actions: actions,
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
    ],
  );
}
