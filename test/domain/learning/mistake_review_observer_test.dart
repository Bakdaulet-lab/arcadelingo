import 'package:arcadelingo/domain/learning/mistake_review_observer.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/observed_session.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_review_session.dart';
import '../../support/review_items.dart';

const _correct = ReviewOutcome(
  correct: true,
  responseTime: Duration(seconds: 1),
  timeLimit: Duration(seconds: 6),
);
const _wrong = ReviewOutcome(
  correct: false,
  responseTime: Duration(seconds: 2),
  timeLimit: Duration(seconds: 6),
);
const _timeout = ReviewOutcome(
  correct: false,
  responseTime: Duration(seconds: 6),
  timeLimit: Duration(seconds: 6),
);

final _now = DateTime.utc(2026, 11, 17, 12);

ObservedSession _observed(
  FakeReviewSession inner,
  MistakeReviewObserver observer,
) => ObservedSession(
  inner: inner,
  observers: [observer],
  now: () => _now,
  gameId: 'falling_words',
  sessionId: 'learning-test',
);

void main() {
  test(
    'создание и чтение списка ошибок не потребляют слова и не пишут ответы',
    () {
      final inner = FakeReviewSession(wordItems(3));
      final observer = MistakeReviewObserver(level: CefrLevel.a1);
      final session = _observed(inner, observer);

      expect(session.answered, 0);
      expect(session.total, 3);
      expect(session.isFinished, isFalse);
      expect(observer.mistakes, isEmpty);
      expect(inner.nextItemCalls, 0);
      expect(inner.reports, isEmpty);
    },
  );

  test('ошибка записывается после единственного исходного ответа сессии', () {
    final item = wordItem(1);
    final inner = FakeReviewSession([item]);
    final observer = MistakeReviewObserver(level: CefrLevel.a1);
    final session = _observed(inner, observer);

    expect(session.nextItem(), same(item));
    expect(observer.mistakes, isEmpty);
    session.report(_wrong);

    expect(inner.nextItemCalls, 1);
    expect(inner.reports, hasLength(1));
    expect(inner.reports.single.outcome, same(_wrong));
    expect(observer.mistakes.single, same(item.word));
    expect(session.answered, 1);
    expect(session.total, 1);
    expect(session.isFinished, isTrue);
  });

  test('правильный ответ не создаёт ошибку, таймаут создаёт', () {
    final inner = FakeReviewSession(wordItems(2));
    final observer = MistakeReviewObserver(level: CefrLevel.a1);
    final session = _observed(inner, observer);

    session.nextItem();
    session.report(_correct);
    expect(observer.mistakes, isEmpty);
    session.nextItem();
    session.report(_timeout);

    expect(observer.mistakes.map((word) => word.id), [wordId(2)]);
    expect(session.answered, 2);
  });

  test('повторные ошибки сгруппированы по слову, порядок — первый промах', () {
    final one = wordItem(1);
    final two = wordItem(2);
    final observer = MistakeReviewObserver(level: CefrLevel.a1);
    final session = _observed(
      FakeReviewSession([two, one, two, one]),
      observer,
    );
    for (var index = 0; index < 4; index++) {
      session.nextItem();
      session.report(index == 3 ? _correct : _wrong);
    }

    expect(observer.mistakes.map((word) => word.id), [wordId(2), wordId(1)]);
    expect(session.answered, 4);
  });

  for (final level in CefrLevel.values) {
    test('${level.name}: события других уровней не попадают в разбор', () {
      final observer = MistakeReviewObserver(level: level);
      for (final itemLevel in CefrLevel.values) {
        observer.onAnswer(
          ReviewEvent(
            item: ReviewItem(
              word: Word(
                id: itemLevel.name,
                text: '${itemLevel.name}-word',
                translation: '${itemLevel.name}-перевод',
                level: itemLevel,
              ),
            ),
            outcome: _wrong,
            grade: ReviewGrade.again,
            at: _now,
            gameId: 'ninja_slash',
            sessionId: 'selected-level',
          ),
        );
      }

      expect(observer.mistakes.map((word) => word.id), [level.name]);
      expect(observer.mistakes.single.level, level);
    });
  }

  test('список ошибок нельзя менять, старый снимок не дополняется позднее', () {
    final observer = MistakeReviewObserver(level: CefrLevel.a1);
    final session = _observed(FakeReviewSession(wordItems(2)), observer);
    session.nextItem();
    session.report(_wrong);
    final firstSnapshot = observer.mistakes;
    expect(() => firstSnapshot.clear(), throwsUnsupportedError);

    session.nextItem();
    session.report(_timeout);
    expect(firstSnapshot.map((word) => word.id), [wordId(1)]);
    expect(observer.mistakes.map((word) => word.id), [wordId(1), wordId(2)]);
  });

  test('выданное без ответа слово не записывается ошибкой', () {
    final inner = FakeReviewSession(wordItems(1));
    final observer = MistakeReviewObserver(level: CefrLevel.a1);
    final session = _observed(inner, observer);
    session.nextItem();

    expect(observer.mistakes, isEmpty);
    expect(inner.reports, isEmpty);
    expect(session.answered, 0);
    expect(session.isFinished, isFalse);
  });

  test('пустая сессия не создаёт ошибку', () {
    final inner = FakeReviewSession([]);
    final observer = MistakeReviewObserver(level: CefrLevel.a1);
    final session = _observed(inner, observer);

    expect(session.isFinished, isTrue);
    expect(session.total, 0);
    expect(session.answered, 0);
    expect(session.nextItem(), isNull);
    expect(observer.mistakes, isEmpty);
    expect(inner.reports, isEmpty);
  });

  test('нарушения протокола не добавляют ошибки и не дублируют ответы', () {
    final inner = FakeReviewSession(wordItems(1));
    final observer = MistakeReviewObserver(level: CefrLevel.a1);
    final session = _observed(inner, observer);

    expect(() => session.report(_wrong), throwsStateError);
    expect(observer.mistakes, isEmpty);
    session.nextItem();
    expect(session.nextItem, throwsStateError);
    session.report(_wrong);
    expect(() => session.report(_wrong), throwsStateError);

    expect(inner.reports, hasLength(1));
    expect(observer.mistakes.map((word) => word.id), [wordId(1)]);
  });
}
