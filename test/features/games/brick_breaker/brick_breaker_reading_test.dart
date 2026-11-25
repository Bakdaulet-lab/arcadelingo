import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_field.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_game.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_run.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';

const _word = Word(
  id: 'evacuation',
  text: 'declare a state of emergency',
  translation: 'объявить чрезвычайное положение',
);

BrickBreakerRun _bonus(List<String> choices) {
  final run = BrickBreakerRun(
    FakeReviewSession([ReviewItem(word: _word, distractors: choices)]),
    Random(4),
  )..launch();
  while (run.phase == BrickPhase.flying) {
    run.advance(const Duration(milliseconds: 8));
  }
  expect(run.phase, BrickPhase.bonus);
  return run;
}

int _hold(BrickBreakerRun run) {
  final initial = run.dropY;
  var ms = 0;
  while (ms < 10000 && run.dropY == initial) {
    run.advance(const Duration(milliseconds: 10));
    ms += 10;
  }
  return ms;
}

void main() {
  test('time to read accounts for all three translations', () {
    final single = _bonus(['снег', 'поле']);
    final several = _bonus([
      'объявить перерыв в заседании',
      'установить личность свидетеля',
    ]);
    expect(_hold(several) - _hold(single), greaterThanOrEqualTo(600));
  });

  test('the player has time to read a long correction after a wrong catch', () {
    final run = _bonus(['снег', 'поле']);
    run.movePaddle(run.laneCenter(run.choices.indexOf('поле')));
    while (run.phase == BrickPhase.bonus) {
      run.advance(const Duration(milliseconds: 16));
    }
    expect(run.lastAnswer, 'поле');
    run.advance(const Duration(milliseconds: 1450));
    expect(run.phase, BrickPhase.feedback);
    run.advance(const Duration(seconds: 4));
    expect(run.phase, BrickPhase.finished);
  });

  testWidgets('a long prompt wraps at the chosen text size on a small phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: wordarcadeTheme(brightness: Brightness.dark),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.4)),
              child: child!,
            ),
        home: BrickBreakerGame(
          session: FakeReviewSession([
            const ReviewItem(word: _word, distractors: ['снег', 'поле']),
          ]),
          onExit: () {},
          onPlayAgain: () {},
        ),
      ),
    );
    final launch = find.byKey(BrickBreakerKeys.launch);
    await tester.ensureVisible(launch);
    await tester.tap(launch);
    await tester.pump();
    final field = tester.widget<BrickBreakerField>(
      find.byType(BrickBreakerField),
    );
    for (var i = 0; i < 100 && field.run.phase == BrickPhase.flying; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    final prompt = find.byKey(BrickBreakerKeys.word);
    final box = tester.renderObject<RenderBox>(prompt);
    final unit =
        box.localToGlobal(const Offset(1, 0)) - box.localToGlobal(Offset.zero);
    expect(unit.dx, closeTo(1, .01));
    expect(box.size.height, greaterThan(44));
    expect(tester.takeException(), isNull);
  });
}
