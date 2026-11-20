import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';

typedef _Slot = ({int row, int column, int layer});
typedef MahjongPair = ({MahjongTile word, MahjongTile translation});

class MahjongTile {
  const MahjongTile._(this.index, this._slot, this.item, this.isTranslation);

  final int index;
  final _Slot _slot;
  final ReviewItem item;
  final bool isTranslation;

  int get row => _slot.row;
  int get column => _slot.column;
  int get layer => _slot.layer;
  String get label => isTranslation ? item.word.translation : item.word.text;
}

class WordMahjongBoard {
  WordMahjongBoard._(this.tiles);

  static const columns = 3;
  static const _maxPairs = 6;

  /// Deal onto a random legal removal path. Removing any other legal pair
  /// along the way only frees tiles, so the rest of the path remains playable.
  factory WordMahjongBoard.deal(List<ReviewItem> items, Random random) {
    final words = <String>{};
    final translations = <String>{};
    final pairs = <ReviewItem>[];
    for (final item in items) {
      final word = item.word.text.trim().toLowerCase();
      final translation = item.word.translation.trim().toLowerCase();
      if (words.contains(word) || translations.contains(translation)) continue;
      words.add(word);
      translations.add(translation);
      pairs.add(item);
      if (pairs.length == _maxPairs) break;
    }
    pairs.shuffle(random);

    final tileCount = pairs.length * 2;
    final stacked = switch (tileCount) {
      12 => 3,
      8 || 10 => 2,
      6 => 1,
      _ => 0,
    };
    final slotCount = tileCount - stacked;
    final rowWidth = tileCount <= 4 ? 2 : columns;
    final slots = [
      for (var i = 0; i < slotCount; i++)
        (row: i ~/ rowWidth, column: i % rowWidth, layer: 0),
      for (var row = 0; row < stacked; row++) (row: row, column: 1, layer: 1),
    ];
    final active = List.of(slots);
    final tiles = <MahjongTile>[];
    for (final item in pairs) {
      final free =
          active.where((slot) => _isOpen(slot, active)).toList()
            ..shuffle(random);
      // Clear the upper layer early so the last two tiles cannot be stacked.
      final first = free.firstWhere(
        (slot) => slot.layer > 0,
        orElse: () => free.first,
      );
      free.remove(first);
      final second = free.first;
      final pair = random.nextBool() ? [first, second] : [second, first];
      for (final (side, slot) in pair.indexed) {
        tiles.add(MahjongTile._(slots.indexOf(slot), slot, item, side == 1));
        active.remove(slot);
      }
    }
    tiles.sort((first, second) => first.index.compareTo(second.index));
    return WordMahjongBoard._(List.unmodifiable(tiles));
  }

  final List<MahjongTile> tiles;
  final Set<MahjongTile> _removed = {};

  bool contains(MahjongTile tile) =>
      tiles.contains(tile) && !_removed.contains(tile);

  bool get isCleared => _removed.length == tiles.length;

  bool isCovered(MahjongTile tile) =>
      tiles.any((other) => contains(other) && _covers(other._slot, tile._slot));

  bool isFree(MahjongTile tile) =>
      contains(tile) &&
      _isOpen(tile._slot, tiles.where(contains).map((other) => other._slot));

  bool match(MahjongTile first, MahjongTile second) {
    if (first.item != second.item ||
        first.isTranslation == second.isTranslation ||
        !isFree(first) ||
        !isFree(second)) {
      return false;
    }
    _removed.addAll([first, second]);
    return true;
  }

  MahjongPair? get hint {
    final free = tiles.where(isFree).toList();
    for (final word in free.where((tile) => !tile.isTranslation)) {
      for (final translation in free.where((tile) => tile.isTranslation)) {
        if (word.item == translation.item) {
          return (word: word, translation: translation);
        }
      }
    }
    return null;
  }

  static bool _covers(_Slot upper, _Slot lower) =>
      upper.layer > lower.layer &&
      upper.row == lower.row &&
      upper.column == lower.column;

  static bool _isOpen(_Slot slot, Iterable<_Slot> active) {
    var left = false;
    var right = false;
    for (final other in active) {
      if (_covers(other, slot)) return false;
      if (other.row != slot.row || other.layer != slot.layer) continue;
      left = left || other.column == slot.column - 1;
      right = right || other.column == slot.column + 1;
    }
    return !left || !right;
  }
}
