/// Лейтнер v1: пять коробок, чистая функция перехода.
///
/// Коробка 1 означает «показать снова в этой же сессии»: `due == now`.
/// Правило «не раньше чем через 3 других карточки» — это порядок очереди,
/// а не расписание, и живёт оно в `ReviewSession` (задача 0.6). Планировщик
/// про размер и порядок сессии не знает.
///
/// ЗАКОН (CLAUDE.md → «Архитектурный закон», п. 3): текущее время приходит
/// параметром `now`. `DateTime.now()` в этом каталоге запрещён и ловится
/// `scripts/arch_check.sh`. Таблица интервалов и переходов —
/// `.claude/skills/srs-engine/SKILL.md`, «Шаг 2 (v1)».
library;

import 'review_grade.dart';

const int _minBox = 1;
const int _maxBox = 5;

/// Через сколько после ответа карточка всплывёт снова, по номеру коробки.
/// Индекс — `box - 1`. Единственное место в коде, где живут эти числа.
const List<Duration> _boxIntervals = [
  Duration.zero, // 1 — в этой же сессии
  Duration(days: 1), // 2
  Duration(days: 3), // 3
  Duration(days: 7), // 4
  Duration(days: 21), // 5
];

/// Состояние карточки в схеме Лейтнера.
///
/// Значимый объект: сравнивается по полям, чтобы «одинаковый вход даёт
/// одинаковый выход» можно было проверить одним `expect`.
class LeitnerCard {
  const LeitnerCard({required this.box, required this.due});

  /// Номер коробки, 1..5. Новая карточка начинает с первой.
  final int box;

  /// Момент, начиная с которого карточку снова можно показывать.
  final DateTime due;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeitnerCard && box == other.box && due == other.due;

  @override
  int get hashCode => Object.hash(box, due);

  @override
  String toString() => 'LeitnerCard(box: $box, due: $due)';
}

/// Новое состояние карточки после ответа с оценкой [grade] в момент [now].
///
/// Чистая функция: тех же аргументов достаточно, чтобы предсказать результат.
LeitnerCard schedule(
  LeitnerCard card,
  ReviewGrade grade, {
  required DateTime now,
}) {
  final target = switch (grade) {
    // Забыл — обратно в первую коробку, как бы высоко ни забрался до этого.
    ReviewGrade.again => _minBox,
    // Вспомнил с трудом — коробка та же, но срок отсчитывается заново от now,
    // а не от старого due: иначе просроченная карточка вернулась бы сразу.
    ReviewGrade.hard => card.box,
    ReviewGrade.good => card.box + 1,
    ReviewGrade.easy => card.box + 2,
  };
  final box = _clampBox(target);
  return LeitnerCard(box: box, due: now.add(_boxIntervals[box - 1]));
}

/// Номер коробки, зажатый в границы таблицы: шестой коробки не существует,
/// поэтому `easy` из пятой не уводит за потолок, а даёт ту же пятую.
int _clampBox(int box) {
  if (box < _minBox) return _minBox;
  if (box > _maxBox) return _maxBox;
  return box;
}
