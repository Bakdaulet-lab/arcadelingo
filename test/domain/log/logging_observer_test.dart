// Наблюдатель журнала: единственная его работа — превратить событие в строку
// и не ждать записи.
//
// «Не ждать» — не мелочь и не оптимизация. `onAnswer` синхронен, ждать его
// некому, и наблюдатель, который всё-таки дождался бы записи, остановил бы
// падающее слово на время обращения к диску.

import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/log/logging_observer.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/observed_session.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_review_session.dart';
import '../../support/in_memory_answer_log.dart';
import '../../support/review_items.dart';

final DateTime _t0 = DateTime.utc(2026, 8, 25, 10);

ReviewEvent _event({int word = 1, ReviewGrade grade = ReviewGrade.good}) =>
    ReviewEvent(
      item: wordItem(word),
      outcome: const ReviewOutcome(
        correct: true,
        responseTime: Duration(seconds: 2),
        timeLimit: Duration(seconds: 6),
      ),
      grade: grade,
      at: _t0,
      gameId: 'falling_words',
      sessionId: 'сессия-1',
    );

void main() {
  test('один ответ — одна строка', () {
    final log = InMemoryAnswerLog();

    LoggingObserver(log: log).onAnswer(_event());

    expect(log.records, hasLength(1));
  });

  test('строка — проекция события, а не что-то своё', () {
    final log = InMemoryAnswerLog();
    final event = _event(word: 3, grade: ReviewGrade.easy);

    LoggingObserver(log: log).onAnswer(event);

    expect(log.records.single, AnswerRecord.of(event));
  });

  test('каждый ответ дописывается, прошлые остаются', () {
    final log = InMemoryAnswerLog();
    final observer = LoggingObserver(log: log);

    observer.onAnswer(_event(word: 1));
    observer.onAnswer(_event(word: 2));
    observer.onAnswer(_event(word: 1));

    expect(log.records.map((r) => r.wordId), [wordId(1), wordId(2), wordId(1)]);
  });

  test('внутри настоящей сессии пишет ровно один раз на ответ', () {
    final log = InMemoryAnswerLog();
    final session = ObservedSession(
      inner: FakeReviewSession(wordItems(2)),
      observers: [LoggingObserver(log: log)],
      now: () => _t0,
      gameId: 'falling_words',
      sessionId: 'сессия-1',
    );

    session.nextItem();
    session.report(
      const ReviewOutcome(
        correct: true,
        responseTime: Duration(seconds: 1),
        timeLimit: Duration(seconds: 6),
      ),
    );

    expect(log.records, hasLength(1));
    expect(log.records.single.wordId, wordId(1));
    expect(log.records.single.gameId, 'falling_words');
    expect(log.records.single.sessionId, 'сессия-1');
  });

  test('доклад без выданного слова строки не оставляет', () {
    final log = InMemoryAnswerLog();
    final session = ObservedSession(
      inner: FakeReviewSession(wordItems(2)),
      observers: [LoggingObserver(log: log)],
      now: () => _t0,
      gameId: 'falling_words',
      sessionId: 'сессия-1',
    );

    expect(
      () => session.report(
        const ReviewOutcome(
          correct: true,
          responseTime: Duration(seconds: 1),
          timeLimit: Duration(seconds: 6),
        ),
      ),
      throwsStateError,
    );
    expect(log.records, isEmpty, reason: 'ответа не было — писать нечего');
  });
}
