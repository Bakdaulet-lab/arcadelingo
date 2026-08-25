/// Ряд дней для полосы прогресса: сводки хранилища, достроенные нулями.
///
/// `AnswerLog.perDay` не возвращает дней без ответов, и это его правильное
/// поведение: отсутствие дня — тоже ответ, а достраивать пустые обязан тот,
/// кто рисует. Здесь это и делается — чистой функцией, потому что «ровно
/// четырнадцать штук в календарном порядке» проверяется таблицей, а не
/// разглядыванием столбиков.
library;

import '../log/answer_record.dart';
import '../streak/streak.dart';

/// Сводки за каждый день отрезка [from]..[to] включительно.
///
/// Дни, которых нет в [tallies], приходят нулями. Порядок календарный,
/// независимо от того, в каком порядке пришли сводки.
///
/// Бросает [ArgumentError], если [to] раньше [from]: перевёрнутый отрезок —
/// ошибка вызывающего, а не исход работы.
List<DayTally> fillDays({
  required List<DayTally> tallies,
  required StreakDay from,
  required StreakDay to,
}) {
  if (to.compareTo(from) < 0) {
    throw ArgumentError('отрезок перевёрнут: $from..$to');
  }
  final byDay = {for (final tally in tallies) tally.day: tally};
  final series = <DayTally>[];
  var day = from;
  while (true) {
    series.add(byDay[day] ?? DayTally(day: day, answers: 0, correct: 0));
    if (day == to) break;
    day = day.next;
  }
  return series;
}
