import 'package:arcadelingo/domain/learning/confused_words.dart';
import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:flutter_test/flutter_test.dart';

const _bring = Word(id: 'bring', text: 'traer', translation: 'приносить');
const _take = Word(id: 'take', text: 'tomar', translation: 'брать');
const _run = Word(id: 'custom:run', text: 'correr', translation: 'бегать');
const _deck = [_bring, _take, _run];

AnswerRecord _answer(
  Word word,
  String? selected, {
  int day = 1,
  String game = 'falling_words',
  int hints = 0,
  bool correct = false,
}) {
  final at = DateTime.utc(2026, 11, day);
  return AnswerRecord(
    wordId: word.id,
    at: at,
    localDay: StreakDay.of(at),
    grade: correct ? ReviewGrade.good : ReviewGrade.again,
    correct: correct,
    responseTime: const Duration(seconds: 2),
    timeLimit: Duration.zero,
    hintsUsed: hints,
    gameId: game,
    sessionId: 'practice',
    selectedAnswer: selected,
  );
}

List<ConfusedWordPair> _pairs(
  List<AnswerRecord> answers, {
  List<Word> vocabulary = _deck,
}) => findConfusedWords(
  vocabulary: vocabulary,
  level: CefrLevel.a1,
  answers: answers,
);

void main() {
  test('a second concrete mistake unlocks one pair in either direction', () {
    final first = _answer(_take, 'приносить');
    final second = _answer(_bring, '  Брать ', day: 3);
    expect(_pairs([first]), isEmpty);
    final pair = _pairs([second, first]).single;
    expect([pair.first.id, pair.second.id], ['bring', 'take']);
    expect(pair.mistakes, 2);
    expect(pair.lastMistakeAt, second.at);
  });

  test('matches the actual choice format used by each game', () {
    for (final game in [
      'falling_words',
      'ninja_slash',
      'match_three',
      'brick_breaker',
      'word_mahjong',
    ]) {
      final pick = _answer(_bring, 'брать', game: game);
      expect(_pairs([pick, pick]).single.second.id, _take.id, reason: game);
    }
    final reversed = _answer(_take, 'correr', game: 'active_recall', hints: 1);
    final apple = _answer(_run, 'tomar — брать', game: 'snake');
    final maze = _answer(_bring, 'tomar', game: 'word_maze');
    expect(_pairs([maze, maze]).single.second.id, _take.id);
    final pair = _pairs([reversed, apple]).single;
    expect({pair.first.id, pair.second.id}, {_take.id, _run.id});
  });

  test('ignores incomplete, unassisted and unidentifiable mistakes', () {
    final ignored = [
      _answer(_bring, null),
      _answer(_bring, ''),
      _answer(_bring, 'приносить'),
      _answer(_bring, 'брать', correct: true),
      _answer(_bring, 'брать', game: 'claw_machine'),
      _answer(_bring, 'tomar', game: 'active_recall'),
      _answer(_bring, 'tomar', game: 'snake'),
      _answer(_bring, 'tomar — бегать', game: 'snake'),
      _answer(_bring, 'tomar'),
      _answer(_bring, 'брать', game: 'active_recall', hints: 1),
      _answer(_bring, 'брать', game: 'new_game'),
      _answer(_bring, 'удалённое слово'),
    ];
    expect(_pairs([...ignored, ...ignored]), isEmpty);
  });

  test('never joins a missing target or a choice outside this level', () {
    const other = Word(
      id: 'other',
      text: 'elegir',
      translation: 'выбирать',
      level: CefrLevel.b1,
    );
    final foreignTarget = _answer(other, _take.translation);
    final foreignChoice = _answer(_take, other.translation);
    final logs = [foreignTarget, foreignChoice, foreignChoice, foreignTarget];
    expect(_pairs(logs, vocabulary: [..._deck, other]), isEmpty);
    expect(_pairs(logs), isEmpty);
  });

  test('a shared meaning or ambiguous distractor cannot nominate a pair', () {
    const synonym = Word(id: 'alias', text: 'coger', translation: 'брать');
    const overlap = Word(
      id: 'overlap',
      text: 'llevar',
      translation: 'нести; приносить',
    );
    const homograph = Word(id: 'homograph', text: 'tomar', translation: 'пить');
    final ambiguous = _answer(_bring, 'брать');
    final possibleMeaning = _answer(_bring, overlap.translation);
    final reverse = _answer(_run, 'tomar', game: 'active_recall', hints: 1);
    final logs = [ambiguous, possibleMeaning, reverse];
    expect(
      _pairs(
        [...logs, ...logs],
        vocabulary: [..._deck, synonym, overlap, homograph],
      ),
      isEmpty,
    );
  });

  test('returns frequent pairs first, then most recently confused', () {
    final bringTake = _answer(_bring, _take.translation, day: 1);
    final bringRun = _answer(_bring, _run.translation, day: 3);
    final takeRun = _answer(_take, _run.translation, day: 2);
    final pairs = _pairs([
      bringRun,
      takeRun,
      bringTake,
      bringTake,
      bringRun,
      bringTake,
      takeRun,
    ]);
    expect(pairs.map((pair) => pair.mistakes), [3, 2, 2]);
    expect(pairs.map((pair) => pair.lastMistakeAt.day), [1, 3, 2]);
  });
}
