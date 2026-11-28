import 'dart:math';

import 'package:arcadelingo/domain/review/hangul.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/word_labels.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

/// Партия хранит только раскладку и попытку по выданному слову.
class ClawMachineRun {
  ClawMachineRun(
    this.session,
    this.random, {
    int? hintLimit,
    this.studyLanguage = 'en',
  }) : _hintsRemaining = hintLimit,
       _alphabet = switch (studyLanguage) {
         'ru' => 'АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ',
         'de' => 'ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÜẞ',
         'fr' => 'ABCDEFGHIJKLMNOPQRSTUVWXYZÀÂÆÇÉÈÊËÎÏÔŒÙÛÜŸ',
         'zh' => '你我他她它们的这那有在去来看学说听写吃喝水火木土山上下中大小日月人心东西南北',
         'ar' => 'ابتثجحخدذرزسشصضطظعغفقكلمنهويأإآؤئةىء',
         'ko' => '가나다라마바사아자차카타파하',
         'ja' => 'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん',
         _ => 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
       };

  static const columnCount = 5;
  static final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);
  static final _shortKana = RegExp(r'^[ぁ-ゖァ-ヺーゝゞヽヾ]{1,8}$');
  static final _katakana = RegExp(r'^[ァ-ヺーヽヾ]+$');
  static const _katakanaTiles = 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン';

  final ReviewSession session;
  final Random random;
  final String studyLanguage;
  final String _alphabet;
  HangulSpelling? _hangul;
  String? kanaReading;
  String? get hangulPreview => _hangul?.completedAt(collected);
  String get _tileAlphabet {
    if (_hangul != null) return hangulTileAlphabet;
    if (studyLanguage == 'ja' && _katakana.hasMatch(kanaReading ?? answer)) {
      return _katakanaTiles;
    }
    return _alphabet;
  }

  int? _hintsRemaining;
  int? get hintsRemaining => _hintsRemaining;

  ReviewItem? item;
  String answer = '';
  List<String> slots = const [];
  Set<int> separators = const {};
  int collected = 0;
  int? hintedColumn;
  String? missedLetter;
  int correctCount = 0;
  bool solved = false;

  int _hintCount = 0;
  bool _hintedAtPosition = false;
  String? _firstWrong;
  final List<List<String>> stacks = [];

  void advance() {
    item = session.nextItem();
    final word = item?.word;
    if (word == null) return;
    answer = uppercaseWordLetters(word.text);
    _hangul = studyLanguage == 'ko' ? HangulSpelling.forWord(answer) : null;
    final reading = word.reading;
    kanaReading =
        studyLanguage == 'ja' && reading != null && _shortKana.hasMatch(reading)
            ? reading
            : null;
    slots =
        _hangul?.tiles ??
        (kanaReading ?? answer).characters.toList(growable: false);
    separators = {
      for (final (i, slot) in slots.indexed)
        if (!_letterOrDigit.hasMatch(slot)) i,
    };
    // Symbol-only legacy words can still be played as written.
    if (separators.length == slots.length) separators = {};
    collected = 0;
    _skipSeparators();
    solved = false;
    missedLetter = null;
    hintedColumn = null;
    _hintCount = 0;
    _hintedAtPosition = false;
    _firstWrong = null;

    final letters =
        {
            for (final (i, slot) in slots.indexed)
              if (!separators.contains(i)) slot,
          }.toList()
          ..shuffle(random);
    final pool = [...letters, ..._tileAlphabet.split('')]..shuffle(random);
    stacks
      ..clear()
      ..addAll(List.generate(columnCount, (_) => [pool.removeLast()]));

    for (final column in List.generate(columnCount, (i) => i)
      ..shuffle(random)) {
      stacks[column].add(
        letters.isEmpty ? pool.removeLast() : letters.removeLast(),
      );
    }
    if (_targetColumn == -1) {
      stacks[random.nextInt(columnCount)][1] = slots[collected];
    }
  }

  int get _targetColumn => stacks.indexWhere(
    (stack) => stack.isNotEmpty && stack.last == slots[collected],
  );

  void _skipSeparators() {
    while (separators.contains(collected)) {
      collected++;
    }
  }

  int? hint() {
    final remaining = _hintsRemaining;
    if (remaining == 0) return null;
    if (remaining != null) _hintsRemaining = remaining - 1;
    if (!_hintedAtPosition) {
      _hintedAtPosition = true;
      _hintCount++;
    }
    return hintedColumn = _targetColumn;
  }

  void grab(int column, Duration elapsed) {
    final stack = stacks[column];
    final letter = stack.removeLast();
    missedLetter = null;
    hintedColumn = null;

    if (letter == slots[collected]) {
      collected++;
      _skipSeparators();
      _hintedAtPosition = false;
      if (collected == slots.length) {
        solved = true;
        final clean = _firstWrong == null;
        if (clean) correctCount++;
        _report(clean, elapsed, selectedAnswer: _firstWrong);
        return;
      }
    } else {
      missedLetter = letter;
      _firstWrong ??= slots.take(collected).join() + letter;
    }

    // Если нужной буквы нет сверху, новая капсула падает в открывшееся
    // место. Иначе достаточно открыть нижнюю капсулу или пополнить пустую стопку.
    if (_targetColumn == -1) {
      stack.add(slots[collected]);
    } else if (stack.isEmpty) {
      stack.add(_tileAlphabet[random.nextInt(_tileAlphabet.length)]);
    }
  }

  void abandon(Duration elapsed) {
    if (item == null || solved) return;
    _report(false, elapsed);
  }

  void _report(bool correct, Duration elapsed, {String? selectedAnswer}) =>
      session.report(
        ReviewOutcome.untimed(
          correct: correct,
          responseTime: elapsed,
          hintsUsed: _hintCount,
          selectedAnswer: selectedAnswer,
        ),
      );
}
