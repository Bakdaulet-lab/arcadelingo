/// Сессия повторения поверх Лейтнера — реализация `ReviewSession`.
///
/// Реализации здесь ещё нет — только сигнатуры, на которых компилируются
/// тесты задачи 0.6. Тело появляется в той же задаче следующим коммитом,
/// тесты в этот момент не трогаются.
library;

import '../review/review_contract.dart';
import '../srs/leitner.dart';

class LeitnerReviewSession implements ReviewSession {
  factory LeitnerReviewSession.start({
    required Map<String, LeitnerCard> cards,
    required List<ReviewItem> items,
    required int target,
    required DateTime Function() now,
    required void Function(Map<String, LeitnerCard> cards) onCardsChanged,
  }) => throw UnimplementedError('сессия не реализована — задача 0.6');

  @override
  ReviewItem? nextItem() =>
      throw UnimplementedError('сессия не реализована — задача 0.6');

  @override
  void report(ReviewOutcome outcome) =>
      throw UnimplementedError('сессия не реализована — задача 0.6');

  @override
  bool get isFinished =>
      throw UnimplementedError('сессия не реализована — задача 0.6');

  @override
  int get answered =>
      throw UnimplementedError('сессия не реализована — задача 0.6');

  @override
  int get total =>
      throw UnimplementedError('сессия не реализована — задача 0.6');
}
