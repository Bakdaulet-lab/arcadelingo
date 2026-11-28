import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

class WordPanel extends StatelessWidget {
  const WordPanel({
    required this.word,
    this.labelCorrectTranslation = false,
    super.key,
  });

  static const wordKey = Key('learning.word');
  static const translationKey = Key('learning.translation');

  final bool labelCorrectTranslation;

  final Word word;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final partOfSpeech = word.partOfSpeech;
    final example = word.example;
    return ArcadePanel(
      accent: colors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (partOfSpeech != null && partOfSpeech.isNotEmpty) ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _partOfSpeechLabel(partOfSpeech, context.strings),
                softWrap: false,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              word.headword,
              key: wordKey,
              softWrap: false,
              style: withWeight(theme.textTheme.displaySmall!, FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          if (labelCorrectTranslation) ...[
            Text(
              context.strings.correctTranslation,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            word.translation,
            key: translationKey,
            style: withWeight(
              theme.textTheme.titleLarge!,
              FontWeight.w600,
            ).copyWith(color: colors.primary, fontSize: 20, height: 1.4),
          ),
          if (example != null && example.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(color: colors.outline.withValues(alpha: .45)),
            const SizedBox(height: 12),
            Text(
              example,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

String _partOfSpeechLabel(String partOfSpeech, AppStrings strings) =>
    switch (partOfSpeech) {
      'noun' => strings.noun,
      'verb' => strings.verb,
      'adjective' || 'adj' => strings.adjective,
      'adverb' || 'adv' => strings.adverb,
      'pronoun' => strings.pronoun,
      'numeral' => strings.numeral,
      'preposition' => strings.preposition,
      'conjunction' => strings.conjunction,
      'interjection' => strings.interjection,
      'determiner' => strings.determiner,
      'phrase' => strings.phrase,
      _ => partOfSpeech,
    };
