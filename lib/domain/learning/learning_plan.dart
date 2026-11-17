/// Слова одного учебного раунда и его предварительного знакомства.
///
/// План ничего не сохраняет и не выдаёт ответы за пользователя. Он только
/// ограничивает словарь, который хост затем передаст в обычный StartSession.
/// Поэтому игра не сможет внезапно показать новое слово, которого не было
/// среди карточек знакомства, а просмотр не сдвигает расписание повторов.
library;

import '../review/review_contract.dart';
import '../srs/leitner.dart';

typedef _Ready = ({ReviewItem item, DateTime due, int index});

class LearningPlan {
  LearningPlan._({
    required List<ReviewItem> selectedItems,
    required List<Word> newWords,
  }) : selectedItems = List.unmodifiable(selectedItems),
       newWords = List.unmodifiable(newWords);

  /// Готовые повторы выбранного уровня идут первыми по сроку, при равенстве
  /// — в порядке словаря. Свободные места занимают не более [maxNewWords]
  /// новых слов. Их точный список доступен для знакомства в [newWords].
  ///
  /// Одинаковый id учитывается только один раз. Карточки других уровней и
  /// повторы, срок которых ещё не наступил, не входят ни в один список.
  factory LearningPlan.build({
    required List<ReviewItem> items,
    required Map<String, LeitnerCard> cards,
    required CefrLevel level,
    required DateTime now,
    int target = 15,
    int maxNewWords = 5,
  }) {
    if (target < 0) {
      throw ArgumentError.value(target, 'target', 'размер раунда меньше нуля');
    }
    if (maxNewWords < 0) {
      throw ArgumentError.value(
        maxNewWords,
        'maxNewWords',
        'число новых слов меньше нуля',
      );
    }

    final ready = <_Ready>[];
    final fresh = <ReviewItem>[];
    final includedIds = <String>{};
    for (final (index, item) in items.indexed) {
      final word = item.word;
      if (word.level != level || !includedIds.add(word.id)) continue;
      final card = cards[word.id];
      if (card == null) {
        fresh.add(item);
      } else if (!card.due.isAfter(now)) {
        ready.add((item: item, due: card.due, index: index));
      }
    }
    ready.sort((a, b) {
      final byDue = a.due.compareTo(b.due);
      return byDue != 0 ? byDue : a.index.compareTo(b.index);
    });

    final selected = [for (final review in ready.take(target)) review.item];
    final admittedNew =
        fresh.take(maxNewWords).take(target - selected.length).toList();
    selected.addAll(admittedNew);
    return LearningPlan._(
      selectedItems: selected,
      newWords: [for (final item in admittedNew) item.word],
    );
  }

  /// Полный допустимый словарь этой партии: готовые повторы и новые слова.
  final List<ReviewItem> selectedItems;

  /// Новые слова этой партии, которые нужно показать до запуска таймера.
  final List<Word> newWords;
}
