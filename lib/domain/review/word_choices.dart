import 'dart:math';

import 'review_contract.dart';
import 'word_labels.dart';

/// Each pass through the deck starts on a different card from the last answer.
void shuffleWordCycle(
  List<ReviewItem> items,
  Random random, {
  ReviewItem? previous,
}) {
  items.shuffle(random);
  if (items.length > 1 && identical(items.first, previous)) {
    final other = 1 + random.nextInt(items.length - 1);
    items[0] = items[other];
    items[other] = previous!;
  }
}

/// Distinct spellings from the target's level for a translation-to-word task.
/// Prefer the card's curated alternatives and exclude alternate correct senses.
Iterable<Word> wordDistractors(
  ReviewItem question,
  Iterable<Word> vocabulary,
  Random random,
) sync* {
  final word = question.word;
  final translations = translationMeanings(word.translation);
  final labels = {normalizedWordLabel(word.text)};
  final curated = question.distractors.map(normalizedWordLabel).toSet();
  final preferred = <Word>[];
  final matchingPartOfSpeech = <Word>[];
  final others = <Word>[];

  for (final candidate in vocabulary) {
    if (candidate.level != word.level) continue;
    if (translationMeanings(candidate.translation).any(translations.contains)) {
      // Choices show only spelling, even if another personal or
      // course card records a different meaning for the same spelling.
      labels.add(normalizedWordLabel(candidate.text));
      continue;
    }
    final normalizedTranslation = normalizedWordLabel(candidate.translation);
    if (curated.contains(normalizedTranslation)) {
      preferred.add(candidate);
    } else if (word.partOfSpeech != null &&
        word.partOfSpeech == candidate.partOfSpeech) {
      matchingPartOfSpeech.add(candidate);
    } else {
      others.add(candidate);
    }
  }

  for (final pool in [preferred, matchingPartOfSpeech, others]) {
    pool.shuffle(random);
    for (final candidate in pool) {
      if (labels.add(normalizedWordLabel(candidate.text))) yield candidate;
    }
  }
}
