import '../log/answer_record.dart';
import '../review/review_contract.dart';
import '../review/word_labels.dart';

class ConfusedWordPair {
  const ConfusedWordPair({
    required this.first,
    required this.second,
    required this.mistakes,
    required this.lastMistakeAt,
  });

  final Word first;
  final Word second;
  final int mistakes;
  final DateTime lastMistakeAt;
}

/// Finds repeated, concrete wrong choices in one course's journal. Both words
/// must still be identifiable in that course's selected level.
List<ConfusedWordPair> findConfusedWords({
  required Iterable<Word> vocabulary,
  required CefrLevel level,
  required Iterable<AnswerRecord> answers,
}) {
  final index = _WordIndex(vocabulary.where((word) => word.level == level));
  final pairs = <(String, String), ConfusedWordPair>{};
  for (final answer in answers) {
    final target = index.byId[answer.wordId];
    if (target == null || answer.correct || answer.selectedAnswer == null) {
      continue;
    }
    final picked = index.choice(answer);
    if (picked == null || index.shareMeaningOrSpelling(target, picked)) {
      continue;
    }
    final (first, second) =
        target.id.compareTo(picked.id) < 0
            ? (target, picked)
            : (picked, target);
    final key = (first.id, second.id);
    final previous = pairs[key];
    pairs[key] = ConfusedWordPair(
      first: first,
      second: second,
      mistakes: (previous?.mistakes ?? 0) + 1,
      lastMistakeAt:
          previous != null && previous.lastMistakeAt.isAfter(answer.at)
              ? previous.lastMistakeAt
              : answer.at,
    );
  }
  final result =
      pairs.values.where((pair) => pair.mistakes >= 2).toList()..sort((a, b) {
        final count = b.mistakes.compareTo(a.mistakes);
        if (count != 0) return count;
        final recency = b.lastMistakeAt.compareTo(a.lastMistakeAt);
        if (recency != 0) return recency;
        final first = a.first.id.compareTo(b.first.id);
        return first != 0 ? first : a.second.id.compareTo(b.second.id);
      });
  return List.unmodifiable(result);
}

class _WordIndex {
  _WordIndex(Iterable<Word> vocabulary) {
    for (final word in vocabulary) {
      byId[word.id] = word;
      final spelling = normalizedWordLabel(word.text);
      final translation = normalizedWordLabel(word.translation);
      final meanings = translationMeanings(translation);
      meaningsBySpelling.putIfAbsent(spelling, () => {}).addAll(meanings);
      _index(spellings, spelling, word);
      for (final meaning in meanings) {
        _index(translations, meaning, word);
      }
      _index(apples, '$spelling — $translation', word);
    }
  }

  final byId = <String, Word>{};
  final spellings = <String, Word?>{};
  final translations = <String, Word?>{};
  final apples = <String, Word?>{};
  final meaningsBySpelling = <String, Set<String>>{};

  /// A null entry means this label represents more than one word.
  void _index(Map<String, Word?> lookup, String label, Word word) {
    lookup.update(
      label,
      (previous) => previous?.id == word.id ? word : null,
      ifAbsent: () => word,
    );
  }

  Word? choice(AnswerRecord answer) {
    final label = normalizedWordLabel(answer.selectedAnswer!);
    if (label.isEmpty) return null;
    return switch (answer.gameId) {
      'falling_words' ||
      'ninja_slash' ||
      'match_three' ||
      'brick_breaker' ||
      'word_mahjong' => translations[label],
      'snake' => apples[label],
      'active_recall' when answer.hintsUsed == 1 => spellings[label],
      _ => null,
    };
  }

  bool shareMeaningOrSpelling(Word a, Word b) {
    final first = normalizedWordLabel(a.text);
    final second = normalizedWordLabel(b.text);
    return first == second ||
        meaningsBySpelling[first]!.any(meaningsBySpelling[second]!.contains);
  }
}
