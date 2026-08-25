/// Настройки напоминания: включено ли и в котором часу.
///
/// Своё время суток, а не `TimeOfDay` из Material: `lib/domain/` не знает
/// Flutter вовсе, и это пункт 1 «Архитектурного закона», который с Фазы 2
/// проверяется скриптом.
library;

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

/// Что человек выбрал про напоминания.
class ReminderSettings {
  const ReminderSettings({required this.enabled, required this.at});

  /// Умолчание: **выключено**.
  ///
  /// Приложение, спрашивающее разрешение на уведомления до того, как человек
  /// о них попросил, — приложение, которому отказывают. Разрешение
  /// спрашивается в момент включения, и до этого момента напоминаний нет.
  ///
  /// Восемь вечера — просто час, с которого начинают: он ничем не обоснован,
  /// кроме того, что его удобно двигать. Замер Фазы 3 покажет, туда ли.
  static const ReminderSettings defaults = ReminderSettings(
    enabled: false,
    at: ReminderTime(20, 0),
  );

  final bool enabled;
  final ReminderTime at;

  ReminderSettings copyWith({bool? enabled, ReminderTime? at}) =>
      ReminderSettings(enabled: enabled ?? this.enabled, at: at ?? this.at);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderSettings && enabled == other.enabled && at == other.at;

  @override
  int get hashCode => Object.hash(enabled, at);

  @override
  String toString() => 'ReminderSettings(enabled: $enabled, at: $at)';
}
