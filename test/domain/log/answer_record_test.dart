// Проекция события ответа в строку журнала.
//
// Здесь решается, что из ответа переживёт запись, а что нет. Вопрос не
// косметический: строка журнала — единственное, из чего потом восстанавливают
// историю, и поле, забытое здесь, не восстановится ниоткуда.

import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/observed_session.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/review_items.dart';

ReviewEvent _event({
  int word = 1,
  ReviewGrade grade = ReviewGrade.good,
  bool correct = true,
  Duration responseTime = const Duration(seconds: 2),
  Duration timeLimit = const Duration(seconds: 6),
  int hintsUsed = 0,
  DateTime? at,
  String gameId = 'falling_words',
  String sessionId = 'сессия-1',
}) => ReviewEvent(
  item: wordItem(word),
  outcome: ReviewOutcome(
    correct: correct,
    responseTime: responseTime,
    timeLimit: timeLimit,
    hintsUsed: hintsUsed,
  ),
  grade: grade,
  at: at ?? DateTime.utc(2026, 8, 25, 21, 30),
  gameId: gameId,
  sessionId: sessionId,
);

void main() {
  group('Что переезжает в запись', () {
    test('слово — только id, не сам ReviewItem', () {
      final record = AnswerRecord.of(_event(word: 7));

      expect(record.wordId, wordId(7));
    });

    test('момент — тот же, что в событии', () {
      final at = DateTime.utc(2026, 8, 25, 21, 30, 15, 500);

      expect(AnswerRecord.of(_event(at: at)).at, at);
    });

    test('сырой факт от игры целиком', () {
      final record = AnswerRecord.of(
        _event(
          correct: false,
          responseTime: const Duration(milliseconds: 4321),
          timeLimit: const Duration(seconds: 5),
          hintsUsed: 2,
        ),
      );

      expect(record.correct, isFalse);
      expect(record.responseTime, const Duration(milliseconds: 4321));
      expect(record.timeLimit, const Duration(seconds: 5));
      expect(record.hintsUsed, 2);
    });

    test('кто спрашивал и в какой партии', () {
      final record = AnswerRecord.of(
        _event(gameId: 'ninja_slash', sessionId: 'сессия-42'),
      );

      expect(record.gameId, 'ninja_slash');
      expect(record.sessionId, 'сессия-42');
    });
  });

  group('Оценка', () {
    // Мутация «пересчитать grade из outcome» ловится только так: событие
    // намеренно несёт оценку, которой gradeOutcome не дал бы никогда.
    // Верный ответ never даёт again, а тут именно again — и он обязан
    // доехать до записи нетронутым.
    test('берётся из события, а не пересчитывается из ответа', () {
      final record = AnswerRecord.of(
        _event(correct: true, grade: ReviewGrade.again),
      );

      expect(
        record.grade,
        ReviewGrade.again,
        reason:
            'переигровка обязана прогонять те оценки, которые применялись, '
            'а не те, что дал бы сегодняшний gradeOutcome',
      );
    });
  });

  group('День', () {
    test('это календарный день момента ответа', () {
      final record = AnswerRecord.of(
        _event(at: DateTime.utc(2026, 8, 25, 23, 59, 59)),
      );

      expect(record.localDay, StreakDay(2026, 8, 25));
    });

    test('меняется вместе с моментом, а не берётся из «сегодня»', () {
      final long = AnswerRecord.of(_event(at: DateTime.utc(2019, 2, 28, 12)));

      expect(long.localDay, StreakDay(2019, 2, 28));
    });
  });

  group('Равенство', () {
    test('записи с одинаковыми полями равны', () {
      expect(AnswerRecord.of(_event()), AnswerRecord.of(_event()));
      expect(
        AnswerRecord.of(_event()).hashCode,
        AnswerRecord.of(_event()).hashCode,
      );
    });

    test('разные поля — разные записи', () {
      final base = AnswerRecord.of(_event());

      expect(AnswerRecord.of(_event(word: 2)), isNot(base));
      expect(AnswerRecord.of(_event(grade: ReviewGrade.easy)), isNot(base));
      expect(AnswerRecord.of(_event(correct: false)), isNot(base));
      expect(AnswerRecord.of(_event(hintsUsed: 1)), isNot(base));
      expect(AnswerRecord.of(_event(sessionId: 'другая')), isNot(base));
      expect(
        AnswerRecord.of(_event(at: DateTime.utc(2026, 8, 26))),
        isNot(base),
      );
    });
  });

  group('Сводка за день', () {
    test('равенство по полям', () {
      final day = StreakDay(2026, 8, 25);

      expect(
        DayTally(day: day, answers: 3, correct: 2),
        DayTally(day: StreakDay(2026, 8, 25), answers: 3, correct: 2),
      );
      expect(
        DayTally(day: day, answers: 3, correct: 2).hashCode,
        DayTally(day: StreakDay(2026, 8, 25), answers: 3, correct: 2).hashCode,
      );
    });

    test('другой день или другой счёт — другая сводка', () {
      final base = DayTally(
        day: StreakDay(2026, 8, 25),
        answers: 3,
        correct: 2,
      );

      expect(
        DayTally(day: StreakDay(2026, 8, 26), answers: 3, correct: 2),
        isNot(base),
      );
      expect(
        DayTally(day: StreakDay(2026, 8, 25), answers: 4, correct: 2),
        isNot(base),
      );
      expect(
        DayTally(day: StreakDay(2026, 8, 25), answers: 3, correct: 3),
        isNot(base),
      );
    });
  });
}
