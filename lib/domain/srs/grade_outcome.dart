/// Шаг 1 SRS: игровой результат → оценка для планировщика.
///
/// Реализации здесь ещё нет — только сигнатуры, на которых компилируются
/// тесты задачи 0.5.1. Тело появляется в той же задаче следующим коммитом,
/// тесты в этот момент не трогаются.
library;

import '../review/review_contract.dart';
import 'review_grade.dart';

/// Оценка ответа по таблице «Шаг 1» скилла srs-engine.
ReviewGrade gradeOutcome(ReviewOutcome outcome) =>
    throw UnimplementedError(
      'маппинг результата в оценку не реализован — задача 0.5.1',
    );

/// Доля лимита, ушедшая на ответ, не больше 1.0.
double responseRatio(ReviewOutcome outcome) =>
    throw UnimplementedError(
      'маппинг результата в оценку не реализован — задача 0.5.1',
    );
