/// Слова напоминания: во что превращается решение политики.
///
/// В `lib/ui/`, а не в домене, и это не педантичность: первая версия
/// собирала текст прямо в политике и утащила `lib/domain` в импорт
/// `lib/ui/streak_label.dart` ради русского счёта дней. Домен решает
/// «когда и почему», презентация — «какими словами»; арх-гейт с 3.5 это
/// проверяет.
///
/// Разница между вариантами и есть тот рычаг, ради которого фаза
/// существует: «Серия 5 дней под угрозой» бьёт сильнее, чем «пора
/// позаниматься».
library;

import 'package:arcadelingo/domain/reminders/reminder_policy.dart';
import 'package:arcadelingo/ui/streak_label.dart';

/// Заголовок и текст уведомления для запланированного напоминания.
(String title, String body) reminderText(ReminderPlan plan) => switch (plan
    .reason) {
  ReminderReason.atRisk => (
    '${streakLabel(plan.days)} под угрозой',
    'Сыграй сегодня — заморозка прикроет вчерашний пропуск',
  ),
  ReminderReason.keepGoing => (
    streakLabel(plan.days),
    'Одна партия — и день засчитан',
  ),
  ReminderReason.start => (
    'Пора вернуться',
    'Одна партия, и серия начнётся заново',
  ),
};
