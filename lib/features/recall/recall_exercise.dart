import 'dart:math';

import 'package:arcadelingo/domain/review/hangul.dart';
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
    this.studyLanguage = 'en',
  }) {
    final hangul = HangulSpelling.forWord(item.word.text);
    _hangul = hangul != null;
    spelling = hangul?.tiles ?? item.word.text.characters.toList();
    final graphemes = spelling;
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
    choices = _choices(item, vocabulary, random, studyLanguage);
  }

  static final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);
  final ReviewItem item;
  final String studyLanguage;
  late final List<String> tiles;
  late final List<String> choices;
  late final List<String> spelling;
  late final bool _hangul;
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
      complete &&
      (_hangul
          ? slots.join() == spelling.join()
          : normalizedCourseSpelling(
                slots.join(),
                studyLanguage: studyLanguage,
              ) ==
              normalizedCourseSpelling(
                item.word.text,
                studyLanguage: studyLanguage,
              ));

  String get answerText => _hangul && correct ? item.word.text : slots.join();

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
  String studyLanguage,
) {
  String spellingOf(String value) =>
      normalizedCourseSpelling(value, studyLanguage: studyLanguage);

  final target = item.word;
  final meanings = translationMeanings(
    normalizedCourseSpelling(target.translation),
  );
  final unavailable = {spellingOf(target.text)};
  final curated = item.distractors.map(normalizedCourseSpelling).toSet();
  final preferred = <String>[];
  final matchingPart = <String>[];
  final other = <String>[];

  for (final candidate in vocabulary) {
    if (candidate.level != target.level) continue;
    final translation = normalizedCourseSpelling(candidate.translation);
    if (translationMeanings(translation).any(meanings.contains)) {
      // A spelling can have multiple cards. One correct sense rules out
      // presenting that spelling as wrong, regardless of source order.
      unavailable.add(spellingOf(candidate.text));
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
      if (unavailable.add(spellingOf(spelling))) {
        result.add(spelling.trim());
        if (result.length == 4) break;
      }
    }
    if (result.length == 4) break;
  }
  return List.unmodifiable(result..shuffle(random));
}
