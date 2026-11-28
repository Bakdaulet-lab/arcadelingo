import 'dart:math';

import 'package:arcadelingo/domain/review/hangul.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/word_labels.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_run.dart';
import 'package:arcadelingo/features/recall/recall_exercise.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';

const _hangul = ReviewItem(
  word: Word(id: 'hangul', text: '한글', translation: 'Korean alphabet'),
);

void main() {
  test('Hangul tiles keep letters grouped into syllables', () {
    expect(HangulSpelling.forWord('한글')?.tiles, [
      'ㅎ',
      'ㅏ',
      'ㄴ',
      ' ',
      'ㄱ',
      'ㅡ',
      'ㄹ',
    ]);
    expect(HangulSpelling.forWord('값')?.tiles, ['ㄱ', 'ㅏ', 'ㅄ']);
    expect(HangulSpelling.forWord('서로 마음을 나누다'), isNull);
    expect(normalizedCourseSpelling('한글'), '한글');
    expect(normalizedCourseSpelling('한'), '한');
  });

  test('Claw builds Hangul and shows each completed syllable', () {
    final session = FakeReviewSession([_hangul]);
    final run = ClawMachineRun(session, Random(7), studyLanguage: 'ko')
      ..advance();
    expect(run.hangulPreview, '');
    for (final (index, letter) in 'ㅎㅏㄴㄱㅡㄹ'.split('').indexed) {
      final column = run.hint()!;
      expect(run.stacks[column].last, letter);
      run.grab(column, Duration(milliseconds: (index + 1) * 80));
      if (index == 2) expect(run.hangulPreview, '한');
    }
    expect(run.solved, isTrue);
    expect(run.hangulPreview, '한글');
    expect(run.answer, '한글');
    expect(session.reports.single.outcome.correct, isTrue);
  });

  test('recall accepts the composed word from selected Hangul letters', () {
    final exercise = RecallExercise(
      item: _hangul,
      vocabulary: [_hangul.word],
      random: Random(7),
    );
    for (final tile in 'ㅎㅏㄴㄱㅡㄹ'.split('')) {
      final index = exercise.tiles.indexOf(tile);
      exercise.selectTile(index);
    }
    expect(exercise.correct, isTrue);
    expect(exercise.answerText, '한글');
  });
}
