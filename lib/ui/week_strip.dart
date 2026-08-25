/// Полоса недели под пламенем: семь дней и что с каждым из них.
///
/// Календарная неделя с понедельника, а не скользящее окно в семь суток. У
/// календарной недели есть будущее, и «сколько ещё осталось» человек читает
/// с неё сам; у окна, кончающегося сегодня, будущего нет вовсе.
///
/// Чистая функция, как и решения про пламя: рисование получает готовый
/// список и ничего не решает.
library;

import 'package:arcadelingo/domain/streak/streak.dart';

/// Что с днём недели.
enum WeekDayState {
  /// Партия в этот день дошла до конца.
  played,

  /// День прикрыт заморозкой: играть было некогда, а серия уцелела.
  frozen,

  /// День прошёл, и партии в нём не было.
  missed,

  /// Сегодня, и сегодня ещё не сыграно.
  pending,

  /// День ещё не наступил.
  future,
}

/// Один кружок полосы.
class WeekDay {
  const WeekDay({
    required this.day,
    required this.letter,
    required this.state,
    required this.isToday,
  });

  final StreakDay day;

  /// Буква для кружка: Пн, Вт, …
  final String letter;

  final WeekDayState state;

  /// Кольцо «где я». Ставится **независимо** от [state]: кольцо отвечает на
  /// «где я», заливка — на «что сделано», и совмещать их в одном признаке
  /// значит однажды потерять один из двух ответов.
  final bool isToday;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeekDay &&
          day == other.day &&
          letter == other.letter &&
          state == other.state &&
          isToday == other.isToday;

  @override
  int get hashCode => Object.hash(day, letter, state, isToday);

  @override
  String toString() => 'WeekDay($letter $day, ${state.name}, today: $isToday)';
}

/// Буквы дней недели по индексу `weekday - 1`.
const List<String> weekdayLetters = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// Семь дней календарной недели, в которую попадает [today].
///
/// [played] — дни, в которые партия дошла до конца; приходят из журнала
/// событий, а не выводятся из длины серии. Человек, игравший в понедельник и
/// вторник, сорвавшийся в среду и вернувшийся в четверг, обязан увидеть
/// галочки на понедельнике и вторнике — вывод из `current` показал бы там
/// пустые кружки (`SPEC.md`).
///
/// [frozen] — день, прикрытый заморозкой; журнал о нём не знает, потому что в
/// этот день ничего не происходило.
List<WeekDay> weekStrip({
  required StreakDay today,
  required Set<StreakDay> played,
  StreakDay? frozen,
}) {
  throw UnimplementedError('weekStrip');
}
