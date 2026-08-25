// Шов «ответ произошёл»: декоратор поверх ReviewSession.
//
// Главное свойство, ради которого декоратор и заведён: он ничего не меняет
// для того, кто держит сессию в руках. Игра видит ReviewSession и не знает,
// обёрнута она или нет. Отсюда две половины тестов — «делегирует всё» и
// «сверх делегирования зовёт наблюдателей».
//
// Внутренняя сессия здесь — FakeReviewSession из тестов игры: она такая же
// строгая, как настоящая, и бросает на нарушении протокола. Декоратор обязан
// эту строгость сохранить, а не смягчить.

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/observed_session.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_review_session.dart';
import '../../support/review_items.dart';

/// Наблюдатель-журнал: всё, что ему сказали, по порядку.
class _SpyObserver implements ReviewObserver {
  final List<ReviewEvent> events = [];

  @override
  void onAnswer(ReviewEvent event) => events.add(event);
}

/// Наблюдатель, который падает. Проверяет, что декоратор не глушит.
class _AngryObserver implements ReviewObserver {
  @override
  void onAnswer(ReviewEvent event) => throw StateError('наблюдатель упал');
}

final DateTime _t0 = DateTime(2026, 8, 25, 10);

ObservedSession _observed(
  ReviewSession inner, {
  List<ReviewObserver> observers = const [],
  DateTime? at,
}) => ObservedSession(
  inner: inner,
  observers: observers,
  now: () => at ?? _t0,
  gameId: 'falling_words',
  sessionId: 'сессия-1',
);

ReviewOutcome _outcome({bool correct = true, int seconds = 1}) => ReviewOutcome(
  correct: correct,
  responseTime: Duration(seconds: seconds),
  timeLimit: const Duration(seconds: 6),
);

void main() {
  group('Делегирует всё, что обещает контракт', () {
    test('nextItem отдаёт слово внутренней сессии', () {
      final inner = FakeReviewSession(wordItems(2));
      final session = _observed(inner);

      expect(session.nextItem()!.word.id, 'w01');
      expect(inner.nextItemCalls, 1);
    });

    test('report доходит до внутренней сессии', () {
      final inner = FakeReviewSession(wordItems(2));
      final session = _observed(inner);
      session.nextItem();

      session.report(_outcome());

      expect(inner.reports, hasLength(1));
      expect(inner.reports.single.outcome.correct, isTrue);
    });

    test('счётчики и признак конца берутся у внутренней сессии', () {
      final inner = FakeReviewSession(wordItems(2), total: 15);
      final session = _observed(inner);

      expect(session.total, 15);
      expect(session.answered, 0);
      expect(session.isFinished, isFalse);

      session.nextItem();
      session.report(_outcome());

      expect(session.answered, 1);
    });

    test('пустая сессия: null и сразу конец', () {
      final session = _observed(FakeReviewSession(const []));

      expect(session.nextItem(), isNull);
      expect(session.isFinished, isTrue);
    });
  });

  group('Строгость протокола не смягчается', () {
    test(
      'report() без выданного слова — StateError, наблюдателей не зовут',
      () {
        final spy = _SpyObserver();
        final session = _observed(
          FakeReviewSession(wordItems(2)),
          observers: [spy],
        );

        expect(() => session.report(_outcome()), throwsStateError);
        expect(
          spy.events,
          isEmpty,
          reason: 'ответа не было — событию неоткуда взяться',
        );
      },
    );

    test('nextItem() до report() — StateError пробрасывается', () {
      final session = _observed(FakeReviewSession(wordItems(2)));
      session.nextItem();

      expect(session.nextItem, throwsStateError);
    });
  });

  group('Событие', () {
    test('один ответ — ровно одно событие каждому наблюдателю', () {
      final first = _SpyObserver();
      final second = _SpyObserver();
      final session = _observed(
        FakeReviewSession(wordItems(2)),
        observers: [first, second],
      );

      session.nextItem();
      session.report(_outcome());

      expect(first.events, hasLength(1));
      expect(second.events, hasLength(1));
    });

    test('несёт слово, сырой факт, момент и кто спрашивал', () {
      final spy = _SpyObserver();
      final at = DateTime(2026, 8, 25, 21, 30);
      final session = _observed(
        FakeReviewSession(wordItems(2)),
        observers: [spy],
        at: at,
      );

      session.nextItem();
      session.report(_outcome(seconds: 2));

      final event = spy.events.single;
      expect(event.item.word.id, 'w01');
      expect(event.outcome.correct, isTrue);
      expect(event.outcome.responseTime, const Duration(seconds: 2));
      expect(event.at, at, reason: 'момент — как его отдал хост, без toUtc()');
      expect(event.gameId, 'falling_words');
      expect(event.sessionId, 'сессия-1');
    });

    test('оценка посчитана из ответа, а не выдумана', () {
      final spy = _SpyObserver();
      final session = _observed(
        FakeReviewSession(wordItems(3)),
        observers: [spy],
      );

      // 1 с из 6 — это 0.17 лимита, то есть easy по таблице скилла.
      session.nextItem();
      session.report(_outcome(seconds: 1));
      // Неверный ответ — always again, каким бы быстрым ни был.
      session.nextItem();
      session.report(_outcome(correct: false, seconds: 1));

      expect(spy.events.map((e) => e.grade), [
        ReviewGrade.easy,
        ReviewGrade.again,
      ]);
    });

    test('событие приходит после того, как ответ принят делегатом', () {
      late int answeredWhenNotified;
      final inner = FakeReviewSession(wordItems(2));
      final session = _observed(
        inner,
        observers: [
          _CallbackObserver((_) => answeredWhenNotified = inner.reports.length),
        ],
      );

      session.nextItem();
      session.report(_outcome());

      expect(
        answeredWhenNotified,
        1,
        reason:
            'наблюдатель обязан видеть согласованное состояние: доклад уже '
            'принят, а не «в полёте»',
      );
    });

    test('наблюдателей нет — сессия работает как обычно', () {
      final session = _observed(FakeReviewSession(wordItems(2)));

      session.nextItem();
      expect(() => session.report(_outcome()), returnsNormally);
    });

    test('упавший наблюдатель не глушится', () {
      final session = _observed(
        FakeReviewSession(wordItems(2)),
        observers: [_AngryObserver()],
      );
      session.nextItem();

      expect(() => session.report(_outcome()), throwsStateError);
    });
  });
}

/// Наблюдатель, который зовёт переданную функцию.
class _CallbackObserver implements ReviewObserver {
  _CallbackObserver(this._onEvent);

  final void Function(ReviewEvent) _onEvent;

  @override
  void onAnswer(ReviewEvent event) => _onEvent(event);
}
