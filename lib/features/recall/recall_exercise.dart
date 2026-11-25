import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/word_labels.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

/// One reverse question: the translation is the prompt and the studied word
/// is assembled from tiles or selected from the course's spellings.
class RecallExercise {
  RecallExercise({
    required this.item,
    required Iterable<Word> vocabulary,
    required Random random,
  }) {
    final graphemes = item.word.text.characters.toList();
    final hasLetters = graphemes.any(_letterOrDigit.hasMatch);
    _template = [
      for (final glyph in graphemes)
        if (!hasLetters || _letterOrDigit.hasMatch(glyph)) null else glyph,
    ];
    final letters = [
      for (final (i, glyph) in graphemes.indexed)
        if (_template[i] == null) glyph,
    ];
    final shuffled = letters.toList()..shuffle(random);
    if (shuffled.length > 1 && shuffled.join() == letters.join()) {
      final other = shuffled.indexWhere((glyph) => glyph != shuffled.first);
      if (other != -1) {
        final first = shuffled.first;
        shuffled[0] = shuffled[other];
        shuffled[other] = first;
      }
    }
    tiles = List.unmodifiable(shuffled);
    choices = _choices(item, vocabulary, random);
  }

  static final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);
  final ReviewItem item;
  late final List<String> tiles;
  late final List<String> choices;
  late final List<String?> _template;
  final _selected = <int>[];

  List<int> get selected => List.unmodifiable(_selected);

  List<String?> get slots {
    var next = 0;
    return [
      for (final fixed in _template)
        fixed ?? (next < _selected.length ? tiles[_selected[next++]] : null),
    ];
  }

  bool get complete => tiles.isNotEmpty && _selected.length == tiles.length;
  bool get correct =>
      complete && _courseLabel(slots.join()) == _courseLabel(item.word.text);

  void selectTile(int index) {
    if (index >= 0 && index < tiles.length && !_selected.contains(index)) {
      _selected.add(index);
    }
  }

  void undo() {
    if (_selected.isNotEmpty) _selected.removeLast();
  }

  void clear() => _selected.clear();

  bool isCorrectChoice(String choice) => choice == item.word.text;
}

List<String> _choices(
  ReviewItem item,
  Iterable<Word> vocabulary,
  Random random,
) {
  final target = item.word;
  final meanings = translationMeanings(_courseLabel(target.translation));
  final unavailable = {_courseLabel(target.text)};
  final curated = item.distractors.map(_courseLabel).toSet();
  final preferred = <String>[];
  final matchingPart = <String>[];
  final other = <String>[];

  for (final candidate in vocabulary) {
    if (candidate.level != target.level) continue;
    final translation = _courseLabel(candidate.translation);
    if (translationMeanings(translation).any(meanings.contains)) {
      // A spelling can have multiple cards. One correct sense rules out
      // presenting that spelling as wrong, regardless of source order.
      unavailable.add(_courseLabel(candidate.text));
    } else if (curated.contains(translation)) {
      preferred.add(candidate.text);
    } else if (target.partOfSpeech != null &&
        target.partOfSpeech == candidate.partOfSpeech) {
      matchingPart.add(candidate.text);
    } else {
      other.add(candidate.text);
    }
  }
  final result = [target.text];
  for (final pool in [preferred, matchingPart, other]) {
    pool.shuffle(random);
    for (final spelling in pool) {
      if (unavailable.add(_courseLabel(spelling))) {
        result.add(spelling.trim());
        if (result.length == 4) break;
      }
    }
    if (result.length == 4) break;
  }
  return List.unmodifiable(result..shuffle(random));
}

// Keyboards can enter accented letters either as one code point or as a base
// plus a combining mark. Keep the original tiles and compare equivalent
// spellings in the course languages without discarding meaningful accents.
const _accentLetters = {
  '\u0300': ('aeiou', 'àèìòù'),
  '\u0301': ('aeiouy', 'áéíóúý'),
  '\u0302': ('aeiou', 'âêîôû'),
  '\u0303': ('ano', 'ãñõ'),
  '\u0306': ('и', 'й'),
  '\u0308': ('aeiouyе', 'äëïöüÿё'),
  '\u030a': ('a', 'å'),
  '\u0327': ('c', 'ç'),
};
final _combiningLetter = RegExp(r'([a-zеи])(\p{M})', unicode: true);

String _courseLabel(String value) =>
    normalizedWordLabel(value).replaceAllMapped(_combiningLetter, (match) {
      final forms = _accentLetters[match[2]];
      if (forms == null) return match[0]!;
      final index = forms.$1.indexOf(match[1]!);
      return index < 0 ? match[0]! : forms.$2[index];
    });
