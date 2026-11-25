@Tags(['peek'])
library;

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/leitner_review_session.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/match_three/match_three_game.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_game.dart';
import 'package:arcadelingo/features/games/word_mahjong/word_mahjong_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_review_session.dart';
import 'peek_harness.dart';

const _phrase = ReviewItem(
  word: Word(
    id: 'state_of_emergency',
    text: 'declare a state of emergency',
    translation: 'объявить чрезвычайное положение',
  ),
  distractors: [
    'отложить запланированное мероприятие',
    'предупредить местных жителей',
    'расследовать обстоятельства',
  ],
);

const _pertinent = ReviewItem(
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
);

const _notice = ReviewItem(
  word: Word(
    id: 'take_notice',
    text: 'take notice',
    translation: 'обратить особое внимание',
  ),
);

void _close() {}

Future<void> _open(
  WidgetTester tester,
  Brightness brightness, {
  required double textScale,
  required Widget game,
}) async {
  tester.view.physicalSize = const Size(640, 1640);
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: wordarcadeTheme(
        brightness: brightness,
        platform: TargetPlatform.android,
      ),
      home: game,
    ),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    final name = brightness.name;

    testWidgets('readable ninja in $name', (tester) async {
      await _open(
        tester,
        brightness,
        textScale: 1.25,
        game: NinjaSlashGame(
          session: FakeReviewSession([_pertinent]),
          seed: 3,
          onPlayAgain: _close,
          onExit: _close,
        ),
      );
      await tester.pump(NinjaRun.windUpTime);
      await tester.pump(const Duration(milliseconds: 1500));
      await peek(tester, 'readable_ninja_$name');
    });

    testWidgets('readable falling words in $name', (tester) async {
      await _open(
        tester,
        brightness,
        textScale: 1.2,
        game: FallingWordsGame(
          session: FakeReviewSession([_phrase]),
          seed: 3,
          onPlayAgain: _close,
          onExit: _close,
        ),
      );
      await tester.pump(FallingWordsRun.windUpTime);
      await tester.pump(const Duration(milliseconds: 900));
      await peek(tester, 'readable_falling_$name');
    });

    testWidgets('readable match three in $name', (tester) async {
      await _open(
        tester,
        brightness,
        textScale: 1.4,
        game: MatchThreeGame(
          session: FakeReviewSession([_phrase]),
          seed: 10,
          onPlayAgain: _close,
          onExit: _close,
        ),
      );
      for (final cell in [9, 15]) {
        final gem = find.byKey(MatchThreeKeys.cell(cell));
        await tester.ensureVisible(gem);
        await tester.tap(gem);
        await tester.pumpAndSettle();
      }
      await peek(tester, 'readable_match_$name');
    });

    testWidgets('readable claw in $name', (tester) async {
      await _open(
        tester,
        brightness,
        textScale: 1.6,
        game: ClawMachineGame(
          session: FakeReviewSession([_notice]),
          seed: 11,
          now: tester.binding.clock.now,
          onPlayAgain: _close,
          onExit: _close,
        ),
      );
      await tester.pumpAndSettle();
      await peek(tester, 'readable_claw_$name');
    });

    testWidgets('readable mahjong in $name', (tester) async {
      final session = LeitnerReviewSession.start(
        cards: {},
        items: const [_phrase, _pertinent, _notice],
        target: 3,
        now: () => DateTime.utc(2026, 11, 21),
        onCardsChanged: (_) {},
      );
      await _open(
        tester,
        brightness,
        textScale: 1.4,
        game: WordMahjongGame(
          session: session,
          seed: 3,
          onPlayAgain: _close,
          onExit: _close,
        ),
      );
      await tester.pumpAndSettle();
      await peek(tester, 'readable_mahjong_$name');
    });
  }
}
