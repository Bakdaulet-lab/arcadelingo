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
    expect(run.paddle, BrickBreakerRun.paddleHalfWidth);
    expect(session.nextItemCalls, 1);
    expect(session.reports, isEmpty);
    run.abandon();
    expect(session.reports.single.outcome.selectedAnswer, isNull);
  });

  test('следующий золотой кирпич открыт и находится в другой части поля', () {
    final run = BrickBreakerRun(FakeReviewSession([agua]), Random(7));
    final first = run.bricks.singleWhere((brick) => brick.gold);
    openBonus(run);
    final next = run.bricks.singleWhere((brick) => brick.gold);
    expect(
      (first.bounds.center.dx - next.bounds.center.dx).abs(),
      greaterThanOrEqualTo(84),
    );
    expect(
      run.bricks.where(
        (b) =>
            b.bounds.center.dx == next.bounds.center.dx &&
            b.bounds.top > next.bounds.top,
      ),
      isEmpty,
    );
  });

  test('длинные варианты дают больше времени на чтение', () {
    const word = ReviewItem(
      word: Word(
        id: 'estiaje',
        text: 'estiaje',
        translation: 'сезонный минимум уровня воды в реке',
      ),
      distractors: ['приток', 'дно реки'],
    );
    final session = FakeReviewSession([word]);
    final run = BrickBreakerRun(session, Random(8));
    openBonus(run);
    run.movePaddle(run.laneCenter(run.choices.indexOf(word.word.translation)));
    run.advance(const Duration(milliseconds: 2600));
    expect(session.reports, isEmpty);
    run.advance(const Duration(seconds: 2));
    expect(session.reports.single.outcome.correct, isTrue);
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

  test('в испытании пропуск расходует один из трёх бонусов', () {
    final session = FakeReviewSession([agua, agua, agua]);
    final run = BrickBreakerRun(session, Random(11), challenge: true);
    expect(run.lives, 1);
    for (var i = 0; i < 3; i++) {
      final gold = run.bricks.singleWhere((brick) => brick.gold);
      run.movePaddle(gold.bounds.center.dx);
      openBonus(run);
      run.movePaddle(0);
      run.advance(const Duration(seconds: 6));
      expect(session.reports, hasLength(i + 1));
      expect(session.reports.last.outcome.timedOut, isTrue);
      expect(session.reports.last.outcome.selectedAnswer, isNull);
    }
    expect(run.phase, BrickPhase.finished);
    expect(run.lives, 1);
    expect(run.correctCount, 0);
    expect(run.score, 30);
  });

  test('испытание заканчивается при потере последнего мяча', () {
    final session = FakeReviewSession([agua, agua, agua]);
    final run = BrickBreakerRun(session, Random(11), challenge: true);
    run.movePaddle(40);
    run.launch();
    run.movePaddle(BrickBreakerRun.width);
    run.advance(const Duration(seconds: 6));
    expect(run.phase, BrickPhase.finished);
    expect(run.lives, 0);
    expect(session.reports, isEmpty);
  });
}
