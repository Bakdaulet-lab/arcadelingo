import 'dart:math';

import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_field.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';
import '../../../support/review_items.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('paddle keeps the grab offset and one finger, $brightness', (
      tester,
    ) async {
      final run = BrickBreakerRun(FakeReviewSession(wordItems(1)), Random(5));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Center(
            child: SizedBox(
              width: 320,
              child: BrickBreakerField(run: run, onMove: run.movePaddle),
            ),
          ),
        ),
      );
      final field = find.byType(BrickBreakerField);
      final scale = tester.getSize(field).width / BrickBreakerRun.width;
      final corner = tester.getTopLeft(field);
      Offset point(double x, double y) => corner + Offset(x, y) * scale;
      final primary = await tester.startGesture(
        point(207, BrickBreakerRun.paddleY + 3),
        pointer: 1,
      );
      expect(run.paddle, 180);
      await primary.moveBy(Offset(3 * scale, 0));
      expect(run.paddle, closeTo(183, .001));
      final secondary = await tester.startGesture(point(66, 140), pointer: 2);
      await secondary.moveTo(point(123, 140));
      expect(run.paddle, closeTo(183, .001));
      await secondary.up();
      await primary.moveTo(point(240, BrickBreakerRun.paddleY + 3));
      expect(run.paddle, closeTo(213, .001));
      await primary.cancel();
      await tester.tapAt(point(96, 110));
      expect(run.paddle, closeTo(96, .001));
    });
  }

  const step = Duration(microseconds: 8333);
  test('side wall and ceiling preserve distance left in a physics step', () {
    final run = BrickBreakerRun(FakeReviewSession(wordItems(1)), Random(5));
    run.launch();
    final ball = run.balls.single;
    ball.position = const Offset(5.5, 5.5);
    ball.velocity = const Offset(-180, -240);
    run.advance(step);
    expect(ball.position.dx, closeTo(5 + 180 * .008333 - .5, .001));
    expect(ball.position.dy, closeTo(5 + 240 * .008333 - .5, .001));
    expect(ball.velocity, const Offset(180, 240));
  });

  test('brick and paddle rebound immediately past the contact point', () {
    final run = BrickBreakerRun(FakeReviewSession(wordItems(1)), Random(5));
    run.launch();
    final ball = run.balls.single;
    final brick = run.bricks.firstWhere((brick) => brick.row == 3);
    final bottom = brick.bounds.bottom + BrickBreakerRun.ballRadius;
    ball.position = Offset(brick.bounds.center.dx, bottom + .2);
    ball.velocity = const Offset(0, -260);
    run.advance(step);
    expect(run.impacts.single.brick, same(brick));
    expect(ball.position.dy, closeTo(bottom + 260 * .008333 - .2, .001));
    expect(ball.velocity.dy, 260);

    const top = BrickBreakerRun.paddleY - BrickBreakerRun.ballRadius;
    ball.position = Offset(run.paddle + 16, top - .2);
    ball.velocity = const Offset(0, 260);
    run.advance(step);
    expect(ball.velocity.dx, isPositive);
    expect(ball.velocity.dy, isNegative);
    expect(
      ball.position.dy,
      closeTo(top + ball.velocity.dy * (.008333 - .2 / 260), .001),
    );
    expect(
      ball.position.dx,
      closeTo(run.paddle + 16 + ball.velocity.dx * (.008333 - .2 / 260), .001),
    );
  });
}
