import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/word_mahjong/word_mahjong_board.dart';
import 'package:flutter_test/flutter_test.dart';

ReviewItem _item(int index, {String? translation}) => ReviewItem(
  word: Word(
    id: '$index',
    text: 'word $index',
    translation: translation ?? 'перевод $index',
  ),
);

void main() {
  test('all sizes stay solvable through any sequence of available matches', () {
    for (var count = 1; count <= 6; count++) {
      for (var seed = 0; seed < 80; seed++) {
        final items = List.generate(count, _item);
        final random = Random(seed);
        final board = WordMahjongBoard.deal(items, random);
        expect(board.tiles, hasLength(count * 2));
        for (final item in items) {
          final pair = board.tiles.where((tile) => tile.item == item);
          expect(
            pair.map((tile) => tile.isTranslation),
            unorderedEquals([true, false]),
          );
        }
        if (count == 6) {
          expect(board.tiles.where((tile) => !board.isFree(tile)), isNotEmpty);
          expect(board.tiles.where((tile) => tile.layer == 1), hasLength(3));
        }
        for (var i = 0; i < count; i++) {
          expect(
            board.hint,
            isNotNull,
            reason: 'size $count, seed $seed, pair $i',
          );
          final free =
              board.tiles.where(board.isFree).toList()..shuffle(random);
          final first = free.firstWhere(
            (tile) =>
                free.any((other) => other != tile && other.item == tile.item),
          );
          final second = free.singleWhere(
            (tile) => tile != first && tile.item == first.item,
          );
          expect(board.match(first, first), isFalse);
          expect(board.match(first, second), isTrue);
          expect(board.match(first, second), isFalse);
        }
        expect(board.isCleared, isTrue);
      }
    }
  });

  test(
    'covered and side-blocked tiles obey the same rules even if they form a pair',
    () {
      final board = WordMahjongBoard.deal(List.generate(6, _item), Random(7));
      final covered = board.tiles.firstWhere(
        (tile) =>
            tile.layer == 0 &&
            board.tiles.any(
              (top) =>
                  top.layer == 1 &&
                  top.row == tile.row &&
                  top.column == tile.column,
            ),
      );
      final partner = board.tiles.singleWhere(
        (tile) => tile.item == covered.item && tile != covered,
      );
      expect(board.isFree(covered), isFalse);
      expect(board.match(covered, partner), isFalse);
      final center = board.tiles.singleWhere(
        (tile) => tile.layer == 0 && tile.row == 3 - 1 && tile.column == 1,
      );
      expect(board.isFree(center), isFalse);
    },
  );

  test('duplicate visible translations are deferred to another board', () {
    final items = [
      _item(0, translation: 'ключ'),
      _item(1, translation: ' Ключ '),
      _item(2),
    ];
    final board = WordMahjongBoard.deal(items, Random(0));
    expect(board.tiles.map((tile) => tile.item).toSet(), {items[0], items[2]});
  });
}
