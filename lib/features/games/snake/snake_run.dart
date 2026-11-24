import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/word_labels.dart';

enum SnakeDirection {
  up(0, -1),
  right(1, 0),
  down(0, 1),
  left(-1, 0);

  const SnakeDirection(this.dx, this.dy);

  final int dx;
  final int dy;
}

enum SnakePhase { ready, moving, paused, feedback, finished }

typedef SnakeCell = ({int x, int y});

class SnakeApple {
  const SnakeApple({required this.cell, required this.word});

  final SnakeCell cell;
  final Word word;
}

/// Runs the field one cell at a time. An apple is the only event that
/// submits a review outcome; movement and collisions leave the word pending.
class SnakeRun {
  SnakeRun(this._session, List<Word> vocabulary, this._random)
    : _vocabulary = List.unmodifiable(vocabulary) {
    _loadQuestion(opening: true);
  }

  static const size = 12;
  static const stepTime = Duration(milliseconds: 490);
  static const _initialBody = [
    (x: 5, y: 6),
    (x: 4, y: 6),
    (x: 3, y: 6),
    (x: 2, y: 6),
    (x: 2, y: 7),
    (x: 2, y: 8),
  ];
  static const _openingCells = [(x: 3, y: 2), (x: 8, y: 6), (x: 8, y: 9)];

  final BoardReviewSession _session;
  final List<Word> _vocabulary;
  final Random _random;

  List<SnakeCell> _body = _initialBody;
  List<SnakeCell> _previousBody = _initialBody;
  SnakeDirection _direction = SnakeDirection.right;
  final _turns = <SnakeDirection>[];
  SnakePhase _phase = SnakePhase.ready;
  ReviewItem? _item;
  List<SnakeApple> _apples = const [];
  Word? _selectedAnswer;
  bool _hitTail = false;
  int _score = 0;
  int _correctCount = 0;
  int _combo = 0;
  int _bestCombo = 0;

  List<SnakeCell> get body => _body;
  List<SnakeCell> get previousBody => _previousBody;
  SnakeDirection get direction => _direction;
  bool get hasQueuedTurn => _turns.isNotEmpty;
  SnakePhase get phase => _phase;
  ReviewItem? get item => _item;
  List<SnakeApple> get apples => _apples;
  Word? get selectedAnswer => _selectedAnswer;
  bool get answerCorrect =>
      _selectedAnswer != null && _selectedAnswer == _item?.word;
  bool get hitTail => _hitTail;
  int get score => _score;
  int get correctCount => _correctCount;
  int get bestCombo => _bestCombo;

  bool start() {
    if (_phase != SnakePhase.ready && _phase != SnakePhase.paused) return false;
    _phase = SnakePhase.moving;
    return true;
  }

  void pause() {
    if (_phase != SnakePhase.moving) return;
    _turns.clear();
    _phase = SnakePhase.paused;
  }

  bool steer(SnakeDirection turn) {
    if (_phase != SnakePhase.ready && _phase != SnakePhase.moving) return false;
    final last = _turns.lastOrNull ?? _direction;
    if (turn == last) return _phase == SnakePhase.ready && _turns.isEmpty;
    if (_turns.length == 2 || (turn.dx == -last.dx && turn.dy == -last.dy)) {
      return false;
    }
    _turns.add(turn);
    return true;
  }

  void step(Duration elapsed) {
    if (_phase != SnakePhase.moving) return;
    final heading = hasQueuedTurn ? _turns.removeAt(0) : _direction;
    final head = _body.first;
    final nextCell = (
      x: (head.x + heading.dx) % size,
      y: (head.y + heading.dy) % size,
    );
    final apple = _apples.where((apple) => apple.cell == nextCell).firstOrNull;
    final grows = apple != null && apple.word == _item?.word;
    // On an ordinary move the last cell is freed by the same step.
    final occupied = grows ? _body : _body.take(_body.length - 1);
    if (occupied.contains(nextCell)) {
      _previousBody = _body;
      _hitTail = true;
      _phase = SnakePhase.finished;
      return;
    }

    _direction = heading;
    _previousBody = _body;
    _body = List.unmodifiable([nextCell, ...occupied]);
    if (apple == null) return;
    _eat(apple, elapsed);
  }

  void _eat(SnakeApple apple, Duration elapsed) {
    _turns.clear();
    final question = _item!;
    _selectedAnswer = apple.word;
    _apples = List.unmodifiable(_apples.where((entry) => entry != apple));
    _phase = SnakePhase.feedback;
    if (answerCorrect) {
      _score += 100;
      _correctCount++;
      _combo++;
      _bestCombo = max(_bestCombo, _combo);
    } else {
      _combo = 0;
    }

    _session.reportPair(
      question,
      ReviewOutcome.untimed(
        correct: answerCorrect,
        responseTime: elapsed,
        selectedAnswer:
            answerCorrect
                ? apple.word.text
                : '${apple.word.text} — ${apple.word.translation}',
      ),
    );
  }

  void next() {
    if (_phase != SnakePhase.feedback) return;
    _previousBody = _body;
    _loadQuestion();
  }

  void _loadQuestion({bool opening = false}) {
    final question = _session.remainingItems.firstOrNull;
    _selectedAnswer = null;
    final available = opening ? List.of(_openingCells) : _spreadCells();
    if (question == null || available.isEmpty) {
      _item = null;
      _apples = const [];
      _phase = SnakePhase.finished;
      return;
    }

    _item = question;
    final correctCell = available.removeAt(_random.nextInt(available.length));
    final distractors = _chooseDistractors(question).take(available.length);
    _apples = List.unmodifiable([
      SnakeApple(cell: correctCell, word: question.word),
      for (final (index, word) in distractors.indexed)
        SnakeApple(cell: available[index], word: word),
    ]);
    _phase = SnakePhase.ready;
  }

  List<SnakeCell> _spreadCells() {
    final occupied = _body.toSet();
    final rows = [2, 4, 7, 9]..shuffle(_random);
    final positions = <SnakeCell>[];
    for (final y in rows) {
      final row = [
        for (var x = 2; x <= size - 3; x++)
          if (!occupied.contains((x: x, y: y))) (x: x, y: y),
      ];
      if (row.isNotEmpty) positions.add(row[_random.nextInt(row.length)]);
      if (positions.length == 3) return positions;
    }
    // A long tail can cover a whole preferred row. Keep away from corners
    // where a word label needs room, using the nearest free interior rows.
    for (final y in [1, 3, 5, 6, 8, 10]) {
      for (var x = 2; x <= size - 3; x++) {
        final cell = (x: x, y: y);
        if (occupied.contains(cell)) continue;
        positions.add(cell);
        break;
      }
      if (positions.length == 3) break;
    }
    return positions;
  }

  Iterable<Word> _chooseDistractors(ReviewItem question) sync* {
    final word = question.word;
    final translations = translationMeanings(word.translation);
    final labels = {normalizedWordLabel(word.text)};
    final curated = question.distractors.map(normalizedWordLabel).toSet();
    final preferred = <Word>[];
    final matchingPartOfSpeech = <Word>[];
    final others = <Word>[];

    for (final candidate in _vocabulary) {
      if (candidate.level != word.level) continue;
      if (translationMeanings(
        candidate.translation,
      ).any(translations.contains)) {
        // The apple only shows the spelling, even if another personal or
        // course card records a different meaning for the same spelling.
        labels.add(normalizedWordLabel(candidate.text));
        continue;
      }
      final normalizedTranslation = normalizedWordLabel(candidate.translation);
      if (curated.contains(normalizedTranslation)) {
        preferred.add(candidate);
      } else if (word.partOfSpeech != null &&
          word.partOfSpeech == candidate.partOfSpeech) {
        matchingPartOfSpeech.add(candidate);
      } else {
        others.add(candidate);
      }
    }

    for (final pool in [preferred, matchingPartOfSpeech, others]) {
      pool.shuffle(_random);
      for (final candidate in pool) {
        if (labels.add(normalizedWordLabel(candidate.text))) yield candidate;
      }
    }
  }
}
