// Полоса недели: семь дней и что с каждым.
//
// Календарная неделя с понедельника, а не окно в семь суток — у календарной
// есть будущее. Границы месяца и года здесь не «на всякий случай»: неделя,
// начавшаяся 30 декабря, кончается в следующем году, и наивная арифметика
// ломается именно там.

import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/ui/week_strip.dart';
import 'package:flutter_test/flutter_test.dart';

/// Среда, 26 августа 2026.
final StreakDay _wed = StreakDay(2026, 8, 26);

/// Понедельник той же недели.
final StreakDay _mon = StreakDay(2026, 8, 24);

StreakDay _plus(StreakDay day, int days) {
  var result = day;
  for (var i = 0; i < days; i++) {
    result = result.next;
  }
  return result;
}

void main() {
  group('Форма недели', () {
    test('семь дней, с понедельника по воскресенье', () {
      final week = weekStrip(today: _wed, played: const {});

      expect(week, hasLength(7));
      expect(week.first.day, _mon);
      expect(week.last.day, StreakDay(2026, 8, 30));
      expect(week.map((d) => d.letter), weekdayLetters);
    });

    test('в понедельник неделя начинается с него же', () {
      final week = weekStrip(today: _mon, played: const {});

      expect(week.first.day, _mon);
      expect(week.first.isToday, isTrue);
    });

    test('в воскресенье неделя кончается сегодняшним днём', () {
      final sunday = StreakDay(2026, 8, 30);

      final week = weekStrip(today: sunday, played: const {});

      expect(week.last.day, sunday);
      expect(week.last.isToday, isTrue);
      expect(week.first.day, _mon);
    });

    test('неделя через границу месяца', () {
      // 1 сентября 2026 — вторник; неделя начинается 31 августа.
      final week = weekStrip(today: StreakDay(2026, 9, 1), played: const {});

      expect(week.first.day, StreakDay(2026, 8, 31));
      expect(week.last.day, StreakDay(2026, 9, 6));
    });

    test('неделя через границу года', () {
      // 1 января 2027 — пятница; неделя начинается 28 декабря 2026.
      final week = weekStrip(today: StreakDay(2027, 1, 1), played: const {});

      expect(week.first.day, StreakDay(2026, 12, 28));
      expect(week.last.day, StreakDay(2027, 1, 3));
    });
  });

  group('Сегодня', () {
    test('помечен ровно один день', () {
      final week = weekStrip(today: _wed, played: const {});

      expect(week.where((d) => d.isToday), hasLength(1));
      expect(week.firstWhere((d) => d.isToday).day, _wed);
    });

    // Кольцо отвечает на «где я», заливка — на «что сделано». Совмещать их в
    // одном признаке значит однажды потерять один из двух ответов.
    test('пометка стоит и на сыгранном сегодня', () {
      final week = weekStrip(today: _wed, played: {_wed});

      final today = week.firstWhere((d) => d.isToday);
      expect(today.state, WeekDayState.played);
      expect(today.isToday, isTrue);
    });

    test('сегодня без партии — ждёт, а не пропущен', () {
      final week = weekStrip(today: _wed, played: const {});

      expect(week[2].state, WeekDayState.pending);
    });
  });

  group('Состояния дней', () {
    test('сыгранные приходят из журнала, а не выводятся', () {
      // Понедельник и вторник сыграны, среда — нет. Серия при этом
      // оборвалась бы, но полосе это безразлично: она показывает факты.
      final week = weekStrip(today: _wed, played: {_mon, _plus(_mon, 1)});

      expect(week[0].state, WeekDayState.played);
      expect(week[1].state, WeekDayState.played);
      expect(week[2].state, WeekDayState.pending);
    });

    test('прошедший день без партии — пропущен', () {
      final week = weekStrip(today: _wed, played: {_mon});

      expect(week[1].state, WeekDayState.missed);
    });

    test('дни после сегодняшнего — будущие', () {
      final week = weekStrip(today: _wed, played: const {});

      expect(week.sublist(3).map((d) => d.state), [
        WeekDayState.future,
        WeekDayState.future,
        WeekDayState.future,
        WeekDayState.future,
      ]);
    });

    test('замороженный день приходит из состояния серии', () {
      final tuesday = _plus(_mon, 1);

      final week = weekStrip(today: _wed, played: {_mon}, frozen: tuesday);

      expect(week[1].state, WeekDayState.frozen);
    });

    test('заморозка прошлой недели полосу не трогает', () {
      final week = weekStrip(
        today: _wed,
        played: const {},
        frozen: StreakDay(2026, 8, 19),
      );

      expect(week.map((d) => d.state), isNot(contains(WeekDayState.frozen)));
    });

    // Журнал ведётся с Этапа 3.2, и дни до него пусты. Полоса от этого не
    // ломается — она просто честно показывает, что записей нет.
    test('пустой журнал — неделя без единой галочки', () {
      final week = weekStrip(today: _wed, played: const {});

      expect(week.map((d) => d.state), isNot(contains(WeekDayState.played)));
    });
  });

  group('Равенство дней', () {
    test('одинаковые дни равны', () {
      final first = weekStrip(today: _wed, played: {_mon});
      final second = weekStrip(today: _wed, played: {_mon});

      expect(first, second);
    });

    test('другой набор сыгранных — другая неделя', () {
      expect(
        weekStrip(today: _wed, played: {_mon}),
        isNot(weekStrip(today: _wed, played: const {})),
      );
    });
  });
}
