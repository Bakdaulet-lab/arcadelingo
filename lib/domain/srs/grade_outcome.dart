/// Шаг 1 SRS: игровой результат → оценка для планировщика.
///
/// Игра отдаёт сырой факт (`ReviewOutcome`: верно/неверно, время, подсказки),
/// а шкалу [ReviewGrade] заводит этот файл — и только он. Иначе каждая
/// новая игра изобретёт свою, и они разъедутся; игре сюда и не дотянуться:
/// CLAUDE.md → «Архитектурный закон», п. 2. Таблица и крайние случаи —
/// `.claude/skills/srs-engine/SKILL.md`, «Шаг 1».
///
/// Чистые функции: ни часов, ни состояния, одинаковый вход — одинаковый
/// выход. Отрицательные длительности контрактом не предусмотрены и здесь
/// не сторожатся: `ReviewOutcome` — носитель данных, отвечает за него тот,
/// кто его строит.
library;

import '../review/review_contract.dart';
import 'review_grade.dart';

/// Быстрее этой доли лимита — `easy`. Сравнение строгое: ровно 0.30 — уже
/// `good`. Вместе с [_goodBelow] — единственное место, где живут пороги.
const double _easyBelow = 0.30;

/// Быстрее этой доли лимита (но не быстрее [_easyBelow]) — `good`, от неё
/// и медленнее — `hard`. Ровно 0.60 — уже `hard`.
const double _goodBelow = 0.60;

/// Оценка ответа.
///
/// Проверка `correct` идёт первой и этим держит два правила скилла сразу:
/// неверный ответ — `again` при любом времени и подсказках, а верный не
/// бывает `again` никогда — дальше шкала начинается с `hard`.
///
/// `hintsUsed > 0` опускает на одну ступень, но не ниже `hard`: подсказка
/// портит верный ответ, не превращая его в «забыл». Это порог, а не
/// счётчик — пять подсказок стоят столько же, сколько одна.
///
/// Нулевой лимит даёт `hard` через [responseRatio] (1.0 ≥ 0.60), отдельной
/// ветки здесь нет.
ReviewGrade gradeOutcome(ReviewOutcome outcome) {
  if (!outcome.correct) return ReviewGrade.again;
  final bySpeed = _bySpeed(responseRatio(outcome));
  return outcome.hintsUsed > 0 ? _demote(bySpeed) : bySpeed;
}

/// Доля лимита, ушедшая на ответ: 0.0 — мгновенно, 1.0 — весь лимит.
///
/// Нормализация по лимиту и есть смысл этой величины: 2 с из 6 и 1 с из 3 —
/// одна и та же скорость, поэтому игры с разным темпом сравнимы. Считается
/// по миллисекундам, как в формуле скилла.
///
/// Сверху зажат в 1.0: ответ дольше лимита (игра засчитала с опозданием)
/// не медленнее, чем ровно в лимит. Нулевой лимит — делить не на что,
/// считаем, что ушёл весь лимит: 1.0, и отсюда `hard` в [gradeOutcome].
/// Лимит короче миллисекунды для формулы в миллисекундах — тот же ноль.
///
/// Публичная, а не приватная, по одной причине: зажим через одну оценку
/// ненаблюдаем (1.0 и 2.5 оба дают `hard`), а правило скилла обязано быть
/// проверяемым.
double responseRatio(ReviewOutcome outcome) {
  final limitMs = outcome.timeLimit.inMilliseconds;
  final responseMs = outcome.responseTime.inMilliseconds;
  if (limitMs <= 0 || responseMs >= limitMs) return 1.0;
  return responseMs / limitMs;
}

/// Оценка по одной скорости, без подсказок.
ReviewGrade _bySpeed(double ratio) {
  if (ratio < _easyBelow) return ReviewGrade.easy;
  if (ratio < _goodBelow) return ReviewGrade.good;
  return ReviewGrade.hard;
}

/// На ступень ниже, но не ниже [ReviewGrade.hard].
///
/// `switch`, а не арифметика по `index`: порядок enum задан от худшего к
/// лучшему и здесь прочитывается буквально, а исчерпывающий разбор не даст
/// забыть ветку при появлении новой ступени.
ReviewGrade _demote(ReviewGrade grade) => switch (grade) {
  ReviewGrade.easy => ReviewGrade.good,
  ReviewGrade.good => ReviewGrade.hard,
  ReviewGrade.hard => ReviewGrade.hard,
  // Недостижимо: again отсечён в gradeOutcome до подсчёта. Ветка нужна
  // исчерпывающему switch, а не поведению.
  ReviewGrade.again => ReviewGrade.again,
};
