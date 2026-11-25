import '../log/answer_record.dart';
import '../review/review_contract.dart';

class DictionaryEntry {
  DictionaryEntry._(this.word, List<AnswerRecord> attempts)
    : attempts = List.unmodifiable(attempts),
      mistakes = attempts.where((answer) => !answer.correct).length;

  final Word word;

  /// От новых попыток к старым.
  final List<AnswerRecord> attempts;

  final int mistakes;

  /// Две ошибки в пяти последних попытках. Старые ошибки перестают
  /// влиять на этот фильтр по мере успешного повторения.
  bool get isDifficult =>
      attempts.take(5).where((answer) => !answer.correct).length >= 2;
}

/// Слова выбранного уровня в порядке последней встречи: новые первыми.
/// [answers] — журнал в хронологическом порядке, как возвращает AnswerLog.
List<DictionaryEntry> buildPersonalDictionary({
  required Iterable<ReviewItem> items,
  required CefrLevel level,
  required List<AnswerRecord> answers,
  Iterable<Word> customWords = const [],
}) {
  final personal = customWords.where((word) => word.level == level).toList();
  final words = {
    for (final item in items)
      if (item.word.level == level) item.word.id: item.word,
    for (final word in personal) word.id: word,
  };
  final history = <String, List<AnswerRecord>>{};
  for (final answer in answers.reversed) {
    if (words.containsKey(answer.wordId)) {
      history.putIfAbsent(answer.wordId, () => []).add(answer);
    }
  }
  return List.unmodifiable([
    for (final entry in history.entries)
      DictionaryEntry._(words[entry.key]!, entry.value),
    for (final word in personal)
      if (!history.containsKey(word.id)) DictionaryEntry._(word, const []),
  ]);
}
