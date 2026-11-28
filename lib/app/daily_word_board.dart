import 'dart:math' as math;

import 'package:arcadelingo/domain/daily_word/daily_word.dart';
import 'package:arcadelingo/domain/review/word_labels.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:flutter/material.dart';

class DailyWordBoard extends StatelessWidget {
  const DailyWordBoard({
    super.key,
    required this.length,
    required this.round,
    required this.draft,
  });

  final int length;
  final DailyWordRound round;
  final String draft;

  @override
  Widget build(BuildContext context) {
    final guesses = round.guesses;
    final marks = round.rows;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 5.0;
        final size = math.min(
          45.0,
          (constraints.maxWidth - gap * (length - 1)) / length,
        );
        return Column(
          children: [
            for (var row = 0; row < DailyWordRound.maxAttempts; row++) ...[
              if (row > 0) const SizedBox(height: gap),
              Builder(
                builder: (context) {
                  final current =
                      row == guesses.length &&
                      round.status == DailyWordStatus.playing;
                  final word =
                      row < guesses.length
                          ? guesses[row]
                          : current
                          ? draft.trim()
                          : '';
                  final letters =
                      uppercaseWordLetters(word).characters.toList();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var col = 0; col < length; col++) ...[
                        if (col > 0) const SizedBox(width: gap),
                        _LetterTile(
                          tileKey: ValueKey('dailyWord.cell.$row.$col'),
                          size: size,
                          current: current,
                          letter: col < letters.length ? letters[col] : '',
                          mark: row < marks.length ? marks[row][col] : null,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

typedef _MarkStyle = ({IconData icon, Color ink, Color fill, String label});

_MarkStyle _style(BuildContext context, DailyLetterMark mark) {
  final colors = Theme.of(context).colorScheme;
  final s = AppStrings.of(context);
  return switch (mark) {
    DailyLetterMark.exact => (
      icon: Icons.check_rounded,
      ink: colors.onPrimary,
      fill: colors.primary,
      label: s.dailyWordExact,
    ),
    DailyLetterMark.present => (
      icon: Icons.swap_horiz_rounded,
      ink: colors.onTertiary,
      fill: colors.tertiary,
      label: s.dailyWordPresent,
    ),
    DailyLetterMark.absent => (
      icon: Icons.remove_rounded,
      ink: colors.onSurfaceVariant,
      fill: colors.surfaceContainerHighest,
      label: s.dailyWordAbsent,
    ),
  };
}

class _LetterTile extends StatelessWidget {
  const _LetterTile({
    required this.tileKey,
    required this.size,
    required this.current,
    required this.letter,
    required this.mark,
  });

  final Key tileKey;
  final double size;
  final bool current;
  final String letter;
  final DailyLetterMark? mark;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = mark == null ? null : _style(context, mark!);
    return Semantics(
      key: tileKey,
      container: true,
      excludeSemantics: true,
      label: style == null ? letter : '$letter · ${style.label}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color:
              style?.fill ??
              (current
                  ? colors.primaryContainer.withValues(alpha: .38)
                  : colors.surface),
          border: Border.all(
            color:
                style?.fill ??
                (current ? colors.primary : colors.outlineVariant),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                letter,
                style: TextStyle(
                  fontSize: 20,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: style?.ink ?? colors.onSurface,
                ),
              ),
              if (style != null) Icon(style.icon, color: style.ink, size: 13),
            ],
          ),
        ),
      ),
    );
  }
}

class DailyWordLegend extends StatelessWidget {
  const DailyWordLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final mark in DailyLetterMark.values)
          Builder(
            builder: (context) {
              final style = _style(context, mark);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: style.fill,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(style.icon, size: 16, color: style.ink),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      style.label,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}
