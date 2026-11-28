import '../review/review_contract.dart';
import '../review/study_course.dart';
import '../review/word_labels.dart';
import '../streak/streak.dart';

enum DailyLetterMark { exact, present, absent }

enum DailyWordStatus { playing, won, lost }

enum DailyGuessError {
  wrongLength,
  invalidLetters,
  unknownWord,
  alreadyTried,
  finished,
}

final _latinLetters = RegExp(r'^[a-záéíóúñü]+$');
final _germanLetters = RegExp(r'^[a-zäöüß]+$');
final _frenchLetters = RegExp(r'^[a-zàâæçéèêëîïôœùûüÿ]+$');
final _hanCharacters = RegExp(r'^[\u3400-\u9fff]+$');
final _hangulSyllables = RegExp(r'^[\uac00-\ud7a3]+$');
final _japaneseLetters = RegExp(r'^[ぁ-ゖァ-ヺーゝゞヽヾ々〆\u3400-\u9fff]+$');
final _arabicLetters = RegExp(r'^[\u0621-\u063a\u0641-\u064a]+$');
final _russianLetters = RegExp(r'^[а-яё]+$');
final _clueWords = RegExp(r'\p{L}+', unicode: true);

RegExp _lettersFor(StudyCourse course) => switch (course.studyLanguage) {
  'ru' => _russianLetters,
  'de' => _germanLetters,
  'fr' => _frenchLetters,
  'zh' => _hanCharacters,
  'ko' => _hangulSyllables,
  'ja' => _japaneseLetters,
  'ar' => _arabicLetters,
  _ => _latinLetters,
};

class DailyWordPuzzle {
  DailyWordPuzzle._(
    this.course,
    this.level,
    this.day,
    this.answer,
    this._allowed,
  ) : _spelling = normalizedCourseSpelling(answer.text);

  final StudyCourse course;
  final CefrLevel level;
  final StreakDay day;
  final Word answer;
  final String _spelling;
  final Set<String> _allowed;
  int get length => _spelling.length;
}

/// [vocabulary] is the full bundled catalogue of [course], before applying
/// personal decks or progress. Words from other levels can be played as
/// guesses; only [level] supplies today's answer and translation.
DailyWordPuzzle? selectDailyWord({
  required StudyCourse course,
  required CefrLevel level,
  required DateTime date,
  required Iterable<Word> vocabulary,
  String? targetId,
}) {
  final letters = _lettersFor(course);
  final (minLength, maxLength) = switch (course.studyLanguage) {
    'zh' => (2, 4),
    'ko' => (2, 5),
    'ja' => (2, 5),
    _ => (4, 7),
  };
  final clear = <String, Word>{};
  final revealing = <String, Word>{};
  final allowed = <String>{};
  Word? target;
  for (final word in vocabulary) {
    final spelling = normalizedCourseSpelling(word.text);
    if (spelling.length < minLength ||
        spelling.length > maxLength ||
        !letters.hasMatch(spelling)) {
      continue;
    }
    allowed.add(spelling);
    if (word.level != level || word.translation.trim().isEmpty) continue;
    if (targetId != null) {
      if (word.id == targetId) target = word;
      continue;
    }
    final clue = normalizedCourseSpelling(word.translation);
    final revealsWord = _clueWords
        .allMatches(clue)
        .any((m) => m[0] == spelling);
    final pool = revealsWord ? revealing : clear;
    final previous = pool[spelling];
    if (previous == null || word.id.compareTo(previous.id) < 0) {
      pool[spelling] = word;
    }
  }

  final day = StreakDay.of(date);
  if (targetId == null) {
    final pool = clear.isEmpty ? revealing : clear;
    if (pool.isEmpty) return null;
    final spellings = pool.keys.toList()..sort();
    // Shuffle the sorted cycle once per course and level. The arithmetic is
    // exact on both native and web. Adjacent days never repeat in a pool of 2+.
    const modulus = 2147483647;
    var seed = 1;
    for (final unit in (course.id + level.name).codeUnits) {
      seed = (seed * 31 + unit) % modulus;
    }
    for (var i = spellings.length - 1; i > 0; i--) {
      seed = (seed * 48271) % modulus;
      final j = seed % (i + 1);
      final previous = spellings[i];
      spellings[i] = spellings[j];
      spellings[j] = previous;
    }
    final calendarDate = DateTime.utc(day.year, day.month, day.day);
    final ordinal = calendarDate.difference(DateTime.utc(1970)).inDays;
    target = pool[spellings[ordinal % spellings.length]];
  }
  if (target == null) return null;
  return DailyWordPuzzle._(course, level, day, target, allowed);
}

class DailyWordRound {
  DailyWordRound(this.puzzle, {Iterable<String> guesses = const []}) {
    for (final saved in guesses) {
      final spelling = normalizedCourseSpelling(saved);
      // Accepted guesses remain meaningful if a later catalogue removes one.
      if (_validate(spelling, requireKnown: false) != null) {
        _validHistory = false;
        break;
      }
      _accept(spelling);
    }
  }

  static const maxAttempts = 6;
  final DailyWordPuzzle puzzle;
  final _guesses = <String>[];
  final _rows = <List<DailyLetterMark>>[];
  bool _validHistory = true;

  bool get validHistory => _validHistory;
  List<String> get guesses => List.unmodifiable(_guesses);
  List<List<DailyLetterMark>> get rows => List.unmodifiable(_rows);

  DailyWordStatus get status {
    if (_guesses.isNotEmpty && _guesses.last == puzzle._spelling) {
      return DailyWordStatus.won;
    }
    return _guesses.length == maxAttempts
        ? DailyWordStatus.lost
        : DailyWordStatus.playing;
  }

  DailyGuessError? _validate(String spelling, {required bool requireKnown}) {
    if (!_validHistory || status != DailyWordStatus.playing) {
      return DailyGuessError.finished;
    }
    if (spelling.isNotEmpty && !_lettersFor(puzzle.course).hasMatch(spelling)) {
      return DailyGuessError.invalidLetters;
    }
    if (spelling.length != puzzle.length) return DailyGuessError.wrongLength;
    if (_guesses.contains(spelling)) return DailyGuessError.alreadyTried;
    if (requireKnown && !puzzle._allowed.contains(spelling)) {
      return DailyGuessError.unknownWord;
    }
    return null;
  }

  DailyGuessError? check(String guess) =>
      _validate(normalizedCourseSpelling(guess), requireKnown: true);

  DailyGuessError? submit(String guess) {
    final spelling = normalizedCourseSpelling(guess);
    final error = _validate(spelling, requireKnown: true);
    if (error == null) _accept(spelling);
    return error;
  }

  void _accept(String spelling) {
    final marks = List.filled(puzzle.length, DailyLetterMark.absent);
    final remaining = <String, int>{};
    final answer = puzzle._spelling;
    for (var i = 0; i < answer.length; i++) {
      if (answer[i] == spelling[i]) {
        marks[i] = DailyLetterMark.exact;
      } else {
        remaining.update(answer[i], (n) => n + 1, ifAbsent: () => 1);
      }
    }
    for (var i = 0; i < spelling.length; i++) {
      if (marks[i] == DailyLetterMark.exact) continue;
      final count = remaining[spelling[i]] ?? 0;
      if (count > 0) {
        remaining[spelling[i]] = count - 1;
        marks[i] = DailyLetterMark.present;
      }
    }
    _guesses.add(spelling);
    _rows.add(List.unmodifiable(marks));
  }

  String get shareGrid {
    if (!_validHistory || status == DailyWordStatus.playing) return '';
    const tiles = {
      DailyLetterMark.exact: '🟩',
      DailyLetterMark.present: '🟨',
      DailyLetterMark.absent: '⬛',
    };
    return _rows
        .map((row) => row.map((mark) => tiles[mark]!).join())
        .join('\n');
  }
}
