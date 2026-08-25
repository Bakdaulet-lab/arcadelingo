// Слова напоминания: три варианта и русский счёт дней.
//
// Разница между вариантами — тот самый рычаг, ради которого фаза
// существует, поэтому она проверяется, а не оставляется на глаз.

import 'package:arcadelingo/domain/reminders/reminder_policy.dart';
import 'package:arcadelingo/ui/reminder_labels.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _at = DateTime(2026, 8, 27, 20);

ReminderPlan _plan(ReminderReason reason, {int days = 5}) =>
    ReminderPlan(at: _at, reason: reason, days: days);

void main() {
  group('Три варианта', () {
    test('серия под угрозой — про угрозу и про заморозку', () {
      final (title, body) = reminderText(_plan(ReminderReason.atRisk));

      expect(title, 'Серия: 5 дней под угрозой');
      expect(body, contains('заморозка'));
    });

    test('серия жива — про серию и про одну партию', () {
      final (title, body) = reminderText(_plan(ReminderReason.keepGoing));

      expect(title, 'Серия: 5 дней');
      expect(body, contains('партия'));
    });

    test('серии не будет — зовём вернуться, числа нет', () {
      final (title, body) = reminderText(_plan(ReminderReason.start, days: 0));

      expect(title, 'Пора вернуться');
      expect(title, isNot(contains('0')));
      expect(body, isNotEmpty);
    });
  });

  group('Числа', () {
    test('русский счёт дней в заголовке', () {
      String titleFor(int days) =>
          reminderText(_plan(ReminderReason.keepGoing, days: days)).$1;

      expect(titleFor(1), 'Серия: 1 день');
      expect(titleFor(3), 'Серия: 3 дня');
      expect(titleFor(11), 'Серия: 11 дней');
      expect(titleFor(21), 'Серия: 21 день');
    });

    test('число берётся из плана, а не выдумывается', () {
      expect(
        reminderText(_plan(ReminderReason.atRisk, days: 30)).$1,
        contains('30'),
      );
    });
  });

  group('Все варианты говорят хоть что-то', () {
    test('заголовок и текст непусты у каждой причины', () {
      for (final reason in ReminderReason.values) {
        final (title, body) = reminderText(_plan(reason));
        expect(title.trim(), isNotEmpty, reason: reason.name);
        expect(body.trim(), isNotEmpty, reason: reason.name);
      }
    });

    test('варианты различимы между собой', () {
      final titles = {
        for (final reason in ReminderReason.values)
          reminderText(_plan(reason)).$1,
      };

      expect(
        titles,
        hasLength(ReminderReason.values.length),
        reason: 'три одинаковых текста — это один текст',
      );
    });
  });
}
