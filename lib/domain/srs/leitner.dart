/// Лейтнер v1: пять коробок, чистая функция перехода.
///
/// Реализации здесь ещё нет — только тип состояния и сигнатура перехода,
/// на которых компилируются тесты задачи 0.3. Тело появляется в задаче 0.4,
/// тесты в этот момент не трогаются.
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
  const LeitnerCard({
    required this.box,
    required this.due,
    this.sessionGap = 0,
  });

  /// Номер коробки, 1..5. Новая карточка начинает с первой.
  final int box;

  /// Момент, начиная с которого карточку снова можно показывать.
  final DateTime due;

  /// Сколько других карточек должно пройти до повтора внутри текущей сессии.
  ///
  /// Ненулевой только у коробки 1: её повтор назначается не на дату, а на
  /// позицию в очереди — «в этой же сессии, но не раньше чем через 3 других
  /// карточки». У коробок 2–5 повтор привязан к [due], поэтому здесь 0.
  final int sessionGap;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeitnerCard &&
          box == other.box &&
          due == other.due &&
          sessionGap == other.sessionGap;

  @override
  int get hashCode => Object.hash(box, due, sessionGap);

  @override
  String toString() =>
      'LeitnerCard(box: $box, due: $due, sessionGap: $sessionGap)';
}

/// Новое состояние карточки после ответа с оценкой [grade] в момент [now].
///
/// Чистая функция: тех же аргументов достаточно, чтобы предсказать результат.
LeitnerCard schedule(
  LeitnerCard card,
  ReviewGrade grade, {
  required DateTime now,
}) => throw UnimplementedError('Лейтнер не реализован — задача 0.4');
