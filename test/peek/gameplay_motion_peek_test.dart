@Tags(['peek'])
library;

import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/session/leitner_review_session.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_game.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/match_three/match_three_field.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_views.dart';
import 'package:arcadelingo/features/games/snake/snake_game.dart';
import 'package:arcadelingo/features/games/word_mahjong/word_mahjong_field.dart';
import 'package:arcadelingo/features/games/word_maze/word_maze_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'peek_harness.dart';

const _pairs = {
  'apple': 'яблоко',
  'fish': 'рыба',
  'key': 'ключ',
  'moon': 'луна',
};

void main() {
  for (final game in wordarcadeGames) {
    for (final brightness in Brightness.values) {
      testWidgets('${game.id} в движении, ${brightness.name}', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        final items = [
          for (final entry in _pairs.entries)
            ReviewItem(
              word: Word(
                id: entry.key,
                text: entry.key,
                translation: entry.value,
              ),
              distractors:
                  _pairs.values.where((text) => text != entry.value).toList(),
            ),
        ];
        final launch = GameLaunch(
          session: LeitnerReviewSession.start(
            cards: {},
            items: items,
            target: items.length,
            now: () => DateTime(2026, 11, 21),
            onCardsChanged: (_) {},
          ),
          course: StudyCourse.englishFromRussian,
          level: CefrLevel.a1,
          vocabulary: items.map((item) => item.word),
          summaryFooter: () => '',
          onRoundOver: () {},
          onPlayAgain: () {},
          onExit: () {},
        );
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: wordarcadeTheme(
              brightness: brightness,
              platform: TargetPlatform.android,
            ),
            home: game.build(launch),
          ),
        );
        await tester.pump();
        if (game == fallingWordsEntry || game == ninjaSlashEntry) {
          await tester.pump(
            game == ninjaSlashEntry
                ? NinjaRun.windUpTime
                : FallingWordsRun.windUpTime,
          );
          await tester.pump(const Duration(milliseconds: 850));
        }
        Future<void> tap(Key key) => tester.tap(find.byKey(key));
        TestGesture? snakeGesture;
        final frames = game == snakeEntry ? 41 : 21;
        for (var frame = 0; frame < frames; frame++) {
          if (frame == 2) {
            if (game == wordMazeEntry) {
              await tester.drag(
                find.byKey(MazeKeys.field),
                const Offset(0, -48),
              );
            }
            if (game == snakeEntry) {
              final field = find.byKey(SnakeKeys.field);
              snakeGesture = await tester.startGesture(tester.getCenter(field));
              await snakeGesture.moveBy(const Offset(24, 0));
            }
            if (game == matchThreeEntry) await tap(MatchThreeKeys.cell(9));
            if (game == brickBreakerEntry) await tap(BrickBreakerKeys.launch);
            if (game == clawMachineEntry) await tap(ClawKeys.right);
            if (game == wordMahjongEntry) {
              final field = tester.widget<WordMahjongField>(
                find.byType(WordMahjongField),
              );
              await tap(WordMahjongKeys.tile(field.board.hint!.word.index));
            }
          }
          if (frame == 7) {
            if (game == fallingWordsEntry) {
              await tester.tap(find.text('яблоко').last);
            }
            if (game == ninjaSlashEntry) {
              final at = tester.getCenter(find.byKey(NinjaKeys.objectAt(1)));
              final finger = await tester.startGesture(
                at - const Offset(30, 0),
              );
              await finger.moveTo(at + const Offset(30, 0));
              await finger.up();
            }
            if (game == clawMachineEntry) await tap(ClawKeys.grab);
            if (game == snakeEntry) {
              await snakeGesture!.moveBy(const Offset(0, -24));
            }
            if (game == matchThreeEntry) await tap(MatchThreeKeys.cell(15));
            if (game == wordMahjongEntry) {
              final field = tester.widget<WordMahjongField>(
                find.byType(WordMahjongField),
              );
              await tap(
                WordMahjongKeys.tile(field.board.hint!.translation.index),
              );
            }
          }
          if (game == wordMazeEntry && frame == 12) {
            await tester.drag(find.byKey(MazeKeys.field), const Offset(48, 0));
          }
          if (game == snakeEntry && frame == 19) {
            await snakeGesture!.moveBy(const Offset(24, 0));
          }
          await tester.pump(const Duration(milliseconds: 40));
          await peek(tester, '${game.id}_${brightness.name}_$frame');
        }
        await snakeGesture?.up();
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
