import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/match_three/match_three_run.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';

const _llave = ReviewItem(
  word: Word(id: 'llave', text: 'llave', translation: 'ключ'),
  distractors: ['дверь', 'билет', 'окно'],
);

void _settle(MatchThreeRun run) {
  for (var i = 0; i < 40 && run.isAnimating; i++) {
    run.advance();
  }
  expect(run.isAnimating, isFalse);
}

void main() {
  test('обмены без совпадения возвращаются и сохраняют ходы', () {
    final session = FakeReviewSession([_llave]);
    final run = MatchThreeRun(session, Random(10));
    final before = List.of(run.cells);
    expect(before, hasLength(36));
    expect(run.swap(0, 12), isFalse);
    expect(run.swap(0, 1), isTrue);
    _settle(run);
    expect(run.phase, MatchThreePhase.ready);
    expect(run.cells, before);
    expect(run.moves, MatchThreeRun.moveLimit);
    expect(run.score, 0);
    expect(session.nextItemCalls, 0);
  });

  test('четвёрка открывает слово, правильный перевод очищает строку', () {
    final session = FakeReviewSession([_llave, _llave]);
    final run = MatchThreeRun(session, Random(10));
    expect(run.swap(9, 15), isTrue);
    _settle(run);
    expect(run.phase, MatchThreePhase.question);
    expect(run.moves, MatchThreeRun.moveLimit - 1);
    expect(run.item, same(_llave));
    expect(run.choices, hasLength(3));
    expect(run.swap(0, 1), isFalse);
    final chargedRow = run.cells.indexOf(MatchGem.charged) ~/ 6;
    final scoreBefore = run.score;
    expect(run.answer('ключ', Duration.zero), isTrue);
    expect(run.answer('ключ', Duration.zero), isFalse);
    expect(session.reports.single.outcome.correct, isTrue);
    run.advance();
    expect(run.phase, MatchThreePhase.clearing);
    expect(run.clearing, {for (var i = 0; i < 6; i++) chargedRow * 6 + i});
    _settle(run);
    expect(run.phase, MatchThreePhase.ready);
    expect(run.cells, isNot(contains(MatchGem.charged)));
    expect(run.cells, everyElement(isNotNull));
    expect(run.score, greaterThanOrEqualTo(scoreBefore + 120));
    expect(session.nextItemCalls, 1);
  });

  test('неверный перевод записывается один раз и оставляет обычные фишки', () {
    final session = FakeReviewSession([_llave]);
    final run = MatchThreeRun(session, Random(10));
    run.swap(9, 15);
    _settle(run);
    final charged = run.cells.indexOf(MatchGem.charged);
    final scoreBefore = run.score;
    final wrong = run.choices.firstWhere((value) => value != 'ключ');
    expect(run.answer(wrong, Duration.zero), isTrue);
    expect(session.reports.single.outcome.selectedAnswer, wrong);
    expect(session.reports.single.outcome.correct, isFalse);
    expect(run.score, scoreBefore);
    run.advance();
    expect(run.clearing, {charged});
    _settle(run);
    expect(run.phase, MatchThreePhase.finished);
    run.abandon();
    expect(session.reports, hasLength(1));
  });
}
