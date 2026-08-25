/// Когда напоминать и почему — чистая функция от состояния и часов.
///
/// Здесь нет ни платформы, ни плагина, ни зон: только «в какой момент» и «по
/// какому поводу». Ради этого порт [Reminders] и заведён — вся политика
/// проверяется таблицей, а адаптеру остаётся отдать момент платформе.
///
/// Главное решение файла: **повод считается на тот день, в который
/// напоминание сработает**, а не на сегодняшний. Напоминание, поставленное
/// вечером на завтра, сработает в мире, где серия на день старше; повод,
/// посчитанный сегодня, говорил бы про сегодняшнее состояние. Пересчёт
/// делает та же `streakAsOf`, что рисует домашний экран, — второй трактовки
/// «что с серией» в проекте нет.
///
/// Слов здесь нет вовсе: политика отвечает «когда и почему», а «какими
/// словами» — презентация (`lib/ui/reminder_labels.dart`). Первая версия
/// собирала текст прямо здесь и утащила `lib/domain` в импорт `lib/ui` ради
/// русского счёта дней; арх-гейт это пропустил, и правило пришлось дописать
/// (`docs/dev/context.md`).
library;

import '../streak/streak.dart';
import '../streak/streak_view.dart';
import 'reminder_settings.dart';

/// Зачем напоминаем. От этого зависят слова, и только они.
enum ReminderReason {
  /// Серии нет или она к тому моменту оборвётся: зовём начать.
  start,

  /// Серия жива, и в тот день ещё не сыграно: зовём продолжить.
  keepGoing,

  /// Пропущен день, и заморозка его прикроет, если сыграть.
  atRisk,
}

/// Готовое напоминание: момент, повод и длина серии на этот момент.
class ReminderPlan {
  const ReminderPlan({
    required this.at,
    required this.reason,
    required this.days,
  });

  /// Момент в местной зоне.
  final DateTime at;

  final ReminderReason reason;

  /// Сколько дней будет в серии в день срабатывания; ноль — серии не будет.
  final int days;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderPlan &&
          at == other.at &&
          reason == other.reason &&
          days == other.days;

  @override
  int get hashCode => Object.hash(at, reason, days);

  @override
  String toString() => 'ReminderPlan($at, ${reason.name}, дней: $days)';
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
  if (!settings.enabled) return null;

  final todayAt = settings.at.on(now);
  final playedToday = streakAsOf(streak, StreakDay.of(now)).playedToday;
  final at =
      !playedToday && now.isBefore(todayAt)
          ? todayAt
          : settings.at.on(now.add(const Duration(days: 1)));

  // Состояние на день срабатывания, а не на сегодня.
  final view = streakAsOf(streak, StreakDay.of(at));
  return ReminderPlan(at: at, reason: reasonFor(view), days: view.days);
}

/// Зачем напоминать при таком состоянии серии.
///
/// Отдельной функцией, потому что различие — решение, а не вёрстка: «серия
/// под угрозой» бьёт сильнее, чем «пора позаниматься», и разница между ними
/// и есть то, ради чего фаза существует. Во что это превратится словами,
/// решает `lib/ui/reminder_labels.dart`.
ReminderReason reasonFor(StreakView view) {
  if (view.freezeWillCover) return ReminderReason.atRisk;
  return view.alive ? ReminderReason.keepGoing : ReminderReason.start;
}
