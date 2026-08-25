// Политика напоминания: когда ставить и что говорить.
//
// Всё, что решает эта фаза про уведомления, живёт здесь, и проверяется
// таблицей: плагин у нас тонкий адаптер, а «в какой момент и какими
// словами» — чистая функция.
//
// Главное, что тут сторожится: текст считается на **тот день, в который
// напоминание сработает**. Поставленное вечером на завтра, оно сработает в
// мире, где серия на день старше, и текст, посчитанный сегодня, сказал бы
// про сегодняшнее состояние.

import 'package:arcadelingo/domain/reminders/reminder_policy.dart';
import 'package:arcadelingo/domain/reminders/reminder_settings.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:flutter_test/flutter_test.dart';

/// Среда, 26 августа 2026.
final DateTime _wed = DateTime(2026, 8, 26);

DateTime _at(int hour, [int minute = 0]) => DateTime(2026, 8, 26, hour, minute);

const ReminderSettings _on = ReminderSettings(
  enabled: true,
  at: ReminderTime(20, 0),
);

/// Серия из [days] дней, последний засчитанный — [lastOffset] суток назад.
StreakState _streak({
  int days = 0,
  int lastOffset = 0,
  int freezes = 0,
  int daysSinceFreeze = 0,
}) {
  var last = StreakDay.of(_wed);
  for (var i = 0; i < lastOffset; i++) {
    last = last.previous;
  }
  return StreakState(
    current: days,
    best: days,
    lastDay: days == 0 ? null : last,
    freezes: freezes,
    daysSinceFreeze: daysSinceFreeze,
  );
}

void main() {
  group('Ставить или не ставить', () {
    test('напоминания выключены — не ставим ничего', () {
      expect(
        planReminder(
          settings: ReminderSettings.defaults,
          streak: _streak(days: 3, lastOffset: 1),
          now: _at(10),
        ),
        isNull,
      );
    });

    test('сегодня не сыграно и время не прошло — сегодня', () {
      final plan = planReminder(
        settings: _on,
        streak: _streak(days: 3, lastOffset: 1),
        now: _at(10),
      );

      expect(plan!.at, DateTime(2026, 8, 26, 20));
    });

    test('сегодня уже сыграно — завтра', () {
      final plan = planReminder(
        settings: _on,
        streak: _streak(days: 3),
        now: _at(10),
      );

      expect(plan!.at, DateTime(2026, 8, 27, 20));
    });

    test('время сегодня прошло — завтра', () {
      final plan = planReminder(
        settings: _on,
        streak: _streak(days: 3, lastOffset: 1),
        now: _at(21),
      );

      expect(plan!.at, DateTime(2026, 8, 27, 20));
    });

    // Уведомление о приложении, которое человек держит открытым, — не
    // напоминание. Ровно в назначенный момент оно уходит на завтра.
    test('ровно в назначенный момент — завтра', () {
      final plan = planReminder(
        settings: _on,
        streak: _streak(days: 3, lastOffset: 1),
        now: _at(20),
      );

      expect(plan!.at, DateTime(2026, 8, 27, 20));
    });

    test('за минуту до — ещё сегодня', () {
      final plan = planReminder(
        settings: _on,
        streak: _streak(days: 3, lastOffset: 1),
        now: _at(19, 59),
      );

      expect(plan!.at, DateTime(2026, 8, 26, 20));
    });

    test('серии нет вовсе — напоминание всё равно ставится', () {
      final plan = planReminder(settings: _on, streak: _streak(), now: _at(10));

      expect(plan, isNotNull);
      expect(plan!.at, DateTime(2026, 8, 26, 20));
    });

    test('час берётся из настроек, а не из головы', () {
      final plan = planReminder(
        settings: const ReminderSettings(
          enabled: true,
          at: ReminderTime(7, 45),
        ),
        streak: _streak(days: 1, lastOffset: 1),
        now: _at(6),
      );

      expect(plan!.at, DateTime(2026, 8, 26, 7, 45));
    });

    test('перенос на завтра переживает границу месяца', () {
      final plan = planReminder(
        settings: _on,
        streak: StreakState(
          current: 1,
          best: 1,
          lastDay: StreakDay(2026, 8, 31),
        ),
        now: DateTime(2026, 8, 31, 22),
      );

      expect(plan!.at, DateTime(2026, 9, 1, 20));
    });
  });

  group('Текст считается на день срабатывания', () {
    // Сегодня сыграно, напоминание уходит на завтра. Завтра серия будет
    // живой и несыгранной — текст обязан звать продолжить, а не
    // поздравлять с сегодняшним днём.
    test('сыграл сегодня — завтрашнее напоминание зовёт продолжить', () {
      final plan = planReminder(
        settings: _on,
        streak: _streak(days: 5),
        now: _at(10),
      );

      expect(plan!.title, contains('5'));
      expect(plan.body, isNot(contains('под угрозой')));
    });

    // Вчера не играл, сегодня время уже прошло: завтра пропущенным окажется
    // сегодняшний день, и заморозка его прикроет.
    test('пропуск и заморозка — завтрашнее напоминание про угрозу', () {
      final plan = planReminder(
        settings: _on,
        streak: _streak(days: 5, lastOffset: 1, freezes: 1),
        now: _at(23),
      );

      expect(plan!.at, DateTime(2026, 8, 27, 20));
      expect(plan.title, contains('под угрозой'));
    });

    test('серия оборвётся, спасать нечем — зовём начать заново', () {
      final plan = planReminder(
        settings: _on,
        streak: _streak(days: 5, lastOffset: 1),
        now: _at(23),
      );

      expect(
        plan!.title,
        isNot(contains('5')),
        reason: 'к завтрашнему дню этой серии уже не будет',
      );
    });

    test('серии нет — зовём начать', () {
      final plan = planReminder(settings: _on, streak: _streak(), now: _at(10));

      expect(plan!.title, isNotEmpty);
      expect(plan.body, isNotEmpty);
      expect(plan.title, isNot(contains('0')));
    });
  });

  group('Слова', () {
    test('заголовок и текст непусты во всех состояниях', () {
      final states = [
        _streak(),
        _streak(days: 1),
        _streak(days: 5, lastOffset: 1),
        _streak(days: 5, lastOffset: 2, freezes: 1),
        _streak(days: 30, lastOffset: 1),
      ];

      for (final state in states) {
        final plan = planReminder(settings: _on, streak: state, now: _at(10));
        expect(plan!.title.trim(), isNotEmpty, reason: '$state');
        expect(plan.body.trim(), isNotEmpty, reason: '$state');
      }
    });

    test('русский счёт дней в заголовке', () {
      String titleFor(int days) =>
          planReminder(
            settings: _on,
            streak: _streak(days: days, lastOffset: 1),
            now: _at(10),
          )!.title;

      expect(titleFor(1), contains('1 день'));
      expect(titleFor(3), contains('3 дня'));
      expect(titleFor(11), contains('11 дней'));
    });
  });
}
