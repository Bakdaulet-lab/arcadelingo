@Tags(['peek'])
library;

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_review_session.dart';
import 'peek_harness.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('long ninja labels in ${brightness.name}', (tester) async {
      tester.view.physicalSize = peekPhysicalSize;
      tester.view.devicePixelRatio = peekDevicePixelRatio;
      addTearDown(tester.view.reset);
      const samples = [
        ReviewItem(
          word: Word(
            id: 'vocational',
            text: 'vocational',
            translation: 'профессионально-технический',
          ),
          distractors: ['общеобразовательный', 'дошкольный', 'любительский'],
        ),
        ReviewItem(
          word: Word(
            id: 'pertinent',
            text: 'pertinent',
            translation: 'непосредственно связанный с вопросом',
          ),
          distractors: [
            'не имеющий отношения к теме',
            'противоречащий себе',
            'преждевременно высказанный',
          ],
        ),
      ];
      for (final item in samples) {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: wordarcadeTheme(
              brightness: brightness,
              platform: TargetPlatform.android,
            ),
            home: NinjaSlashGame(
              key: ValueKey(item.word.id),
              session: FakeReviewSession([item]),
              seed: 3,
              onPlayAgain: () {},
              onExit: () {},
            ),
          ),
        );
        await tester.pump(NinjaRun.windUpTime);
        await tester.pump(const Duration(milliseconds: 1750));
        await peek(tester, 'ninja_${item.word.id}_${brightness.name}');
      }
    });
  }
}
