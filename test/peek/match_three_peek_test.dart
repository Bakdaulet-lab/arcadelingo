@Tags(['peek'])
library;

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/match_three/match_three_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_review_session.dart';
import 'peek_harness.dart';

const _item = ReviewItem(
  word: Word(id: 'llave', text: 'llave', translation: 'ключ'),
  distractors: ['дверь', 'билет'],
);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('три в ряд — ${brightness.name}', (tester) async {
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
          home: MatchThreeGame(
            session: FakeReviewSession([_item, _item]),
            onPlayAgain: () {},
            onExit: () {},
            course: StudyCourse.spanishFromRussian,
            level: CefrLevel.a1,
            seed: 10,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await peek(tester, 'match_three_${brightness.name}_ready');
      await tester.tap(find.byKey(MatchThreeKeys.cell(9)));
      await tester.pump();
      await tester.tap(find.byKey(MatchThreeKeys.cell(15)));
      await tester.pumpAndSettle();
      await peek(tester, 'match_three_${brightness.name}_bonus');
    });
  }
}
