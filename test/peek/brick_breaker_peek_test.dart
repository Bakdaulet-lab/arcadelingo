@Tags(['peek'])
library;

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_review_session.dart';
import 'peek_harness.dart';

const _agua = ReviewItem(
  word: Word(id: 'agua', text: 'agua', translation: 'вода'),
  distractors: ['сок', 'вино', 'чай'],
);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('арканоид в теме ${brightness.name}', (tester) async {
      tester.view.physicalSize = peekPhysicalSize;
      tester.view.devicePixelRatio = peekDevicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: wordarcadeTheme(
            brightness: brightness,
            platform: TargetPlatform.android,
          ),
          home: BrickBreakerGame(
            session: FakeReviewSession([_agua, _agua]),
            onExit: () {},
            onPlayAgain: () {},
            seed: 19,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await peek(tester, 'brick_${brightness.name}_ready');
      await tester.tap(find.byKey(BrickBreakerKeys.launch));
      for (var i = 0; i < 140; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await peek(tester, 'brick_${brightness.name}_bonus');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
