import '../review/review_contract.dart';
import '../session/observed_session.dart';

/// Ошибки одной партии для спокойного разбора после игры.
///
/// Существующая ObservedSession вызывает наблюдателя после принятия ответа.
/// Здесь нет повторного report(), изменения карточек или начисления очков:
/// чтение разбора не становится ещё одной попыткой в истории обучения.
class MistakeReviewObserver implements ReviewObserver {
  MistakeReviewObserver({required this.level});

  final CefrLevel level;
  final List<Word> _mistakes = [];
  final Set<String> _wordIds = {};

  /// Неизменяемый снимок в порядке первых ошибок. Даже если слово затем
  /// отвечено верно, оно остаётся доступным для разбора этого раунда.
  List<Word> get mistakes => List.unmodifiable(_mistakes);

  @override
  void onAnswer(ReviewEvent event) {
    final word = event.item.word;
    if (event.outcome.correct || word.level != level) return;
    if (_wordIds.add(word.id)) _mistakes.add(word);
  }
}
