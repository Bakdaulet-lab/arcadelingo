import 'package:arcadelingo/domain/learning/personal_dictionary.dart';
import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:flutter_test/flutter_test.dart';

const _words = [
  Word(
    id: 'climate',
    text: 'climate',
    translation: 'климат',
    level: CefrLevel.b1,
  ),
  Word(
    id: 'journey',
    text: 'journey',
    translation: 'путешествие',
    level: CefrLevel.b1,
  ),
  Word(
    id: 'duty',
    text: 'duty',
    translation: 'обязанность',
    level: CefrLevel.b1,
  ),
  Word(id: 'sun', text: 'sun', translation: 'солнце'),
];

AnswerRecord _answer(String id, int day, {required bool correct}) {
  final at = DateTime.utc(2026, 11, day);
  return AnswerRecord(
    wordId: id,
    at: at,
    localDay: StreakDay.of(at),
    grade: correct ? ReviewGrade.good : ReviewGrade.again,
    correct: correct,
    responseTime: const Duration(seconds: 1),
    timeLimit: const Duration(seconds: 6),
    hintsUsed: 0,
    gameId: 'falling_words',
    sessionId: 'test',
  );
}

void main() {
  test('словарь соединяет журнал с актуальными словами одного уровня', () {
    final older = _answer('climate', 1, correct: true);
    final newer = _answer('climate', 4, correct: false);
    final entries = buildPersonalDictionary(
      items: _words.map((word) => ReviewItem(word: word)),
      level: CefrLevel.b1,
      answers: [
        older,
        _answer('journey', 2, correct: false),
        _answer('sun', 3, correct: false),
        newer,
        _answer('removed-word', 5, correct: false),
      ],
    );
    expect(entries.map((entry) => entry.word.id), ['climate', 'journey']);
    expect(entries.first.attempts, [newer, older]);
    expect(entries.first.mistakes, 1);
    expect(entries.first.isDifficult, isFalse);
  });

  test('трудные слова — минимум две ошибки среди пяти последних ответов', () {
    final entries = buildPersonalDictionary(
      items: _words.map((word) => ReviewItem(word: word)),
      level: CefrLevel.b1,
      answers: [
        for (var day = 1; day <= 7; day++)
          _answer('climate', day, correct: day > 2),
        _answer('journey', 5, correct: false),
        _answer('journey', 6, correct: true),
        _answer('journey', 7, correct: false),
      ],
    );
    expect(
      entries.firstWhere((entry) => entry.word.id == 'climate').isDifficult,
      isFalse,
    );
    expect(
      entries.firstWhere((entry) => entry.word.id == 'journey').isDifficult,
      isTrue,
    );
  });
}
