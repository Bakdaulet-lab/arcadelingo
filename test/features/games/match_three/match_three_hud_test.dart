import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/match_three/match_three_game.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';

const _item = ReviewItem(
  word: Word(id: 'estrenar', text: 'estrenar', translation: 'использовать впервые'),
  distractors: ['согласовать встречу', 'переехать в новый дом'],
);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('the first charge brings the word into view in ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(320, 560);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.45;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final session = FakeReviewSession([_item]);
      await tester.pumpWidget(MaterialApp(
        theme: wordarcadeTheme(brightness: brightness),
        home: MatchThreeGame(
          session: session, seed: 10, onExit: () {}, onPlayAgain: () {},
        ),
      ));
      final field = find.byKey(MatchThreeKeys.field);
      final strings = tester.element(field).strings;
      await tester.tap(find.byTooltip(strings.matchHowTo));
      await tester.pumpAndSettle();
      expect(find.text(strings.matchCrossRule), findsOneWidget);
      await tester.tap(find.text(strings.play));
      await tester.pumpAndSettle();
      for (final cell in [9, 15]) {
        final target = find.byKey(MatchThreeKeys.cell(cell));
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }
      expect(find.byKey(MatchThreeKeys.word).hitTestable(), findsOneWidget);
      expect(find.text(strings.matchBonus), findsOneWidget);
      expect(find.text(_item.word.translation).hitTestable(), findsOneWidget);
      await tester.tap(find.text(_item.word.translation));
      await tester.pumpAndSettle();
      expect(session.reports.single.outcome.correct, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
