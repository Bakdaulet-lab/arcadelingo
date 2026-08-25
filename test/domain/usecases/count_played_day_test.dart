// Засчитать день: правила серии на настоящем порте, без дерева виджетов.
//
// Пять сценариев приехали сюда из `start_session_test.dart` целиком — там
// они назывались «Серия продвигается по ответу». С Фазы 3 день засчитывает
// **законченная партия**, а не первый ответ, и `StartSession` серию больше не
// двигает вовсе. Сценарии от смены вызывающего не изменились: первый день,
// второй за тот же день, назавтра, пропуск, рекорд.
//
// Плюс то, чего у наблюдателя быть не могло: заморозка и битый документ.

import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/domain/usecases/count_played_day.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_stores.dart';
import '../../support/result.dart';

final DateTime _today = DateTime(2026, 8, 26, 10);

CountPlayedDay _usecase(
  InMemoryStreakStore streaks, {
  DateTime Function()? now,
}) => CountPlayedDay(streaks: streaks, now: now ?? () => _today);

void main() {
  group('Первый день', () {
    test('серия записывается в хранилище', () {
      final streaks = InMemoryStreakStore();

      final state = ok(_usecase(streaks)());

      expect(state.current, 1);
      expect(state.best, 1);
      expect(state.lastDay, StreakDay(2026, 8, 26));
      expect(streaks.saves, hasLength(1));
      expect(streaks.state, state);
    });
  });

  group('Тот же день', () {
    test('вторая партия ничего не пишет', () {
      final streaks = InMemoryStreakStore();
      final usecase = _usecase(streaks);
      final first = ok(usecase());

      final second = ok(usecase());

      expect(second, first);
      expect(
        streaks.saves,
        hasLength(1),
        reason: 'серия меняется раз в день, а не раз в партию',
      );
    });

    test('и на третьей тоже', () {
      final streaks = InMemoryStreakStore();
      final usecase = _usecase(streaks);

      usecase();
      usecase();
      usecase();

      expect(streaks.saves, hasLength(1));
    });
  });

  group('Следующий день', () {
    test('продлевает серию', () {
      var now = _today;
      final streaks = InMemoryStreakStore();
      final usecase = _usecase(streaks, now: () => now);

      usecase();
      now = _today.add(const Duration(days: 1));
      final state = ok(usecase());

      expect(state.current, 2);
      expect(state.best, 2);
      expect(state.lastDay, StreakDay(2026, 8, 27));
      expect(streaks.saves, hasLength(2));
    });
  });

  group('Пропуск', () {
    test('обрывает серию, рекорд остаётся', () {
      var now = _today;
      final streaks = InMemoryStreakStore();
      final usecase = _usecase(streaks, now: () => now);

      for (final shift in [0, 1, 3]) {
        now = _today.add(Duration(days: shift));
        usecase();
      }

      expect(streaks.state.current, 1);
      expect(streaks.state.best, 2);
    });

    // То, чего у наблюдателя по ответу быть не могло: заморозка тратится
    // задним числом, в момент следующей игры.
    test('в один день прощается заморозкой', () {
      var now = _today;
      final streaks = InMemoryStreakStore(
        StreakState(
          current: 3,
          best: 3,
          lastDay: StreakDay(2026, 8, 25),
          freezes: 1,
        ),
      );
      final usecase = _usecase(streaks, now: () => now);

      now = _today.add(const Duration(days: 1)); // 27-е, 26-е пропущено
      final state = ok(usecase());

      expect(state.current, 5, reason: 'три сыгранных, прикрытое 26-е и 27-е');
      expect(state.freezes, 0);
      expect(state.lastFrozenDay, StreakDay(2026, 8, 26));
    });
  });

  group('Битый документ', () {
    test('Err с причиной', () {
      final streaks = FailingStreakStore('серия: last_day не парсится');

      final failure = err(
        CountPlayedDay(streaks: streaks, now: () => _today)(),
      );

      expect(failure.message, contains('last_day'));
    });

    test('молчаливого сброса нет', () {
      final streaks = FailingStreakStore();

      CountPlayedDay(streaks: streaks, now: () => _today)();

      expect(streaks.resets, 0);
    });
  });

  group('Часы', () {
    test('день берётся из now, а не из настоящих часов', () {
      final streaks = InMemoryStreakStore();

      ok(_usecase(streaks, now: () => DateTime(2019, 2, 28, 23))());

      expect(streaks.state.lastDay, StreakDay(2019, 2, 28));
    });

    // Граница дня — местная полночь: правило Фазы 3, и оно проверяется там,
    // где день превращается в запись.
    test('без секунды до полуночи — ещё сегодня', () {
      final streaks = InMemoryStreakStore();

      ok(_usecase(streaks, now: () => DateTime(2026, 8, 26, 23, 59, 59))());

      expect(streaks.state.lastDay, StreakDay(2026, 8, 26));
    });
  });
}
