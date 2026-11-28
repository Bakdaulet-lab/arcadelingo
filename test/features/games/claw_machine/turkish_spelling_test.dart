import 'dart:math';

import 'package:arcadelingo/domain/daily_word/daily_word.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_run.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';

const _language = 'tr';
const _course = StudyCourse(
  id: 'en-tr',
  studyLanguage: _language,
  translationLanguage: 'en',
);
const _flower = Word(id: 'flower', text: 'çiçek', translation: 'flower');
const _light = Word(id: 'light', text: 'ışık', translation: 'light');
const _paper = Word(id: 'paper', text: 'kâğıt', translation: 'paper');

DailyWordRound _round(Word word) => DailyWordRound(
  selectDailyWord(
    course: _course,
    level: CefrLevel.a1,
    date: DateTime(2026, 11, 28),
    vocabulary: [word],
  )!,
);

void main() {
  test('Turkish Claw has separate I and İ tiles', () {
    final session = FakeReviewSession([
      const ReviewItem(word: _flower),
      const ReviewItem(word: _light),
    ]);
    final run = ClawMachineRun(session, Random(7), studyLanguage: _language)
      ..advance();
    expect(run.slots, ['Ç', 'İ', 'Ç', 'E', 'K']);
    for (final tile in run.slots) {
      final column = run.hint()!;
      expect(run.stacks[column].last, tile);
      run.grab(column, const Duration(seconds: 1));
    }
    expect(session.reports.single.outcome.correct, isTrue);
    run.advance();
    expect(run.slots, ['I', 'Ş', 'I', 'K']);
  });

  test('Turkish daily guesses keep dotted I and dotless I distinct', () {
    final round = _round(_light);
    expect(round.check('İŞİK'), DailyGuessError.unknownWord);
    expect(round.submit('IŞIK'), isNull);
    expect(round.status, DailyWordStatus.won);
  });

  test('Turkish daily guesses accept composed and decomposed letters', () {
    expect(_round(_flower).submit('ÇI\u0307ÇEK'), isNull);
    expect(_round(_paper).submit('KA\u0302G\u0306IT'), isNull);
    expect(_round(_paper).check('KAĞIT'), DailyGuessError.unknownWord);
  });
}
