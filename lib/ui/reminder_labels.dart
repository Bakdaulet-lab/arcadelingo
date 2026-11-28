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
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/streak_label.dart';

/// Заголовок и текст уведомления для запланированного напоминания.
(String title, String body) reminderText(
  ReminderPlan plan, {
  AppStrings strings = russianStrings,
}) => switch (plan.reason) {
  ReminderReason.atRisk => (
    switch (strings.language) {
      InterfaceLanguage.english => 'Your ${plan.days}-day streak is at risk',
      InterfaceLanguage.spanish =>
        'Tu racha de ${plan.days} ${spanishDayWord(plan.days)} está en riesgo',
      InterfaceLanguage.kazakh => '${plan.days} күндік серия үзілуі мүмкін',
      InterfaceLanguage.russian ||
      InterfaceLanguage.system => '${streakLabel(plan.days)} под угрозой',
    },
    strings.reminderSavedByFreeze,
  ),
  ReminderReason.keepGoing => (
    streakLabel(plan.days, strings: strings),
    strings.oneRoundCounts,
  ),
  ReminderReason.start => (strings.timeToReturn, strings.restartStreak),
};
