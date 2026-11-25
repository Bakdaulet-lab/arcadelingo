import 'dart:math';

import 'package:arcadelingo/domain/learning/custom_review_items.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/leitner_review_session.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_run.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_run.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/match_three/match_three_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/features/games/snake/snake_run.dart';
import 'package:arcadelingo/features/games/word_mahjong/word_mahjong_board.dart';
import 'package:flutter_test/flutter_test.dart';

const _key = Word(id: 'key', text: 'llave', translation: 'ключ');
const _door = Word(id: 'custom:door', text: 'puerta', translation: 'дверь');
const _outside = Word(id: 'outside', text: 'mesa', translation: 'стол');

void main() {
  for (final words in [
    const [_key],
    const [_key, _door],
  ]) {
    test('all seven games can present just ${words.length} set member(s)', () {
      final items = buildWordSetReviewItems(
        vocabulary: const [_outside, _key, _door],
        wordIds: words.map((word) => word.id),
        level: CefrLevel.a1,
      );
      BoardReviewSession session() => LeitnerReviewSession.start(
        cards: {},
        items: items,
        target: 15,
        practiceAll: true,
        now: () => DateTime.utc(2026, 11, 25),
        onCardsChanged: (_) {},
      );
      final translations = unorderedEquals(
        words.map((word) => word.translation),
      );

      final falling = FallingWordsRun(session: session(), random: Random(7))
        ..start();
      expect(falling.item!.word, _key);
      expect(falling.options, translations);

      final ninja = NinjaRun(session: session(), random: Random(7))..start();
      expect(ninja.item!.word, _key);
      expect(ninja.options, translations);

      final clawSession = session();
      final claw = ClawMachineRun(clawSession, Random(7))..advance();
      for (final word in words) {
        expect(claw.item!.word, same(word));
        expect(claw.answer, word.text.toUpperCase());
        for (final slot in claw.slots) {
          final column = claw.stacks.indexWhere((stack) => stack.last == slot);
          claw.grab(column, Duration.zero);
        }
        claw.advance();
      }
      expect(claw.item, isNull);

      final bricks = BrickBreakerRun(session(), Random(7))..launch();
      bricks.advance(const Duration(seconds: 2));
      expect(bricks.item!.word, _key);
      expect(bricks.choices, translations);

      final match = MatchThreeRun(session(), Random(10))..swap(9, 15);
      for (var i = 0; i < 40 && match.isAnimating; i++) {
        match.advance();
      }
      expect(match.item!.word, _key);
      expect(match.choices, translations);

      final board = WordMahjongBoard.deal(session().remainingItems, Random(7));
      expect(
        board.tiles.map((tile) => tile.label),
        unorderedEquals([
          for (final word in words) ...[word.text, word.translation],
        ]),
      );
      for (var i = 0; i < words.length; i++) {
        final pair = board.hint!;
        expect(board.match(pair.word, pair.translation), isTrue);
      }
      expect(board.isCleared, isTrue);

      final snake = SnakeRun(session(), [
        for (final item in items) item.word,
      ], Random(7));
      expect(snake.item!.word, _key);
      expect(snake.apples.map((apple) => apple.word), unorderedEquals(words));
    });
  }
}
