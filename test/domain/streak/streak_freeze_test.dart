// Заморозка серии: правила Фазы 3 поверх формы Фазы 2.
//
// Отдельным файлом от `streak_test.dart` намеренно. Там лежит арифметика
// календаря и три случая перехода, написанные до того, как заморозка
// существовала; смешивать их значило бы перечитывать оба файла каждый раз,
// когда меняется одно из двух.
//
// Все ожидания посчитаны по правилу, а не вызовом кода: заморозка прощает
// ровно один пропущенный день, **сам пропущенный день идёт в счёт серии**
// (Пн–Ср + пропуск + Пт–Вс = 7, не 3), два пропуска подряд не прощаются,
// новая заморозка зарабатывается за семь засчитанных дней.

import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:flutter_test/flutter_test.dart';

/// Понедельник, чтобы недельные сценарии читались как календарь.
final StreakDay _mon = StreakDay(2026, 8, 24);
StreakDay _day(int offset) {
  var day = _mon;
  for (var i = 0; i < offset; i++) {
    day = day.next;
  }
  return day;
}

/// Состояние с заморозкой в запасе на конец [offset]-го дня.
StreakState _withFreeze({required int current, required int offset}) =>
    StreakState(
      current: current,
      best: current,
      lastDay: _day(offset),
      freezes: 1,
    );

void main() {
  group('Новый игрок', () {
    test('заморозки нет: она зарабатывается, а не выдаётся', () {
      expect(StreakState.empty.freezes, 0);
      expect(StreakState.empty.daysSinceFreeze, 0);
      expect(StreakState.empty.lastFrozenDay, isNull);
    });

    test('первый же засчитанный день приближает заморозку', () {
      final state = advanceStreak(StreakState.empty, _day(0));

      expect(state.daysSinceFreeze, 1);
      expect(state.freezes, 0);
    });

    test('семь засчитанных дней подряд дают заморозку', () {
      var state = StreakState.empty;
      for (var i = 0; i < daysToEarnFreeze; i++) {
        state = advanceStreak(state, _day(i));
      }

      expect(state.current, 7);
      expect(state.freezes, 1);
      expect(
        state.daysSinceFreeze,
        0,
        reason: 'заморозка есть — копить больше нечего',
      );
    });

    test('шести дней не хватает', () {
      var state = StreakState.empty;
      for (var i = 0; i < daysToEarnFreeze - 1; i++) {
        state = advanceStreak(state, _day(i));
      }

      expect(state.freezes, 0);
      expect(state.daysSinceFreeze, 6);
    });

    test('обрыв серии счётчик к заморозке не обнуляет', () {
      var state = StreakState.empty;
      state = advanceStreak(state, _day(0));
      state = advanceStreak(state, _day(1));
      state = advanceStreak(state, _day(2));
      // Пропуск в три дня — заморозке такое не по силам, серия с единицы.
      state = advanceStreak(state, _day(6));

      expect(state.current, 1);
      expect(
        state.daysSinceFreeze,
        4,
        reason:
            'эти дни человек отыграл; отнимать их за пропуск — наказать '
            'дважды',
      );
    });
  });

  group('Трата заморозки', () {
    test('пропуск ровно одного дня прощается, и сам день идёт в счёт', () {
      // Пн, Вт, Ср сыграны (серия 3, заморозка в запасе), Чт пропущен,
      // Пт сыгран.
      final before = _withFreeze(current: 3, offset: 2);

      final after = advanceStreak(before, _day(4));

      expect(
        after.current,
        5,
        reason: 'три сыгранных, замороженный четверг и пятница',
      );
      expect(after.freezes, 0);
      expect(after.lastFrozenDay, _day(3), reason: 'прикрыт четверг');
      expect(after.lastDay, _day(4));
    });

    test('неделя из примера автора даёт семь, а не три', () {
      var state = StreakState(freezes: StreakState.maxFreezes);
      state = advanceStreak(state, _day(0)); // Пн
      state = advanceStreak(state, _day(1)); // Вт
      state = advanceStreak(state, _day(2)); // Ср
      // Чт пропущен.
      state = advanceStreak(state, _day(4)); // Пт
      state = advanceStreak(state, _day(5)); // Сб
      state = advanceStreak(state, _day(6)); // Вс

      expect(state.current, 7);
      expect(state.best, 7);
      expect(state.lastFrozenDay, _day(3));
    });

    test('после траты счётчик считает заново, начиная с сегодняшнего дня', () {
      final after = advanceStreak(_withFreeze(current: 3, offset: 2), _day(4));

      expect(
        after.daysSinceFreeze,
        1,
        reason: 'сегодняшний сыгранный день уже в счёт следующей заморозки',
      );
    });

    test(
      'вторая заморозка приходит через семь засчитанных дней после траты',
      () {
        var state = advanceStreak(_withFreeze(current: 3, offset: 2), _day(4));
        // Один день уже засчитан тратой; добираем ещё шесть.
        for (var i = 5; i < 11; i++) {
          state = advanceStreak(state, _day(i));
        }

        expect(state.freezes, 1);
        expect(state.daysSinceFreeze, 0);
      },
    );
  });

  group('Чего заморозка не прощает', () {
    test('два пропущенных дня подряд — серия с единицы', () {
      final before = _withFreeze(current: 5, offset: 4);

      final after = advanceStreak(before, _day(7));

      expect(after.current, 1);
      expect(
        after.freezes,
        1,
        reason: 'на два дня её не хватило — значит и не потрачена',
      );
      expect(after.lastFrozenDay, isNull);
    });

    test('пропуск без заморозки в запасе — серия с единицы', () {
      final before = StreakState(current: 3, best: 3, lastDay: _day(2));

      final after = advanceStreak(before, _day(4));

      expect(after.current, 1);
      expect(after.best, 3);
    });

    test('обрыв стирает замороженный день: у новой серии их нет', () {
      final frozen = advanceStreak(_withFreeze(current: 3, offset: 2), _day(4));
      expect(frozen.lastFrozenDay, isNotNull);

      final broken = advanceStreak(frozen, _day(10));

      expect(broken.current, 1);
      expect(broken.lastFrozenDay, isNull);
    });
  });

  group('День раньше последнего — не разрыв (правило Фазы 3)', () {
    test('перевод часов назад ничего не меняет', () {
      final state = StreakState(current: 4, best: 6, lastDay: _day(5));

      final backwards = advanceStreak(state, _day(1));

      expect(
        backwards,
        state,
        reason:
            'часы, переведённые назад, и перелёт на запад — не пропуск; '
            'Фаза 2 обрывала серию и оставила смягчение Фазе 3',
      );
    });

    test('заморозка при этом не тратится', () {
      final state = _withFreeze(current: 4, offset: 5);

      expect(advanceStreak(state, _day(1)).freezes, 1);
    });
  });

  group('Инварианты запаса', () {
    test('заморозок больше максимума — ArgumentError', () {
      expect(
        () => StreakState(
          current: 1,
          best: 1,
          lastDay: _day(0),
          freezes: StreakState.maxFreezes + 1,
        ),
        throwsArgumentError,
      );
    });

    test('заморозка в запасе и ненулевой счётчик — ArgumentError', () {
      expect(
        () => StreakState(
          current: 1,
          best: 1,
          lastDay: _day(0),
          freezes: 1,
          daysSinceFreeze: 3,
        ),
        throwsArgumentError,
      );
    });

    test(
      'замороженный день не раньше последнего сыгранного — ArgumentError',
      () {
        expect(
          () => StreakState(
            current: 2,
            best: 2,
            lastDay: _day(1),
            lastFrozenDay: _day(1),
          ),
          throwsArgumentError,
        );
        expect(
          () => StreakState(lastFrozenDay: _day(0)),
          throwsArgumentError,
          reason: 'заморозить день, не сыграв ни одного, нельзя',
        );
      },
    );
  });
}
