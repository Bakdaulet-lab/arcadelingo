// Календарный день и переход серии: чистая арифметика, без часов и хранилища.
//
// Литералы, а не константы из lib/: тест обязан быть независимой сверкой с
// правилом, а не с реализацией.
//
// Границы месяца, года и високосного февраля здесь не «на всякий случай».
// Продление серии — это ровно вопрос «какой день следующий», и наивная
// арифметика ломается именно на них.

import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Календарный день', () {
    test('следующий день внутри месяца', () {
      expect(StreakDay(2026, 8, 25).next, StreakDay(2026, 8, 26));
    });

    test('через границу месяца', () {
      expect(StreakDay(2026, 1, 31).next, StreakDay(2026, 2, 1));
      expect(StreakDay(2026, 4, 30).next, StreakDay(2026, 5, 1));
    });

    test('через границу года', () {
      expect(StreakDay(2026, 12, 31).next, StreakDay(2027, 1, 1));
    });

    test('високосный февраль: 2028 год длиннее', () {
      expect(StreakDay(2028, 2, 28).next, StreakDay(2028, 2, 29));
      expect(StreakDay(2028, 2, 29).next, StreakDay(2028, 3, 1));
    });

    test('невисокосный февраль: 28-е сразу переходит в март', () {
      expect(StreakDay(2027, 2, 28).next, StreakDay(2027, 3, 1));
    });

    test('момент превращается в день своей зоны, без приведения к UTC', () {
      // Полночь по местному времени в зоне +05: в UTC это ещё вчера, и
      // приведение к UTC отняло бы у человека день.
      final localMidnight = DateTime(2026, 8, 25, 0, 30);

      expect(StreakDay.of(localMidnight), StreakDay(2026, 8, 25));
    });

    test('несуществующая дата — ArgumentError', () {
      expect(() => StreakDay(2026, 13, 1), throwsArgumentError);
      expect(() => StreakDay(2026, 2, 31), throwsArgumentError);
      expect(() => StreakDay(2027, 2, 29), throwsArgumentError);
      expect(() => StreakDay(2026, 0, 10), throwsArgumentError);
    });

    test('tryCreate возвращает null вместо броска — это для кодека', () {
      expect(StreakDay.tryCreate(2026, 2, 31), isNull);
      expect(StreakDay.tryCreate(2027, 2, 29), isNull);
      expect(StreakDay.tryCreate(2028, 2, 29), StreakDay(2028, 2, 29));
    });

    test('сравнение и порядок', () {
      expect(StreakDay(2026, 8, 25), StreakDay(2026, 8, 25));
      expect(StreakDay(2026, 8, 25), isNot(StreakDay(2026, 8, 26)));
      expect(
        StreakDay(2026, 8, 25).compareTo(StreakDay(2026, 9, 1)),
        isNegative,
      );
      expect(
        StreakDay(2027, 1, 1).compareTo(StreakDay(2026, 12, 31)),
        isPositive,
      );
      expect(StreakDay(2026, 8, 25).compareTo(StreakDay(2026, 8, 25)), 0);
    });

    test('в строке — дата с ведущими нулями', () {
      expect(StreakDay(2026, 8, 5).toString(), '2026-08-05');
    });
  });

  group('Переход серии', () {
    test('первый день: серия и рекорд равны единице', () {
      final state = advanceStreak(StreakState.empty, StreakDay(2026, 8, 25));

      expect(state.current, 1);
      expect(state.best, 1);
      expect(state.lastDay, StreakDay(2026, 8, 25));
    });

    test('тот же день не меняет ничего — состояние то же самое', () {
      final first = advanceStreak(StreakState.empty, StreakDay(2026, 8, 25));

      final again = advanceStreak(first, StreakDay(2026, 8, 25));

      expect(
        again,
        first,
        reason: 'вторая партия за день — не второй день серии',
      );
    });

    test('следующий день продлевает серию', () {
      var state = advanceStreak(StreakState.empty, StreakDay(2026, 8, 25));
      state = advanceStreak(state, StreakDay(2026, 8, 26));
      state = advanceStreak(state, StreakDay(2026, 8, 27));

      expect(state.current, 3);
      expect(state.best, 3);
      expect(state.lastDay, StreakDay(2026, 8, 27));
    });

    test('пропуск дня обрывает серию, но не рекорд', () {
      var state = advanceStreak(StreakState.empty, StreakDay(2026, 8, 25));
      state = advanceStreak(state, StreakDay(2026, 8, 26));
      state = advanceStreak(state, StreakDay(2026, 8, 27));

      final afterGap = advanceStreak(state, StreakDay(2026, 8, 29));

      expect(afterGap.current, 1);
      expect(
        afterGap.best,
        3,
        reason: 'рекорд держит максимум за всё время — в этом весь смысл поля',
      );
      expect(afterGap.lastDay, StreakDay(2026, 8, 29));
    });

    // Правило изменено Фазой 3, и изменено по записи, оставленной Фазой 2:
    // «мягче с этим случаем должна обходиться Фаза 3 вместе с заморозкой и
    // часовым поясом». Часы, переведённые назад, и перелёт на запад — не
    // пропуск, и наказывать за них обрывом не за что.
    test('день раньше последнего ничего не меняет', () {
      var state = advanceStreak(StreakState.empty, StreakDay(2026, 8, 25));
      state = advanceStreak(state, StreakDay(2026, 8, 26));

      final backwards = advanceStreak(state, StreakDay(2026, 8, 20));

      expect(
        backwards,
        state,
        reason: 'состояние возвращается тем же самым, как и на тот же день',
      );
    });

    test('серия продлевается через границу года', () {
      final last = advanceStreak(StreakState.empty, StreakDay(2026, 12, 31));

      final next = advanceStreak(last, StreakDay(2027, 1, 1));

      expect(next.current, 2);
    });

    test('рекорд обновляется только когда серия его превысила', () {
      var state = advanceStreak(StreakState.empty, StreakDay(2026, 8, 1));
      state = advanceStreak(state, StreakDay(2026, 8, 2));
      state = advanceStreak(state, StreakDay(2026, 8, 3));
      // Разрыв и новая короткая серия.
      state = advanceStreak(state, StreakDay(2026, 8, 10));
      state = advanceStreak(state, StreakDay(2026, 8, 11));

      expect(state.current, 2);
      expect(state.best, 3);
    });
  });

  group('Состояние: инварианты сторожит конструктор', () {
    test('отрицательные счётчики — ArgumentError', () {
      expect(() => StreakState(current: -1, best: 0), throwsArgumentError);
    });

    test('рекорд меньше текущей серии — ArgumentError', () {
      expect(
        () => StreakState(current: 5, best: 2, lastDay: StreakDay(2026, 8, 25)),
        throwsArgumentError,
      );
    });

    test('серия без последнего дня и день без серии — ArgumentError', () {
      expect(() => StreakState(current: 3, best: 3), throwsArgumentError);
      expect(
        () => StreakState(best: 1, lastDay: StreakDay(2026, 8, 25)),
        throwsArgumentError,
      );
    });

    test('пустое состояние — ноль, ноль, ничего', () {
      expect(StreakState.empty.current, 0);
      expect(StreakState.empty.best, 0);
      expect(StreakState.empty.lastDay, isNull);
    });
  });
}
