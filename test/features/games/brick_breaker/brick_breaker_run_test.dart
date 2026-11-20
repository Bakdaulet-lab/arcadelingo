import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_run.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';

const agua = ReviewItem(
  word: Word(id: 'agua', text: 'agua', translation: 'вода'),
  distractors: ['сок', 'вино', 'чай'],
);

void openBonus(BrickBreakerRun run) {
  run.launch();
  run.advance(const Duration(seconds: 2));
  expect(run.phase, BrickPhase.bonus);
}

void main() {
  test('ловля платформой выдаёт три мяча и один учебный ответ', () {
    final session = FakeReviewSession([agua, agua]);
    final run = BrickBreakerRun(session, Random(4));
    openBonus(run);
    expect(run.item, same(agua));
    expect(run.choices, hasLength(3));
    final position = run.balls.single.position;
    run.movePaddle(run.laneCenter(run.choices.indexOf('вода')));
    run.advance(const Duration(seconds: 1));
    expect(run.balls.single.position, position);
    expect(session.reports, isEmpty);
    run.advance(const Duration(seconds: 6));
    expect(session.reports.single.outcome.correct, isTrue);
    expect(session.reports.single.outcome.selectedAnswer, 'вода');
    expect(run.balls, hasLength(3));
    run.abandon();
    expect(session.reports, hasLength(1));
  });

  test('пропущенные дорожки оставляют карточку на следующую попытку', () {
    final session = FakeReviewSession([agua]);
    final run = BrickBreakerRun(session, Random(3));
    openBonus(run);
    run.movePaddle(0);
    run.advance(const Duration(seconds: 6));
    expect(run.missedDrop, isTrue);
    expect(run.phase, BrickPhase.serve);
    expect(session.nextItemCalls, 1);
    expect(session.reports, isEmpty);
    run.abandon();
    expect(session.reports.single.outcome.selectedAnswer, isNull);
  });

  test('пойманная обманка попадает в разбор, а партия завершается', () {
    final session = FakeReviewSession([agua]);
    final run = BrickBreakerRun(session, Random(9));
    openBonus(run);
    final wrong = run.choices.firstWhere((choice) => choice != 'вода');
    run.movePaddle(run.laneCenter(run.choices.indexOf(wrong)));
    run.advance(const Duration(seconds: 6));
    expect(session.reports.single.outcome.correct, isFalse);
    expect(session.reports.single.outcome.selectedAnswer, wrong);
    expect(run.phase, BrickPhase.finished);
  });
}
