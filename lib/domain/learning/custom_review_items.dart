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
  return _buildItems(
    targets: personal,
    alternatives: vocabulary,
    vocabulary: vocabulary,
  );
}

/// Resolve the saved IDs against the current course. Rebuild the choices
/// from the set because a bundled card's distractors can name other words.
List<ReviewItem> buildWordSetReviewItems({
  required Iterable<Word> vocabulary,
  required Iterable<String> wordIds,
  required CefrLevel level,
}) {
  final byId = {
    for (final word in vocabulary)
      if (word.level == level) word.id: word,
  };
  final selected = [
    for (final id in wordIds.toSet())
      if (byId[id] case final word?) word,
  ];
  if (selected.isEmpty) return [];
  return _buildItems(
    targets: selected,
    alternatives: selected,
    vocabulary: byId.values,
  );
}

List<ReviewItem> _buildItems({
  required List<Word> targets,
  required List<Word> alternatives,
  required Iterable<Word> vocabulary,
}) {
  final meaningsBySpelling = <String, Set<String>>{};
  for (final word in vocabulary) {
    meaningsBySpelling
        .putIfAbsent(normalizedWordLabel(word.text), () => {})
        .addAll(translationMeanings(word.translation));
  }
  return [
    for (final word in targets)
      ReviewItem(
        word: word,
        distractors: _choices(word, alternatives, meaningsBySpelling),
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
