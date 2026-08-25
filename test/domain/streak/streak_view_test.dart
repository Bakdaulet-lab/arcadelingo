// Серия глазами сегодняшнего дня.
//
// Ради чего функция вообще заведена: `StreakState` знает последний
// **засчитанный** день, а не сегодняшний. Человек, игравший три дня подряд и
// пропустивший позавчера и вчера, до Фазы 3 открывал приложение и видел
// «Серия: 3 дня» — серии уже не было, а состояние об этом не знало и узнать
// не могло: в полночь у нас ничего не выполняется.
//
// Вторая половина — видимость заморозки. Потраченная молча заморозка не
// существует для игрока, поэтому запас выносится наружу явным типом.

import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/domain/streak/streak_view.dart';
import 'package:flutter_test/flutter_test.dart';

final StreakDay _mon = StreakDay(2026, 8, 24);
StreakDay _day(int offset) {
  var day = _mon;
  for (var i = 0; i < offset; i++) {
    day = day.next;
  }
  return day;
}

void main() {
  group('Серии ещё нет', () {
    test('пустое состояние: нечего показывать', () {
      final view = streakAsOf(StreakState.empty, _day(0));

      expect(view.days, 0);
      expect(view.best, 0);
      expect(view.playedToday, isFalse);
      expect(view.alive, isFalse);
      expect(view.freezeWillCover, isFalse);
    });
  });

  group('Сегодня уже сыграно', () {
    test('серия жива и показывается целиком', () {
      final state = StreakState(current: 4, best: 9, lastDay: _day(3));

      final view = streakAsOf(state, _day(3));

      expect(view.days, 4);
      expect(view.best, 9);
      expect(view.playedToday, isTrue);
      expect(view.alive, isTrue);
      expect(view.freezeWillCover, isFalse);
    });

    test('часы, переведённые вперёд у последнего дня, — тоже «сыграно»', () {
      // lastDay оказался «в будущем» относительно today. Играть смысла нет:
      // advanceStreak на таком дне возвращает состояние тем же самым.
      final state = StreakState(current: 4, best: 4, lastDay: _day(5));

      final view = streakAsOf(state, _day(3));

      expect(view.playedToday, isTrue);
      expect(view.alive, isTrue);
      expect(view.days, 4);
    });
  });

  group('Сегодня ещё не сыграно', () {
    test('вчера играл: серия жива, день ждёт', () {
      final state = StreakState(current: 4, best: 4, lastDay: _day(3));

      final view = streakAsOf(state, _day(4));

      expect(
        view.days,
        4,
        reason: 'показываем то, что есть, а не то, что будет',
      );
      expect(view.playedToday, isFalse);
      expect(view.alive, isTrue);
      expect(view.freezeWillCover, isFalse);
    });
  });

  group('Пропущен ровно один день', () {
    test('заморозка есть: серия жива, и сегодняшняя игра её потратит', () {
      final state = StreakState(
        current: 4,
        best: 4,
        lastDay: _day(3),
        freezes: 1,
      );

      final view = streakAsOf(state, _day(5));

      expect(view.alive, isTrue);
      expect(view.days, 4);
      expect(
        view.freezeWillCover,
        isTrue,
        reason:
            'это и есть «под угрозой, но спасём» — и сказать об этом надо '
            'до того, как человек решит играть',
      );
      expect(view.freeze.available, isTrue);
    });

    test('заморозки нет: серия уже оборвана, сегодня начнётся новая', () {
      final state = StreakState(current: 4, best: 4, lastDay: _day(3));

      final view = streakAsOf(state, _day(5));

      expect(view.alive, isFalse);
      expect(view.days, 0, reason: 'показывать четыре дня было бы враньём');
      expect(view.best, 4, reason: 'рекорд обрывом не сбрасывается');
      expect(view.freezeWillCover, isFalse);
    });
  });

  group('Пропущено два дня и больше', () {
    test('заморозка не спасает: серия оборвана', () {
      final state = StreakState(
        current: 6,
        best: 6,
        lastDay: _day(3),
        freezes: 1,
      );

      final view = streakAsOf(state, _day(6));

      expect(view.alive, isFalse);
      expect(view.days, 0);
      expect(view.freezeWillCover, isFalse);
      expect(
        view.freeze.available,
        isTrue,
        reason: 'её не потратили — на два дня она и не рассчитана',
      );
    });
  });

  group('Состояние запаса видно снаружи', () {
    test('заморозка есть', () {
      final state = StreakState(
        current: 2,
        best: 2,
        lastDay: _day(1),
        freezes: 1,
      );

      final freeze = streakAsOf(state, _day(1)).freeze;

      expect(freeze.available, isTrue);
      expect(freeze.daysToNext, 0);
      expect(freeze.spentOn, isNull);
    });

    test('заморозка потрачена вчера — и видно, на какой день', () {
      // Пн–Ср сыграны, Чт прикрыт заморозкой, Пт сыгран, сегодня Пт.
      final state = StreakState(
        current: 5,
        best: 5,
        lastDay: _day(4),
        daysSinceFreeze: 1,
        lastFrozenDay: _day(3),
      );

      final view = streakAsOf(state, _day(4));

      expect(view.days, 5);
      expect(view.freeze.available, isFalse);
      expect(view.freeze.spentOn, _day(3));
      expect(
        view.freeze.daysToNext,
        daysToEarnFreeze - 1,
        reason: 'один засчитанный день после траты уже позади',
      );
    });

    test('заморозки нет: сколько засчитанных дней до следующей', () {
      final state = StreakState(
        current: 3,
        best: 3,
        lastDay: _day(2),
        daysSinceFreeze: 3,
      );

      final freeze = streakAsOf(state, _day(2)).freeze;

      expect(freeze.available, isFalse);
      expect(freeze.daysToNext, daysToEarnFreeze - 3);
    });

    test('оборванная серия замороженным днём больше не хвастается', () {
      final state = StreakState(
        current: 5,
        best: 5,
        lastDay: _day(4),
        daysSinceFreeze: 1,
        lastFrozenDay: _day(3),
      );

      final view = streakAsOf(state, _day(9));

      expect(view.alive, isFalse);
      expect(
        view.freeze.spentOn,
        isNull,
        reason: 'серии, которую она спасала, больше нет',
      );
    });
  });

  group('Граница дня — местная полночь', () {
    // Правило, а не побочный эффект: `StreakDay.of` берёт поля момента как
    // есть, без приведения к UTC. Сессия в 23:59 и сессия в 00:00 — разные
    // дни, и это ровно то, что человек видит в календаре телефона.
    test('последняя секунда суток ещё сегодня', () {
      final late = DateTime(2026, 8, 24, 23, 59, 59, 999);

      expect(StreakDay.of(late), StreakDay(2026, 8, 24));
    });

    test('первая секунда суток — уже завтра', () {
      final justAfter = DateTime(2026, 8, 25);

      expect(StreakDay.of(justAfter), StreakDay(2026, 8, 25));
    });

    test('серия, продлённая в 23:59 и в 00:01, — два разных дня', () {
      var state = advanceStreak(
        StreakState.empty,
        StreakDay.of(DateTime(2026, 8, 24, 23, 59)),
      );
      state = advanceStreak(state, StreakDay.of(DateTime(2026, 8, 25, 0, 1)));

      expect(state.current, 2);
    });
  });
}
