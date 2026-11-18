/// Подпись серии на домашнем экране.
///
/// Отдельной чистой функцией, а не строкой в виджете, из-за русского счёта:
/// «1 день», «2 дня», «5 дней», и снова «21 день». Заглушка Фазы 2 с
/// «Серия: 1 дней» была бы заглушкой, которую видит пользователь.
library;

import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/ui/app_strings.dart';

/// «Серия: N дней» с правильной формой слова.
String streakLabel(int days, {AppStrings strings = russianStrings}) =>
    switch (strings.language) {
      InterfaceLanguage.english => 'Streak: $days ${englishDayWord(days)}',
      InterfaceLanguage.spanish => 'Racha: $days ${spanishDayWord(days)}',
      InterfaceLanguage.russian ||
      InterfaceLanguage.system => 'Серия: $days ${dayWord(days)}',
    };

String englishDayWord(int days) => days == 1 ? 'day' : 'days';
String spanishDayWord(int days) => days == 1 ? 'día' : 'días';

/// Форма слова «день» при числе [n].
///
/// Одиннадцать–четырнадцать проверяются до последней цифры и ломают наивное
/// «смотрим на единицу в конце»: 11 — «дней», хотя кончается на 1.
///
/// Публичная с Фазы 3: та же форма понадобилась строке «заморозка вернётся
/// через N дней», а вторая копия русского счёта разошлась бы с первой.
String dayWord(int n) {
  final lastTwo = n.abs() % 100;
  if (lastTwo >= 11 && lastTwo <= 14) return 'дней';
  return switch (n.abs() % 10) {
    1 => 'день',
    2 || 3 || 4 => 'дня',
    _ => 'дней',
  };
}
