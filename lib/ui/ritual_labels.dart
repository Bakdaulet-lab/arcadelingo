/// Тексты дневного ритуала: что домашний экран говорит человеку.
///
/// Чистые функции от [StreakView], а не строки внутри виджета, — по той же
/// причине, что и `streakLabel`: у них есть варианты, и варианты надо
/// проверять таблицей, а не разглядыванием экрана.
///
/// Решения, а не оформление, живут здесь ровно одно: **заморозка называется
/// вслух**. Молча потраченная заморозка не существует для игрока — он обязан
/// узнать и что его спасли, и какой ценой. Поэтому три состояния запаса
/// различимы текстом, а не отсутствием строки.
library;

import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/domain/streak/streak_view.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/streak_label.dart';

/// Надпись на главной кнопке.
///
/// Кнопка — это и есть приглашение, и оно разное: начать, продолжить,
/// спасти или сыграть ещё раз. «Играть» на всех четырёх случаях сразу
/// превратило бы ритуал обратно в экран с кнопкой.
String ritualCallToAction(
  StreakView view, {
  AppStrings strings = russianStrings,
}) {
  if (view.playedToday) return strings.playAnotherRound;
  if (view.freezeWillCover) return strings.saveStreak;
  if (view.alive) return strings.continueStreak;
  return strings.play;
}

/// Что с сегодняшним днём: засчитан или ещё нет.
String ritualTodayLabel(
  StreakView view, {
  AppStrings strings = russianStrings,
}) => view.playedToday ? strings.playedToday : strings.notPlayedToday;

/// Подпись под пламенем, или null — показывать нечего.
///
/// **Без числа**: число уже нарисовано в самом пламени крупно, и повторить
/// его строкой значило бы сказать одно и то же дважды. Подпись объясняет,
/// что это за число: «5» плюс «дней подряд» читается сверху вниз одной
/// фразой.
///
/// Ноль дней это не «0 дней подряд», а отсутствие подписи: у человека,
/// который ещё не играл, и у человека, который серию оборвал, на экране
/// одинаково пусто. Разница между ними — в кнопке, а не в счётчике.
String? ritualStreakLabel(
  StreakView view, {
  AppStrings strings = russianStrings,
}) =>
    view.days == 0
        ? null
        : switch (strings.language) {
          InterfaceLanguage.english => '${englishDayWord(view.days)} in a row',
          InterfaceLanguage.spanish =>
            view.days == 1 ? 'día seguido' : 'días seguidos',
          InterfaceLanguage.kazakh => 'күн қатарынан',
          InterfaceLanguage.russian ||
          InterfaceLanguage.system => '${dayWord(view.days)} подряд',
        };

/// Состояние запаса заморозок словами, или null — говорить нечего.
String? ritualFreezeLabel(
  StreakView view, {
  AppStrings strings = russianStrings,
}) {
  // До первой партии говорить не о чем: человек ещё не знает ни про серию,
  // ни про заморозку, и «вернётся через семь дней» было бы обещанием
  // непонятно чего.
  if (view.best == 0) return null;
  if (view.freeze.available) return strings.freezeAvailable;
  final spent = view.freeze.spentOn;
  if (spent != null) {
    if (strings.language == InterfaceLanguage.spanish) {
      const months = [
        'enero',
        'febrero',
        'marzo',
        'abril',
        'mayo',
        'junio',
        'julio',
        'agosto',
        'septiembre',
        'octubre',
        'noviembre',
        'diciembre',
      ];
      return 'Protección usada el ${spent.day} de ${months[spent.month - 1]}';
    }
    if (strings.language == InterfaceLanguage.english) {
      final month =
          const [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ][spent.month - 1];
      return 'Streak Freeze used for $month ${spent.day}';
    }
    if (strings.language == InterfaceLanguage.kazakh) {
      final month =
          const [
            'қаңтар',
            'ақпан',
            'наурыз',
            'сәуір',
            'мамыр',
            'маусым',
            'шілде',
            'тамыз',
            'қыркүйек',
            'қазан',
            'қараша',
            'желтоқсан',
          ][spent.month - 1];
      return 'Серия қорғанысы қолданылды · ${spent.day} $month';
    }
    return 'Заморозка потрачена за '
        '${spent.day} ${monthInGenitive(spent.month)}';
  }
  final left = view.freeze.daysToNext;
  return switch (strings.language) {
    InterfaceLanguage.english =>
      'Streak Freeze returns in $left ${englishDayWord(left)}',
    InterfaceLanguage.spanish =>
      'Recuperas la protección en $left ${spanishDayWord(left)}',
    InterfaceLanguage.kazakh => 'Серия қорғанысы $left күннен кейін жаңарады',
    InterfaceLanguage.russian || InterfaceLanguage.system =>
      'Заморозка вернётся через $left ${dayWord(left)}',
  };
}

/// Название месяца в родительном падеже: «27 **августа**».
///
/// Своя таблица, а не `intl`: двенадцать строк против пакета с локалями,
/// который в проекте больше никому не нужен. Появится второй потребитель дат
/// — вернуться к вопросу.
String monthInGenitive(int month) =>
    const [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ][month - 1];
