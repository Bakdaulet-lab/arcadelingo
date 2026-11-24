import '../review/review_contract.dart';
import '../review/word_labels.dart';

/// Builds questions for personal words in a single course. Prefer other saved
/// translations, then fill the remaining choices from that course's vocabulary.
List<ReviewItem> buildCustomReviewItems({
  required Iterable<Word> words,
  required Iterable<ReviewItem> courseItems,
  required CefrLevel level,
}) {
  final personal = words.where((word) => word.level == level).toList();
  if (personal.isEmpty) return [];
  final vocabulary = [
    ...personal,
    for (final item in courseItems)
      if (item.word.level == level) item.word,
  ];
  final meaningsBySpelling = <String, Set<String>>{};
  for (final word in vocabulary) {
    meaningsBySpelling
        .putIfAbsent(normalizedWordLabel(word.text), () => {})
        .addAll(translationMeanings(word.translation));
  }
  return [
    for (final word in personal)
      ReviewItem(
        word: word,
        distractors: _choices(word, vocabulary, meaningsBySpelling),
      ),
  ];
}

List<String> _choices(
  Word target,
  List<Word> vocabulary,
  Map<String, Set<String>> meaningsBySpelling,
) {
  final used = {...meaningsBySpelling[normalizedWordLabel(target.text)]!};
  final choices = <String>[];
  for (final candidate in vocabulary) {
    final meanings = translationMeanings(candidate.translation);
    if (meanings.isEmpty || meanings.any(used.contains)) continue;
    used.addAll(meanings);
    choices.add(candidate.translation);
    if (choices.length == 3) break;
  }
  return choices;
}
