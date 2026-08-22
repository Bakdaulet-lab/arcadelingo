// Шаг 1 скилла srs-engine: игровой результат → оценка. Обязательные кейсы —
// docs/dev/tasks.md, задача 0.5.1. Пороги 0.30 и 0.60 записаны литералами
// через миллисекунды, а не константами из lib/: тест обязан быть независимой
// сверкой с таблицей скилла. Ссылайся он на ту же константу, что и
// реализация, — он подтвердил бы любую ошибку в ней.
//
// Лимит в тестах 10 с, чтобы граница читалась без дробей: 0.30 → 3000 мс,
// 0.60 → 6000 мс. Формула скилла считает ratio по inMilliseconds, поэтому
// «по обе стороны границы» — это шаг в 1 мс: 2999/3000/3001 и 5999/6000/6001.

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/srs/grade_outcome.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:flutter_test/flutter_test.dart';

/// Лимит, при котором ratio читается по миллисекундам: 0.30 → 3000 мс.
const _limit = Duration(seconds: 10);

/// Ответ за [ms] миллисекунд. По умолчанию верный, без подсказок, из лимита
/// [_limit]: каждый кейс меняет ровно один параметр относительно этой базы.
ReviewOutcome _answer(
  int ms, {
  bool correct = true,
  int hintsUsed = 0,
  Duration timeLimit = _limit,
}) => ReviewOutcome(
  correct: correct,
  responseTime: Duration(milliseconds: ms),
  timeLimit: timeLimit,
  hintsUsed: hintsUsed,
);

void main() {
  group('Оценка ответа: неверный → again', () {
    test('неверный ответ → again, даже мгновенный', () {
      expect(gradeOutcome(_answer(0, correct: false)), ReviewGrade.again);
      expect(
        gradeOutcome(_answer(1, correct: false)),
        ReviewGrade.again,
        reason: 'скорость не спасает неверный ответ',
      );
    });

    test(
      'истёкшее время (correct: false, responseTime == timeLimit) → again',
      () {
        // Таймаут по SPEC.md — это correct: false с responseTime == timeLimit.
        expect(gradeOutcome(_answer(10000, correct: false)), ReviewGrade.again);
      },
    );

    test('неверный с подсказками → again: ниже понижать некуда', () {
      expect(
        gradeOutcome(_answer(500, correct: false, hintsUsed: 2)),
        ReviewGrade.again,
      );
    });

    test('неверный при нулевом лимите → again, а не hard', () {
      // Правило «нулевой лимит → hard» — про верный ответ. Неверный остаётся
      // again: проверка correct стоит раньше любой арифметики.
      expect(
        gradeOutcome(_answer(0, correct: false, timeLimit: Duration.zero)),
        ReviewGrade.again,
      );
    });
  });

  group('Оценка ответа: верный, шкала по скорости', () {
    test('граница 0.30: 2999 мс → easy, 3000 и 3001 мс → good', () {
      expect(
        gradeOutcome(_answer(2999)),
        ReviewGrade.easy,
        reason: 'ratio 0.2999 < 0.30',
      );
      expect(
        gradeOutcome(_answer(3000)),
        ReviewGrade.good,
        reason: 'ratio ровно 0.30: сравнение строгое, граница принадлежит good',
      );
      expect(
        gradeOutcome(_answer(3001)),
        ReviewGrade.good,
        reason: 'ratio 0.3001',
      );
    });

    test('граница 0.60: 5999 мс → good, 6000 и 6001 мс → hard', () {
      expect(
        gradeOutcome(_answer(5999)),
        ReviewGrade.good,
        reason: 'ratio 0.5999 < 0.60',
      );
      expect(
        gradeOutcome(_answer(6000)),
        ReviewGrade.hard,
        reason: 'ratio ровно 0.60: сравнение строгое, граница принадлежит hard',
      );
      expect(
        gradeOutcome(_answer(6001)),
        ReviewGrade.hard,
        reason: 'ratio 0.6001',
      );
    });

    test('мгновенный верный → easy, верный ровно в лимит → hard', () {
      expect(gradeOutcome(_answer(0)), ReviewGrade.easy, reason: 'ratio 0.0');
      expect(
        gradeOutcome(_answer(10000)),
        ReviewGrade.hard,
        reason: 'ratio 1.0 ≥ 0.60',
      );
    });

    test('границы не зависят от лимита: одна доля при 6 с и при 3 с', () {
      // Нормализация по лимиту и есть смысл ratio: игры с разным темпом
      // сравнимы. 6 с и 3 с — диапазон времени падения из SPEC.md.
      const six = Duration(seconds: 6);
      const three = Duration(seconds: 3);

      expect(gradeOutcome(_answer(1799, timeLimit: six)), ReviewGrade.easy);
      expect(
        gradeOutcome(_answer(1800, timeLimit: six)),
        ReviewGrade.good,
        reason: '1800/6000 = 0.30 — та же граница, что 3000/10000',
      );
      expect(
        gradeOutcome(_answer(3600, timeLimit: six)),
        ReviewGrade.hard,
        reason: '3600/6000 = 0.60',
      );

      expect(gradeOutcome(_answer(899, timeLimit: three)), ReviewGrade.easy);
      expect(
        gradeOutcome(_answer(900, timeLimit: three)),
        ReviewGrade.good,
        reason: '900/3000 = 0.30',
      );
      expect(
        gradeOutcome(_answer(1800, timeLimit: three)),
        ReviewGrade.hard,
        reason: '1800/3000 = 0.60: в 6-секундной игре это было бы good',
      );
    });
  });

  group('Оценка ответа: подсказки', () {
    test('hintsUsed > 0 понижает на ступень: easy → good, good → hard', () {
      expect(
        gradeOutcome(_answer(1000, hintsUsed: 1)),
        ReviewGrade.good,
        reason: 'ratio 0.10 без подсказки — easy',
      );
      expect(
        gradeOutcome(_answer(4000, hintsUsed: 1)),
        ReviewGrade.hard,
        reason: 'ratio 0.40 без подсказки — good',
      );
    });

    test('hard с подсказкой остаётся hard: ниже hard не опускает', () {
      expect(
        gradeOutcome(_answer(8000, hintsUsed: 1)),
        ReviewGrade.hard,
        reason: 'ratio 0.80 — hard и так; подсказка не делает из него again',
      );
    });

    test('ступень одна, сколько бы подсказок ни было', () {
      // «hintsUsed > 0» — порог, а не счётчик ступеней: пять подсказок
      // не превращают easy в hard.
      expect(gradeOutcome(_answer(1000, hintsUsed: 5)), ReviewGrade.good);
    });
  });

  group('Оценка ответа: верный никогда не again', () {
    test('самый медленный верный с подсказками → hard, не again', () {
      expect(gradeOutcome(_answer(10000, hintsUsed: 3)), ReviewGrade.hard);
      expect(
        gradeOutcome(_answer(25000, hintsUsed: 3)),
        ReviewGrade.hard,
        reason: 'дольше лимита и с подсказками — всё равно верный',
      );
    });

    test('ни одна комбинация времени, лимита и подсказок не даёт again', () {
      for (final ms in [0, 2999, 3000, 5999, 6000, 10000, 25000]) {
        for (final hints in [0, 1, 5]) {
          for (final limit in [Duration.zero, _limit]) {
            expect(
              gradeOutcome(_answer(ms, hintsUsed: hints, timeLimit: limit)),
              isNot(ReviewGrade.again),
              reason: 'correct: true, $ms мс из $limit, подсказок: $hints',
            );
          }
        }
      }
    });
  });

  group('Оценка ответа: крайние случаи', () {
    test('timeLimit == Duration.zero, верный → hard: делить нельзя', () {
      expect(
        gradeOutcome(_answer(0, timeLimit: Duration.zero)),
        ReviewGrade.hard,
      );
      expect(
        gradeOutcome(_answer(500, timeLimit: Duration.zero)),
        ReviewGrade.hard,
        reason: 'любое время при нулевом лимите — hard',
      );
    });

    test('лимит короче миллисекунды — для формулы в миллисекундах нулевой', () {
      // ratio считается по inMilliseconds: 500 мкс — это 0 мс, делить
      // по-прежнему нельзя. Без этой ветки 0/0 даёт NaN, а не оценку.
      const subMs = Duration(microseconds: 500);
      const outcome = ReviewOutcome(
        correct: true,
        responseTime: Duration(microseconds: 100),
        timeLimit: subMs,
      );

      expect(gradeOutcome(outcome), ReviewGrade.hard);
      expect(responseRatio(outcome), 1.0);
    });

    test('responseTime > timeLimit: ratio зажат в 1.0, не больше', () {
      // Через одну оценку зажим ненаблюдаем: 1.0 и 2.5 оба дают hard.
      // Поэтому правило проверяется по самому ratio.
      expect(
        responseRatio(_answer(25000)),
        1.0,
        reason: '2.5 лимита — всё равно 1.0',
      );
      expect(
        responseRatio(_answer(10001)),
        1.0,
        reason: 'на миллисекунду дольше лимита — тоже 1.0',
      );
      expect(
        gradeOutcome(_answer(25000)),
        ReviewGrade.hard,
        reason: 'и оценка та же, что за ответ ровно в лимит',
      );
    });

    test('ratio внутри лимита — доля лимита, без зажима', () {
      expect(responseRatio(_answer(0)), 0.0, reason: 'мгновенно');
      expect(responseRatio(_answer(2500)), 0.25);
      expect(responseRatio(_answer(10000)), 1.0, reason: 'ровно в лимит');
    });

    test('нулевой лимит: ratio = 1.0 — как будто ушёл весь лимит', () {
      // Именно отсюда hard при нулевом лимите: 1.0 ≥ 0.60.
      expect(responseRatio(_answer(0, timeLimit: Duration.zero)), 1.0);
    });
  });
}
