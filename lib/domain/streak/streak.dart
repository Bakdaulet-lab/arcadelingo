/// Серия дней подряд: календарный день, состояние и чистый переход.
///
/// Правила Фазы 2 — только форма и три случая: тот же день ничего не меняет,
/// следующий календарный продлевает серию, всё остальное её обрывает.
/// Заморозка, часовой пояс и «что вообще считается днём» — Фаза 3; здесь их
/// нет намеренно, чтобы хранилище было готово раньше правил.
///
/// Чистый слой: ни часов, ни хранилища. День приходит параметром, как время
/// приходит в `srs/`.
library;

/// Локальная календарная дата — без времени и **без зоны**.
///
/// Это сознательная противоположность правилу `LeitnerCard.due`, где строка
/// без обозначения зоны считается битыми данными. Разница не в аккуратности,
/// а в природе величины: у `due` есть момент, и зона определяет, какой
/// именно; у «дня» момента нет — он и есть локальный календарный день того,
/// кто играл. Зону здесь просто нечему обозначать, и тип устроен так, что
/// её невозможно записать (`docs/dev/context.md`).
class StreakDay implements Comparable<StreakDay> {
  /// Бросает [ArgumentError] на несуществующей дате: 13-й месяц, 31 февраля.
  ///
  /// Как и у `LeitnerCard`, конструктор сторожит инвариант, а не разбирает
  /// хранилище: битую запись обязан отсеять кодек — для этого есть
  /// [tryCreate], который возвращает null вместо броска.
  StreakDay(this.year, this.month, this.day) {
    if (_normalize(year, month, day) == null) {
      throw ArgumentError('несуществующая дата: $year-$month-$day');
    }
  }

  /// День, в который случился [moment], в его собственной зоне.
  ///
  /// Никакого `toUtc()`: играл человек в своей полуночи, а не в гринвичской.
  factory StreakDay.of(DateTime moment) =>
      StreakDay(moment.year, moment.month, moment.day);

  /// Дата или null, если такой не существует. Для кодека: он обязан отдать
  /// `Err`, а не поймать [ArgumentError].
  static StreakDay? tryCreate(int year, int month, int day) =>
      _normalize(year, month, day) == null ? null : StreakDay(year, month, day);

  final int year;
  final int month;
  final int day;

  /// Следующий календарный день.
  ///
  /// Считается через `DateTime.utc`, и это не противоречие «дню без зоны»:
  /// UTC здесь взят как календарь, а не как момент. У него нет переходов на
  /// летнее время, поэтому «плюс сутки» всегда даёт следующую дату. То же
  /// сложение на локальном `DateTime` в ночь перевода стрелок дало бы тот же
  /// день или пропустило бы один — и серия порвалась бы дважды в год.
  StreakDay get next {
    throw UnimplementedError();
  }

  static DateTime? _normalize(int year, int month, int day) {
    final probe = DateTime.utc(year, month, day);
    if (probe.year != year || probe.month != month || probe.day != day) {
      return null;
    }
    return probe;
  }

  @override
  int compareTo(StreakDay other) {
    final byYear = year.compareTo(other.year);
    if (byYear != 0) return byYear;
    final byMonth = month.compareTo(other.month);
    return byMonth != 0 ? byMonth : day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakDay &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '$year-${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

/// Состояние серии.
///
/// Значимый объект: сравнивается по полям, чтобы «тот же день ничего не
/// изменил» проверялось одним `expect`, а наблюдатель мог не писать в
/// хранилище, когда писать нечего.
class StreakState {
  /// Бросает [ArgumentError] на отрицательных счётчиках и на `best`
  /// меньше `current`: это не исход работы, а повреждённое состояние.
  StreakState({this.current = 0, this.best = 0, this.lastDay}) {
    if (current < 0 || best < 0) {
      throw ArgumentError('серия отрицательной длины: $current/$best');
    }
    if (best < current) {
      throw ArgumentError('лучшая серия $best меньше текущей $current');
    }
    if ((current == 0) != (lastDay == null)) {
      throw ArgumentError(
        'серия $current и последний день $lastDay не согласованы',
      );
    }
  }

  /// Ещё ни одного дня.
  static final StreakState empty = StreakState();

  /// Сколько дней подряд человек играл, считая последний.
  final int current;

  /// Самая длинная серия за всё время. Разрыв её не сбрасывает — в этом
  /// весь смысл поля.
  final int best;

  /// Последний засчитанный день; null только у [empty].
  final StreakDay? lastDay;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakState &&
          current == other.current &&
          best == other.best &&
          lastDay == other.lastDay;

  @override
  int get hashCode => Object.hash(current, best, lastDay);

  @override
  String toString() =>
      'StreakState(current: $current, best: $best, lastDay: $lastDay)';
}

/// Состояние после игры в [day].
///
/// Три случая, и других нет:
/// - тот же день — состояние возвращается **тем же самым**, по `==`;
/// - следующий календарный день — серия продлевается;
/// - всё остальное — серия начинается заново с единицы.
///
/// «Всё остальное» включает и день **раньше** последнего: часы, переведённые
/// назад, или перелёт на запад обрывают серию так же, как пропуск. Это
/// решение, а не недосмотр — оно закреплено тестом. Мягче обходиться с таким
/// случаем должна Фаза 3 вместе с заморозкой и часовым поясом.
///
/// `best` держит максимум и разрывом не сбрасывается.
StreakState advanceStreak(StreakState state, StreakDay day) {
  throw UnimplementedError();
}
