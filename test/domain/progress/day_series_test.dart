// Достройка пустых дней: хранилище их не возвращает, рисующий обязан достроить.
//
// Проверяется ровно то, что легко сломать незаметно: длина ряда, календарный
// порядок и то, что дырки становятся нулями, а не пропадают.

import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/progress/day_series.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:flutter_test/flutter_test.dart';

final StreakDay _from = StreakDay(2026, 8, 24);
final StreakDay _to = StreakDay(2026, 8, 30);

DayTally _tally(int day, {int answers = 3, int correct = 2}) =>
    DayTally(day: StreakDay(2026, 8, day), answers: answers, correct: correct);

void main() {
  group('Длина и порядок', () {
    test('ровно столько дней, сколько в отрезке', () {
      expect(fillDays(tallies: const [], from: _from, to: _to), hasLength(7));
    });

    test('один день — один элемент', () {
      expect(fillDays(tallies: const [], from: _from, to: _from), hasLength(1));
    });

    test('календарный порядок, а не порядок сводок', () {
      final filled = fillDays(
        tallies: [_tally(30), _tally(24), _tally(27)],
        from: _from,
        to: _to,
      );

      expect(filled.map((d) => d.day.day), [24, 25, 26, 27, 28, 29, 30]);
    });

    test('отрезок через границу месяца', () {
      final filled = fillDays(
        tallies: const [],
        from: StreakDay(2026, 8, 30),
        to: StreakDay(2026, 9, 2),
      );

      expect(filled.map((d) => d.day.toString()), [
        '2026-08-30',
        '2026-08-31',
        '2026-09-01',
        '2026-09-02',
      ]);
    });

    test('перевёрнутый отрезок — ArgumentError', () {
      expect(
        () => fillDays(tallies: const [], from: _to, to: _from),
        throwsArgumentError,
      );
    });
  });

  group('Дырки', () {
    test('день без сводки приходит нулями', () {
      final filled = fillDays(tallies: [_tally(24)], from: _from, to: _to);

      expect(filled.first.answers, 3);
      expect(filled[1].answers, 0);
      expect(filled[1].correct, 0);
      expect(filled[1].day, StreakDay(2026, 8, 25));
    });

    test('пустые сводки — весь ряд нулями', () {
      final filled = fillDays(tallies: const [], from: _from, to: _to);

      expect(filled.map((d) => d.answers), everyElement(0));
    });

    test('сводки доезжают целиком, а не только числом ответов', () {
      final filled = fillDays(
        tallies: [_tally(26, answers: 9, correct: 7)],
        from: _from,
        to: _to,
      );

      final day = filled.firstWhere((d) => d.day == StreakDay(2026, 8, 26));
      expect(day.answers, 9);
      expect(day.correct, 7);
    });

    // Сводка за день вне отрезка в ряд не попадает: отрезок задаёт тот, кто
    // рисует, и лишний столбик сломал бы полосу молча.
    test('сводка вне отрезка игнорируется', () {
      final filled = fillDays(
        tallies: [_tally(20, answers: 99)],
        from: _from,
        to: _to,
      );

      expect(filled, hasLength(7));
      expect(filled.map((d) => d.answers), everyElement(isNot(99)));
    });
  });
}
