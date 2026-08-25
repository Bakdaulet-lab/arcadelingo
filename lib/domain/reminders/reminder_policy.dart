/// Когда напоминать и что говорить — чистая функция от состояния и часов.
///
/// Здесь нет ни платформы, ни плагина, ни зон: только «в какой момент» и
/// «какими словами». Ради этого порт [Reminders] и заведён — вся политика
/// проверяется таблицей, а адаптеру остаётся отдать момент платформе.
///
/// Главное решение файла: **текст считается на тот день, в который
/// напоминание сработает**, а не на сегодняшний. Напоминание, поставленное
/// вечером на завтра, сработает в мире, где серия на день старше; текст,
/// посчитанный сегодня, сказал бы про сегодняшнее состояние. Пересчёт делает
/// та же `streakAsOf`, что рисует домашний экран, — второй трактовки «что с
/// серией» в проекте нет.
library;

import '../streak/streak.dart';
import '../streak/streak_view.dart';
import 'reminder_settings.dart';

/// Готовое напоминание: момент и слова.
class ReminderPlan {
  const ReminderPlan({
    required this.at,
    required this.title,
    required this.body,
  });

  /// Момент в местной зоне.
  final DateTime at;

  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderPlan &&
          at == other.at &&
          title == other.title &&
          body == other.body;

  @override
  int get hashCode => Object.hash(at, title, body);

  @override
  String toString() => 'ReminderPlan($at: $title / $body)';
}

/// Что поставить в расписание сейчас, или null — ставить нечего.
///
/// Три случая, и других нет:
/// - напоминания выключены — null;
/// - сегодня ещё не сыграно и время сегодня ещё не прошло — сегодня;
/// - иначе — завтра.
///
/// «Иначе» включает и «сегодня уже сыграно», и «время прошло». Ровно в
/// назначенный момент напоминание уходит на завтра: уведомление о
/// приложении, которое человек держит открытым, — не напоминание.
ReminderPlan? planReminder({
  required ReminderSettings settings,
  required StreakState streak,
  required DateTime now,
}) {
  throw UnimplementedError('planReminder');
}

/// Слова напоминания по состоянию серии на день, когда оно сработает.
///
/// Отдельной функцией, потому что варианты — это решение, а не вёрстка:
/// «Серия 5 дней под угрозой» бьёт сильнее, чем «пора позаниматься», и
/// разница между ними и есть то, ради чего фаза существует.
(String title, String body) reminderText(StreakView view) {
  throw UnimplementedError('reminderText');
}
