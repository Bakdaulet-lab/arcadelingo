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
    final tomorrow = DateTime.utc(
      year,
      month,
      day,
    ).add(const Duration(days: 1));
    return StreakDay(tomorrow.year, tomorrow.month, tomorrow.day);
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
  /// Больше одной заморозки в запасе не бывает: две подряд прощённые недели
  /// превращают серию в счётчик установок приложения.
  static const int maxFreezes = 1;

  /// Бросает [ArgumentError] на отрицательных счётчиках и на `best`
  /// меньше `current`: это не исход работы, а повреждённое состояние.
  StreakState({
    this.current = 0,
    this.best = 0,
    this.lastDay,
    this.freezes = 0,
    this.daysSinceFreeze = 0,
    this.lastFrozenDay,
  }) {
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
    if (freezes < 0 || freezes > maxFreezes) {
      throw ArgumentError('заморозок $freezes вне 0..$maxFreezes');
    }
    if (daysSinceFreeze < 0) {
      throw ArgumentError('дней к заморозке отрицательное: $daysSinceFreeze');
    }
    if (freezes == maxFreezes && daysSinceFreeze != 0) {
      throw ArgumentError(
        'заморозка уже в запасе, копить нечего: $daysSinceFreeze',
      );
    }
    final frozen = lastFrozenDay;
    if (frozen != null) {
      final last = lastDay;
      if (last == null || frozen.compareTo(last) >= 0) {
        throw ArgumentError(
          'замороженный день $frozen не раньше последнего сыгранного $last',
        );
      }
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

  /// Заморозок в запасе: 0 или 1 ([maxFreezes]).
  ///
  /// Заморозка прощает **ровно один** пропущенный день и тратится не в
  /// полночь, а задним числом — в момент следующей игры. Иначе и быть не
  /// может: в полночь у нас ничего не выполняется.
  final int freezes;

  /// Сколько засчитанных дней прошло с последней траты.
  ///
  /// Копится только пока заморозки нет: при `freezes == maxFreezes` всегда
  /// ноль, и это инвариант конструктора, а не соглашение.
  final int daysSinceFreeze;

  /// День, который прикрыла заморозка, — или null, если в текущей серии
  /// такого не было.
  ///
  /// Хранится ради одного: молча потраченная заморозка не существует для
  /// игрока. Он обязан узнать и что его спасли, и какой ценой
  /// (`streak_view.dart`). Обрыв серии обнуляет поле вместе с ней: у новой
  /// серии замороженных дней нет.
  final StreakDay? lastFrozenDay;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakState &&
          current == other.current &&
          best == other.best &&
          lastDay == other.lastDay &&
          freezes == other.freezes &&
          daysSinceFreeze == other.daysSinceFreeze &&
          lastFrozenDay == other.lastFrozenDay;

  @override
  int get hashCode => Object.hash(
    current,
    best,
    lastDay,
    freezes,
    daysSinceFreeze,
    lastFrozenDay,
  );

  @override
  String toString() =>
      'StreakState(current: $current, best: $best, lastDay: $lastDay, '
      'freezes: $freezes, daysSinceFreeze: $daysSinceFreeze, '
      'lastFrozenDay: $lastFrozenDay)';
}

/// Сколько засчитанных дней нужно, чтобы заработать заморозку.
///
/// Считаются именно засчитанные дни, а не календарные: заморозка — награда за
/// игру, а не за то, что прошла неделя. Обрыв серии счётчик не обнуляет —
/// человек эти дни отыграл, и отнимать их за один пропуск значило бы наказать
/// дважды.
const int daysToEarnFreeze = 7;

/// Состояние после игры в [day].
///
/// Пять случаев, и других нет:
/// - день **не позже** последнего засчитанного — состояние возвращается
///   **тем же самым**, по `==`. Сюда попадают и вторая партия за день, и
///   часы, переведённые назад, и перелёт на запад: ни то, ни другое, ни
///   третье не пропуск, и обрывать за них серию не за что. Фаза 2 обрывала и
///   оставила смягчение этой фазе;
/// - следующий календарный день — серия продлевается;
/// - пропущен **ровно один** день и заморозка в запасе есть — заморозка
///   тратится, серия растёт на два: сыгранный сегодня и прикрытый вчерашний.
///   Замороженный день идёт в счёт серии — иначе прощение выглядело бы как
///   наказание помягче, а не как прощение;
/// - пропущено два дня и больше — серия с единицы, каким бы ни был запас:
///   заморозка прощает один день, и растягивать её на два значит перестать
///   называть серию серией;
/// - пропуск без заморозки — серия с единицы.
///
/// Заморозка тратится **задним числом**, в момент игры, а не в полночь: в
/// полночь у нас ничего не выполняется. Отсюда же следует, что до следующей
/// игры состояние о пропуске не знает, и показывать серию как есть нельзя —
/// для этого есть `streak_view.dart`.
///
/// `best` держит максимум и разрывом не сбрасывается.
///
/// **Чем именно день был засчитан, переход не знает и не спрашивает.**
/// Законченная партия и экран «на сегодня всё» приходят сюда одинаково: игрок
/// в обоих случаях сделал всё, что система позволила, а разложенный по
/// коробкам Лейтнер делает пустые дни неизбежными. Второй ветки правил не
/// существует — значит и разойтись им негде. Кто зовёт этот путь, решает хост.
StreakState advanceStreak(StreakState state, StreakDay day) {
  final last = state.lastDay;
  // Не позже последнего засчитанного — считать нечего.
  if (last != null && day.compareTo(last) <= 0) return state;

  final int current;
  var freezes = state.freezes;
  var frozenDay = state.lastFrozenDay;

  if (last == null) {
    current = 1;
  } else if (day == last.next) {
    current = state.current + 1;
  } else if (day == last.next.next && freezes > 0) {
    freezes -= 1;
    frozenDay = last.next;
    current = state.current + 2;
  } else {
    current = 1;
    // У новой серии замороженных дней нет: тот, что был, спасал серию,
    // которой больше не существует.
    frozenDay = null;
  }

  // Начисление идёт после траты, поэтому сегодняшний сыгранный день уже
  // работает на следующую заморозку. Обрыв серии счётчик не трогает: эти дни
  // человек отыграл.
  var daysSinceFreeze = state.daysSinceFreeze;
  if (freezes < StreakState.maxFreezes) {
    daysSinceFreeze += 1;
    if (daysSinceFreeze >= daysToEarnFreeze) {
      freezes += 1;
      daysSinceFreeze = 0;
    }
  }

  return StreakState(
    current: current,
    best: current > state.best ? current : state.best,
    lastDay: day,
    freezes: freezes,
    daysSinceFreeze: daysSinceFreeze,
    lastFrozenDay: frozenDay,
  );
}
