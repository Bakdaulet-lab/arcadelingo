import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/word_choices.dart';

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
  SnakeRun(
    this._session,
    List<Word> vocabulary,
    this._random, {
    this.continuous = false,
  }) : _vocabulary = List.unmodifiable(vocabulary) {
    _loadQuestion(opening: true);
  }

  static const size = 16;
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
  static const _continuousOpening = [
    (x: 3, y: 2),
    (x: 8, y: 6),
    (x: 12, y: 12),
  ];
  static const _initialRocks = {
    (x: 7, y: 3),
    (x: 8, y: 3),
    (x: 8, y: 4),
    (x: 11, y: 2),
    (x: 12, y: 2),
    (x: 13, y: 2),
    (x: 11, y: 3),
    (x: 10, y: 7),
    (x: 11, y: 7),
    (x: 12, y: 7),
    (x: 12, y: 8),
    (x: 6, y: 12),
    (x: 7, y: 12),
    (x: 8, y: 12),
    (x: 8, y: 13),
    (x: 1, y: 11),
    (x: 1, y: 12),
    (x: 2, y: 12),
  };
  static const _formations = [
    [(x: 2, y: 3), (x: 2, y: 4), (x: 3, y: 4)],
    [(x: 9, y: 10), (x: 10, y: 10), (x: 10, y: 11)],
    [(x: 13, y: 11), (x: 13, y: 12), (x: 13, y: 13)],
    [(x: 4, y: 8), (x: 4, y: 9), (x: 3, y: 9)],
    [(x: 5, y: 14), (x: 4, y: 14), (x: 3, y: 14)],
  ];

  final BoardReviewSession _session;
  final List<Word> _vocabulary;
  final Random _random;
  final bool continuous;
  Set<SnakeCell> _rocks = _initialRocks;
  int _formationsAdded = 0;

  List<SnakeCell> _body = _initialBody;
  List<SnakeCell> _previousBody = _initialBody;
  SnakeDirection _direction = SnakeDirection.right;
  final _turns = <SnakeDirection>[];
  SnakePhase _phase = SnakePhase.ready;
  ReviewItem? _item;
  List<SnakeApple> _apples = const [];
  Word? _selectedAnswer;
  Word? _answeredWord;
  bool _hitTail = false;
  bool _hitObstacle = false;
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
  Word? get answeredWord => _answeredWord;
  bool get answerCorrect =>
      _selectedAnswer != null && _selectedAnswer == _answeredWord;
  bool get hitTail => _hitTail;
  bool get hitObstacle => _hitObstacle;
  Set<SnakeCell> get rocks => _rocks;
  Duration get pace {
    final tier = min(8, _correctCount ~/ 3);
    return Duration(
      milliseconds:
          (continuous ? 340 : stepTime.inMilliseconds) -
          (continuous ? 20 : 24) * tier,
    );
  }

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

  void finish() {
    _turns.clear();
    _phase = SnakePhase.finished;
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
    if (_rocks.contains(nextCell) || occupied.contains(nextCell)) {
      _previousBody = _body;
      _hitObstacle = _rocks.contains(nextCell);
      _hitTail = !_hitObstacle;
      finish();
      return;
    }

    _direction = heading;
    _previousBody = _body;
    _body = List.unmodifiable([nextCell, ...occupied]);
    if (apple == null) return;
    _eat(apple, elapsed);
  }

  void _eat(SnakeApple apple, Duration elapsed) {
    final question = _item!;
    _answeredWord = question.word;
    _selectedAnswer = apple.word;
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
    if (continuous) {
      _loadQuestion();
    } else {
      _turns.clear();
      _apples = List.unmodifiable(_apples.where((entry) => entry != apple));
      _phase = SnakePhase.feedback;
    }
  }

  void next() {
    if (_phase != SnakePhase.feedback) return;
    _previousBody = _body;
    _selectedAnswer = null;
    _answeredWord = null;
    _loadQuestion();
  }

  void _loadQuestion({bool opening = false}) {
    final question = _session.remainingItems.firstOrNull;
    if (question != null && !opening) _addFormation();
    final available =
        opening
            ? List.of(continuous ? _continuousOpening : _openingCells)
            : _spreadCells();
    if (question == null || available.isEmpty) {
      _item = null;
      _apples = const [];
      _phase = SnakePhase.finished;
      return;
    }

    _item = question;
    final correctCell = available.removeAt(_random.nextInt(available.length));
    final distractors = wordDistractors(
      question,
      _vocabulary,
      _random,
    ).take(available.length);
    _apples = List.unmodifiable([
      SnakeApple(cell: correctCell, word: question.word),
      for (final (index, word) in distractors.indexed)
        SnakeApple(cell: available[index], word: word),
    ]);
    _phase = continuous && !opening ? SnakePhase.moving : SnakePhase.ready;
  }

  int _distance(SnakeCell a, SnakeCell b) {
    final dx = (a.x - b.x).abs();
    final dy = (a.y - b.y).abs();
    return min(dx, size - dx) + min(dy, size - dy);
  }

  void _addFormation() {
    if (_formationsAdded >= min(_correctCount ~/ 3, _formations.length)) return;
    final safe =
        _formations
            .where(
              (formation) => formation.every(
                (cell) =>
                    !_rocks.contains(cell) &&
                    !_body.contains(cell) &&
                    _distance(cell, _body.first) >= 5,
              ),
            )
            .toList();
    if (safe.isEmpty) return;
    _rocks = Set.unmodifiable({
      ..._rocks,
      ...safe[_random.nextInt(safe.length)],
    });
    _formationsAdded++;
  }

  List<SnakeCell> _spreadCells() {
    final occupied = {..._body, ..._rocks};
    final free = [
      for (var y = 0; y < size; y++)
        for (var x = 0; x < size; x++)
          if (!occupied.contains((x: x, y: y))) (x: x, y: y),
    ]..shuffle(_random);
    final positions = <SnakeCell>[];
    // Leave steering and reading room, including around wrap-around edges.
    for (final cell in free) {
      if (cell.x == 0 ||
          cell.y == 0 ||
          cell.x == size - 1 ||
          cell.y == size - 1 ||
          _distance(cell, _body.first) < 5 ||
          positions.any((other) => _distance(cell, other) < 5)) {
        continue;
      }
      positions.add(cell);
      if (positions.length == 3) return positions;
    }
    // A nearly full board may leave fewer than three well-separated cells.
    for (final cell in free) {
      if (!positions.contains(cell)) positions.add(cell);
      if (positions.length == 3) break;
    }
    return positions;
  }
}
