/// Прогресс по словам: во что превращаются коробки Лейтнера на экране.
///
/// Деление — не оформление, а толкование: коробка 1 означает «показать снова
/// сегодня», то есть слово не даётся; коробка 5 — интервал в три недели, то
/// есть слово человек помнит. Всё между ними в работе. Числа коробок живут в
/// `domain/srs/leitner.dart`, а что они значат для человека — здесь.
///
/// Отдельно от `srs/` намеренно: планировщику эти группы не нужны вовсе, а
/// `domain/srs/*` неприкосновенен с Фазы 2.
library;

import '../srs/leitner.dart';

/// Во что превратилось слово.
enum WordStage {
  /// Коробка 1: не даётся, вернётся сегодня же.
  hard,

  /// Коробки 2–4: в работе.
  learning,

  /// Коробка 5: интервал в три недели — считаем выученным.
  learned,
}

/// Группа слова по его карточке.
WordStage stageOf(LeitnerCard card) {
  if (card.box <= LeitnerCard.minBox) return WordStage.hard;
  if (card.box >= LeitnerCard.maxBox) return WordStage.learned;
  return WordStage.learning;
}

/// Сколько слов в каждой группе.
class WordCounts {
  const WordCounts({
    required this.hard,
    required this.learning,
    required this.learned,
  });

  /// Пусто: ни одного слова с карточкой.
  static const WordCounts empty = WordCounts(hard: 0, learning: 0, learned: 0);

  final int hard;
  final int learning;
  final int learned;

  /// Слов, до которых человек вообще добрался. Слова без карточки сюда не
  /// входят: их не показывали ни разу, и «прогресса» по ним нет.
  int get total => hard + learning + learned;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordCounts &&
          hard == other.hard &&
          learning == other.learning &&
          learned == other.learned;

  @override
  int get hashCode => Object.hash(hard, learning, learned);

  @override
  String toString() =>
      'WordCounts(трудные: $hard, в работе: $learning, выучено: $learned)';
}

/// Подсчёт групп по карте карточек.
WordCounts countWords(Map<String, LeitnerCard> cards) {
  var hard = 0;
  var learning = 0;
  var learned = 0;
  for (final card in cards.values) {
    switch (stageOf(card)) {
      case WordStage.hard:
        hard++;
      case WordStage.learning:
        learning++;
      case WordStage.learned:
        learned++;
    }
  }
  return WordCounts(hard: hard, learning: learning, learned: learned);
}

/// Доля верных ответов в процентах, или null — отвечать было нечего.
///
/// Целочисленно, как порог «в последний момент» в падающих словах:
/// плавающая точка на границе дала бы тест, зелёный на одной машине и
/// красный на другой.
///
/// Ноль ответов даёт **null**, а не ноль: «0%» означает «всё неверно», и
/// показывать это тому, кто ещё не играл, — враньё.
int? accuracyPercent({required int answers, required int correct}) =>
    answers == 0 ? null : correct * 100 ~/ answers;
