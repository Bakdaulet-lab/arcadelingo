/// Настройки напоминания: включено ли и в котором часу.
///
/// Своё время суток, а не `TimeOfDay` из Material: `lib/domain/` не знает
/// Flutter вовсе, и это пункт 1 «Архитектурного закона», который с Фазы 2
/// проверяется скриптом.
library;

import '../review/study_course.dart';

enum InterfaceLanguage {
  system('system'),
  russian('ru'),
  english('en'),
  spanish('es'),
  kazakh('kk');

  const InterfaceLanguage(this.tag);
  final String tag;

  static InterfaceLanguage fromTag(Object? value) =>
      values.where((language) => language.tag == value).firstOrNull ?? system;
}

enum AppTheme {
  dark,
  light;

  static AppTheme fromTag(Object? value) => value == light.name ? light : dark;
}

/// Время суток без даты и без зоны.
///
/// Зоны здесь нет по той же причине, что у `StreakDay`: «восемь вечера» — это
/// не момент, а договорённость с человеком. В какой момент она превратится
/// сегодня, решает тот, у кого есть часы.
class ReminderTime {
  /// Бросает [ArgumentError] на несуществующем времени: инвариант сторожит
  /// конструктор, а разбирает хранилище кодек.
  const ReminderTime(this.hour, this.minute)
    : assert(hour >= 0 && hour <= 23, 'час вне 0..23'),
      assert(minute >= 0 && minute <= 59, 'минута вне 0..59');

  final int hour;
  final int minute;

  /// Время или null, если такого не бывает. Для кодека: он обязан отдать
  /// `Err`, а не поймать ошибку.
  static ReminderTime? tryCreate(int hour, int minute) =>
      hour < 0 || hour > 23 || minute < 0 || minute > 59
          ? null
          : ReminderTime(hour, minute);

  /// Тот же день, но в это время.
  DateTime on(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderTime && hour == other.hour && minute == other.minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Настройки напоминаний, звука, языка, курса и темы хранятся одним документом.
class AppSettings {
  const AppSettings({
    required this.enabled,
    required this.at,
    this.soundOn = true,
    this.interfaceLanguage = InterfaceLanguage.system,
    this.courseId = StudyCourse.englishFromRussianId,
    this.theme = AppTheme.dark,
  });

  /// Умолчание: **выключено**.
  ///
  /// Приложение, спрашивающее разрешение на уведомления до того, как человек
  /// о них попросил, — приложение, которому отказывают. Разрешение
  /// спрашивается в момент включения, и до этого момента напоминаний нет.
  ///
  /// Восемь вечера — просто час, с которого начинают: он ничем не обоснован,
  /// кроме того, что его удобно двигать. Замер Фазы 3 покажет, туда ли.
  static const AppSettings defaults = AppSettings(
    enabled: false,
    at: ReminderTime(20, 0),
    soundOn: true,
  );

  final bool enabled;
  final ReminderTime at;

  /// Звук в играх. Умолчание — **включён**, в отличие от напоминаний.
  ///
  /// Разница не в настроении, а в цене: напоминание стучится в человека
  /// само и требует разрешения системы, звук звучит только пока человек
  /// держит игру открытой, и беззвучный режим телефона его глушит без
  /// всяких настроек.
  final bool soundOn;
  final InterfaceLanguage interfaceLanguage;
  final String courseId;
  final AppTheme theme;

  AppSettings copyWith({
    bool? enabled,
    ReminderTime? at,
    bool? soundOn,
    InterfaceLanguage? interfaceLanguage,
    String? courseId,
    AppTheme? theme,
  }) => AppSettings(
    enabled: enabled ?? this.enabled,
    at: at ?? this.at,
    soundOn: soundOn ?? this.soundOn,
    interfaceLanguage: interfaceLanguage ?? this.interfaceLanguage,
    courseId: courseId ?? this.courseId,
    theme: theme ?? this.theme,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          enabled == other.enabled &&
          at == other.at &&
          soundOn == other.soundOn &&
          interfaceLanguage == other.interfaceLanguage &&
          courseId == other.courseId &&
          theme == other.theme;

  @override
  int get hashCode =>
      Object.hash(enabled, at, soundOn, interfaceLanguage, courseId, theme);

  @override
  String toString() =>
      'AppSettings(enabled: $enabled, at: $at, soundOn: $soundOn)';
}
