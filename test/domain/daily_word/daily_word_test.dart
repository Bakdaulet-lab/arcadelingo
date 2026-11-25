import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/daily_word/daily_word.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:flutter_test/flutter_test.dart';

Word card(
  String text, {
  String? id,
  String translation = 'подсказка',
  CefrLevel level = CefrLevel.a1,
}) => Word(id: id ?? text, text: text, translation: translation, level: level);

DailyWordPuzzle? select(
  Iterable<Word> words, {
  int day = 1,
  int hour = 0,
  String? targetId,
}) => selectDailyWord(
  course: StudyCourse.englishFromRussian,
  level: CefrLevel.a1,
  date: DateTime(2026, 11, day, hour),
  vocabulary: words,
  targetId: targetId,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a full rotation uses every eligible spelling once in a stable order', () {
    final cards = [
      card('bird'), card('apple'), card('cheese'), card('bicycle'),
      card('Apple', id: 'zz-duplicate'),
      card('air'), card('blackbird'), card('get up'), card("can't"),
      card('hotel', translation: 'a hotel / inn'),
      card('uncle', translation: '  '),
      card('roads', level: CefrLevel.b1),
    ];
    final seen = <String>{};
    for (var day = 1; day <= 4; day++) {
      final own = select(cards, day: day)!;
      expect(own.answer.id, select(cards.reversed, day: day, hour: 23)!.answer.id);
      expect(seen.add(own.answer.id), isTrue);
      expect(select(cards, day: day + 1)!.answer.id, isNot(own.answer.id));
    }
    expect(seen, {'bird', 'apple', 'cheese', 'bicycle'});
    expect(select(cards, day: 5)!.answer.id, select(cards)!.answer.id);
    expect(select([card('taxi', translation: 'taxi')])!.answer.id, 'taxi');
    expect(select([card('in'), card('use up'), card('tree', level: CefrLevel.b2)]), isNull);
  });

  test('saved target is pinned by id, including after the catalogue changes', () {
    final cards = [card('hotel', translation: 'hotel'), card('bird')];
    expect(select(cards)!.answer.id, 'bird');
    expect(select(cards, targetId: 'hotel')!.answer.id, 'hotel');
    expect(select(cards, targetId: 'missing'), isNull);
    expect(select([card('bird', level: CefrLevel.a2)], targetId: 'bird'), isNull);
  });

  test('Spanish composite accents match and accent distinctions are preserved', () {
    final puzzle = selectDailyWord(
      course: StudyCourse.spanishFromRussian,
      level: CefrLevel.a1,
      date: DateTime(2026, 11, 25),
      vocabulary: [card('sen\u0303al'), card('avión'), card('güero')],
      targetId: 'sen\u0303al',
    )!;
    final round = DailyWordRound(puzzle);
    expect(puzzle.length, 5);
    expect(round.check('senal'), DailyGuessError.unknownWord);
    expect(round.check('GU\u0308ERO'), isNull);
    expect(round.submit(' AVIO\u0301N '), isNull);
    expect(round.check('avión'), DailyGuessError.alreadyTried);
    expect(round.submit('SEN\u0303AL'), isNull);
    expect(round.guesses, ['avión', 'señal']);
    expect(round.status, DailyWordStatus.won);
  });

  final vocabulary = [
    card('apple'), card('allee', level: CefrLevel.b1),
    ...['climb', 'elbow', 'fight', 'ghost', 'horse', 'ivory'].map((s) => card(s)),
  ];
  DailyWordPuzzle apple() => select(vocabulary, targetId: 'apple')!;

  test('rejects invalid guesses without spending a turn; shares only marks', () {
    final round = DailyWordRound(apple());
    expect(round.submit('aple'), DailyGuessError.wrongLength);
    expect(round.submit('a-p!e'), DailyGuessError.invalidLetters);
    expect(round.submit('zzzzz'), DailyGuessError.unknownWord);
    expect(round.guesses, isEmpty);
    expect(round.submit('ALLEE'), isNull);
    expect(round.rows.single, [
      DailyLetterMark.exact, DailyLetterMark.present, DailyLetterMark.absent,
      DailyLetterMark.absent, DailyLetterMark.exact,
    ]);
    expect(round.submit('allee'), DailyGuessError.alreadyTried);
    expect(round.shareGrid, isEmpty);
    expect(round.submit('apple'), isNull);
    expect(round.shareGrid, '🟩🟨⬛⬛🟩\n🟩🟩🟩🟩🟩');
    expect(round.submit('climb'), DailyGuessError.finished);
  });

  test('sixth turn can win; six misses finish the round including on restore', () {
    final wrong = ['climb', 'elbow', 'fight', 'ghost', 'horse', 'ivory'];
    final lost = DailyWordRound(apple(), guesses: wrong);
    expect(lost.validHistory, isTrue);
    expect(lost.status, DailyWordStatus.lost);
    expect(lost.shareGrid.split('\n'), hasLength(DailyWordRound.maxAttempts));
    expect(lost.check('apple'), DailyGuessError.finished);
    final win = DailyWordRound(apple(), guesses: wrong.take(5));
    expect(win.submit('apple'), isNull);
    expect(win.status, DailyWordStatus.won);
    expect(DailyWordRound(apple(), guesses: win.guesses).shareGrid, win.shareGrid);
  });

  test('previously accepted guesses survive a catalogue update; damaged rows fail closed', () {
    final puzzle = select([card('apple')])!;
    final old = DailyWordRound(puzzle, guesses: ['allee']);
    expect(old.validHistory, isTrue);
    expect(old.rows.single, DailyWordRound(apple(), guesses: ['allee']).rows.single);
    for (final bad in [
      ['short', 'SHORT'], ['too-long'], ['apple', 'allee'], ['книга'],
    ]) {
      final round = DailyWordRound(puzzle, guesses: bad);
      expect(round.validHistory, isFalse);
      expect(round.check('apple'), DailyGuessError.finished);
      expect(round.shareGrid, isEmpty);
    }
  });

  test('all 17 real course and level combinations have playable daily words', () async {
    final courses = [
      (StudyCourse.englishFromRussian, loadWordsSeed, CefrLevel.values),
      (StudyCourse.spanishFromRussian, loadSpanishSeed, CefrLevel.values.take(5)),
      (StudyCourse.englishFromSpanish, loadEnglishA1FromSpanishSeed, [CefrLevel.a1]),
      (StudyCourse.spanishFromEnglish, loadSpanishFromEnglishSeed, CefrLevel.values.take(5)),
    ];
    for (final (course, load, levels) in courses) {
      final seed = (await load() as Ok<List<ReviewItem>>).value;
      final words = seed.map((item) => item.word).toList();
      for (final level in levels) {
        final puzzle = selectDailyWord(
          course: course, level: level, date: DateTime(2026, 11, 25),
          vocabulary: words,
        )!;
        expect(puzzle.answer.level, level);
        expect(seed.any((item) => item.word == puzzle.answer), isTrue);
        final round = DailyWordRound(puzzle);
        expect(round.submit(puzzle.answer.text), isNull);
        expect(round.status, DailyWordStatus.won);
      }
    }
  });
}
