import 'dart:math';

import 'package:arcadelingo/domain/daily_word/daily_word.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/review/word_labels.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_run.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';

const _school = ReviewItem(
  word: Word(
    id: 'ja_school',
    text: '学校',
    reading: 'がっこう',
    translation: 'school',
  ),
);

void main() {
  test('Claw captures the kana reading and reveals the written word', () {
    final session = FakeReviewSession([_school]);
    final run = ClawMachineRun(session, Random(7), studyLanguage: 'ja')
      ..advance();
    expect(run.slots, ['が', 'っ', 'こ', 'う']);
    for (final kana in run.slots) {
      final column = run.hint()!;
      expect(run.stacks[column].last, kana);
      run.grab(column, const Duration(seconds: 1));
    }
    expect(run.solved, isTrue);
    expect(run.answer, '学校');
    expect(session.reports.single.outcome.correct, isTrue);
  });

  test('Japanese Daily Word accepts the spelling entered via IME', () {
    const course = StudyCourse(
      id: 'en-ja',
      studyLanguage: 'ja',
      translationLanguage: 'en',
    );
    final puzzle = selectDailyWord(
      course: course,
      level: CefrLevel.a1,
      date: DateTime(2026, 11, 28),
      vocabulary: [_school.word],
    );
    expect(puzzle?.length, 2);
    expect(DailyWordRound(puzzle!).submit('学校'), isNull);
    expect(normalizedCourseSpelling('か\u3099っこう'), 'がっこう');
    expect(normalizedCourseSpelling('ケ\u3099ーム'), 'ゲーム');
  });
}
