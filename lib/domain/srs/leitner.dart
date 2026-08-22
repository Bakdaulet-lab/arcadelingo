/// Лейтнер v1: пять коробок, чистая функция перехода.
///
/// Реализации здесь ещё нет — только тип состояния и сигнатура перехода,
/// на которых компилируются тесты задачи 0.3. Тело появляется в задаче 0.4,
/// тесты в этот момент не трогаются.
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
}) => throw UnimplementedError('Лейтнер не реализован — задача 0.4');
