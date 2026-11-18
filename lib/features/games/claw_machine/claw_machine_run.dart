import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';

/// Партия хранит только раскладку и попытку по выданному слову.
class ClawMachineRun {
  ClawMachineRun(this.session, this.random);

  static const columnCount = 5;
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  final ReviewSession session;
  final Random random;

  ReviewItem? item;
  String answer = '';
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
    answer = word.text.toUpperCase();
    collected = 0;
    solved = false;
    missedLetter = null;
    hintedColumn = null;
    _hintCount = 0;
    _hintedAtPosition = false;
    _firstWrong = null;

    final letters = answer.split('').toSet().toList()..shuffle(random);
    final pool = [...letters, ..._alphabet.split('')]..shuffle(random);
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
      stacks[random.nextInt(columnCount)][1] = answer[0];
    }
  }

  int get _targetColumn => stacks.indexWhere(
    (stack) => stack.isNotEmpty && stack.last == answer[collected],
  );

  int hint() {
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

    if (letter == answer[collected]) {
      collected++;
      _hintedAtPosition = false;
      if (collected == answer.length) {
        solved = true;
        final clean = _firstWrong == null;
        if (clean) correctCount++;
        _report(clean, elapsed, selectedAnswer: _firstWrong);
        return;
      }
    } else {
      missedLetter = letter;
      _firstWrong ??= answer.substring(0, collected) + letter;
    }

    // Если нужной буквы нет сверху, новая капсула падает в открывшееся
    // место. Иначе достаточно открыть нижнюю капсулу или пополнить пустую стопку.
    if (_targetColumn == -1) {
      stack.add(answer[collected]);
    } else if (stack.isEmpty) {
      stack.add(_alphabet[random.nextInt(_alphabet.length)]);
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
