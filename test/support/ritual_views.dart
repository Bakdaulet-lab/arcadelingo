// Готовые состояния ритуала для экранов и снимков.
//
// Собираются настоящим `streakAsOf` из настоящего `StreakState`, а не
// выдуманным значением полей: экран обязан рисовать то, что домен реально
// отдаёт. Фейковый `StreakView` с несогласованными полями показал бы кадр,
// которого в приложении не бывает.

import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/domain/streak/streak_view.dart';

/// Сегодня во всех сценариях ритуала — среда.
final StreakDay ritualToday = StreakDay(2026, 8, 26);

/// День на [offset] суток раньше [ritualToday].
StreakDay daysAgo(int offset) {
  final moment = DateTime.utc(
    ritualToday.year,
    ritualToday.month,
    ritualToday.day,
  ).subtract(Duration(days: offset));
  return StreakDay(moment.year, moment.month, moment.day);
}

/// Серия из [days] дней, последний засчитанный — [lastOffset] суток назад
/// (0 — сегодня).
StreakView ritualView({
  int days = 0,
  int lastOffset = 0,
  int? best,
  int freezes = 0,
  int daysSinceFreeze = 0,
  int? frozenOffset,
}) => streakAsOf(
  StreakState(
    current: days,
    best: best ?? days,
    lastDay: days == 0 ? null : daysAgo(lastOffset),
    freezes: freezes,
    daysSinceFreeze: daysSinceFreeze,
    lastFrozenDay: frozenOffset == null ? null : daysAgo(frozenOffset),
  ),
  ritualToday,
);
