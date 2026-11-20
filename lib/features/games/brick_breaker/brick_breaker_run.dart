import 'dart:math';
import 'dart:ui';

import 'package:arcadelingo/domain/review/review_contract.dart';

enum BrickPhase { serve, flying, bonus, feedback, finished }

class BrickBall {
  BrickBall(this.position, this.velocity);

  Offset position;
  Offset velocity;
}

class ArcadeBrick {
  ArcadeBrick(this.bounds, this.row);

  final Rect bounds;
  final int row;
  bool gold = false;
}

typedef BrickImpact = ({ArcadeBrick brick, Duration time});

/// Simulates the field in fixed logical coordinates. A bonus retains its
/// pending review item until a catch, including across a missed drop.
class BrickBreakerRun {
  BrickBreakerRun(this.session, this._random, {this.challenge = false}) {
    lives = lifeLimit;
    if (session.isFinished) {
      phase = BrickPhase.finished;
    } else {
      _buildField();
      _serve();
    }
  }

  static const width = 360.0;
  static const height = 392.0;
  static const paddleY = 362.0;
  static const paddleHalfWidth = 38.0;
  static const ballRadius = 5.0;
  static const startingLives = 3;
  static const impactLifetime = Duration(milliseconds: 320);
  static const _step = Duration(microseconds: 8333);
  static const _seconds = 0.008333;
  static const _baseReadingTime = Duration(milliseconds: 850);
  static const _fallTime = Duration(milliseconds: 2600);
  static const _feedbackTime = Duration(milliseconds: 850);
  static const _dropStart = 138.0;
  static const _layouts = [
    ['.######.', '########', '########', '.##..##.', '...##...'],
    ['########', '..####..', '###..###', '.##..##.', '...##...'],
    ['##....##', '.##..##.', '..####..', '.######.', '#..##..#'],
    ['########', '##....##', '#.####.#', '#.#..#.#', '##....##'],
    ['..####..', '.##..##.', '##....##', '.##..##.', '..####..'],
    ['##..##..', '.##..##.', '..##..##', '.##..##.', '##..##..'],
  ];

  final ReviewSession session;
  final Random _random;
  final bool challenge;
  final bricks = <ArcadeBrick>[];
  final balls = <BrickBall>[];
  final impacts = <BrickImpact>[];
  List<String> choices = const [];
  ReviewItem? item;
  String? lastAnswer;
  bool missedDrop = false;
  BrickPhase phase = BrickPhase.serve;
  double paddle = width / 2;
  late int lives;
  int score = 0;
  int field = 1;
  int correctCount = 0;
  int bestCombo = 0;
  int _combo = 0;
  int _parkedBalls = 1;
  Duration _phaseTime = Duration.zero;
  Duration _answerTime = Duration.zero;
  Duration _remainder = Duration.zero;
  Duration _clock = Duration.zero;
  Duration _readingTime = _baseReadingTime;

  bool get caughtCorrect =>
      lastAnswer != null && lastAnswer == item?.word.translation;

  int get lifeLimit => challenge ? 1 : startingLives;

  double get dropY {
    final progress =
        (_phaseTime - _readingTime).inMicroseconds / _fallTime.inMicroseconds;
    return _dropStart + (paddleY - _dropStart) * progress.clamp(0, 1);
  }

  double impactProgress(BrickImpact impact) =>
      (_clock - impact.time).inMicroseconds / impactLifetime.inMicroseconds;

  double get laneSpacing => min(96.0, width / max(1, choices.length));

  double laneCenter(int index) =>
      width / 2 + (index - (choices.length - 1) / 2) * laneSpacing;

  int? get catchLane {
    if (choices.isEmpty) return null;
    final index = ((paddle - laneCenter(0)) / laneSpacing).round().clamp(
      0,
      choices.length - 1,
    );
    return (laneCenter(index) - paddle).abs() <= paddleHalfWidth ? index : null;
  }

  void movePaddle(double x) {
    paddle = x.clamp(paddleHalfWidth, width - paddleHalfWidth);
    if (phase == BrickPhase.serve) _parkBalls();
  }

  void launch() {
    if (phase != BrickPhase.serve) return;
    _changePhase(BrickPhase.flying);
  }

  void advance(Duration elapsed) {
    _remainder += elapsed;
    while (_remainder >= _step && _isMoving) {
      _remainder -= _step;
      _phaseTime += _step;
      _clock += _step;
      switch (phase) {
        case BrickPhase.flying:
          _fly();
        case BrickPhase.bonus:
          _drop();
        case BrickPhase.feedback:
          if (_phaseTime >= _feedbackTime) {
            final count = caughtCorrect ? 3 : _parkedBalls;
            item = null;
            if (session.isFinished) {
              _changePhase(BrickPhase.finished);
            } else {
              _serve(count);
            }
          }
        case BrickPhase.serve || BrickPhase.finished:
          break;
      }
    }
    if (!_isMoving) _remainder = Duration.zero;
    impacts.removeWhere((hit) => _clock - hit.time >= impactLifetime);
  }

  bool get _isMoving => switch (phase) {
    BrickPhase.flying || BrickPhase.bonus || BrickPhase.feedback => true,
    BrickPhase.serve || BrickPhase.finished => false,
  };

  void abandon() {
    if (item != null && phase != BrickPhase.feedback) {
      session.report(
        ReviewOutcome.untimed(correct: false, responseTime: _answerTime),
      );
    }
    item = null;
    _changePhase(BrickPhase.finished);
  }

  void _changePhase(BrickPhase next) {
    phase = next;
    _phaseTime = Duration.zero;
  }

  void _buildField() {
    final rows = _layouts[(field - 1) % _layouts.length];
    bricks.clear();
    for (final (row, layout) in rows.indexed) {
      for (var column = 0; column < layout.length; column++) {
        if (layout[column] == '#') {
          bricks.add(
            ArcadeBrick(
              Rect.fromLTWH(12 + column * 42, 16 + row * 17, 38, 13),
              row,
            ),
          );
        }
      }
    }
    bricks.last.gold = true;
  }

  void _serve([int count = 1]) {
    if (bricks.isEmpty) {
      field++;
      _buildField();
    }
    _parkedBalls = count;
    _parkBalls();
    _changePhase(BrickPhase.serve);
  }

  void _parkBalls() {
    balls.clear();
    for (var i = 0; i < _parkedBalls; i++) {
      final spread = i - (_parkedBalls - 1) / 2;
      balls.add(
        BrickBall(
          Offset(paddle + 3 + spread * 16, paddleY - ballRadius - 1),
          Offset(spread * 116, -260),
        ),
      );
    }
  }

  void _fly() {
    for (final ball in balls) {
      final previous = ball.position;
      var next = previous + ball.velocity * _seconds;
      if (next.dx < ballRadius || next.dx > width - ballRadius) {
        next = Offset(next.dx.clamp(ballRadius, width - ballRadius), next.dy);
        ball.velocity = Offset(-ball.velocity.dx, ball.velocity.dy);
      }
      if (next.dy < ballRadius) {
        next = Offset(next.dx, ballRadius);
        ball.velocity = Offset(ball.velocity.dx, ball.velocity.dy.abs());
      }
      if (ball.velocity.dy > 0 &&
          previous.dy <= paddleY - ballRadius &&
          next.dy >= paddleY - ballRadius &&
          (next.dx - paddle).abs() <= paddleHalfWidth + ballRadius) {
        final aim = ((next.dx - paddle) / paddleHalfWidth).clamp(-1, 1);
        final aimedSpeed = aim.toDouble() * 225;
        // Даже точный удар центром немного уводит мяч из пустого столбца.
        final horizontal =
            aimedSpeed.abs() < 34
                ? (aimedSpeed < 0 ? -34.0 : 34.0)
                : aimedSpeed;
        ball.velocity = Offset(
          horizontal,
          -sqrt(280 * 280 - horizontal * horizontal),
        );
        next = Offset(next.dx, paddleY - ballRadius - .1);
      }
      ball.position = next;
      for (var i = 0; i < bricks.length; i++) {
        final brick = bricks[i];
        final box = brick.bounds.inflate(ballRadius);
        if (!box.contains(next)) continue;
        ball.velocity =
            previous.dx < box.left || previous.dx >= box.right
                ? Offset(-ball.velocity.dx, ball.velocity.dy)
                : Offset(ball.velocity.dx, -ball.velocity.dy);
        ball.position = previous;
        bricks.removeAt(i);
        impacts.add((brick: brick, time: _clock));
        score += 10;
        if (brick.gold) {
          _markNextGold(brick.bounds.center.dx);
          _openBonus();
          return;
        }
        break;
      }
    }
    balls.removeWhere((ball) => ball.position.dy > height + ballRadius);
    if (balls.isNotEmpty) return;
    lives--;
    if (lives == 0) {
      abandon();
    } else {
      _serve();
    }
  }

  void _markNextGold(double previousX) {
    if (bricks.isEmpty) return;
    // Кирпичи хранятся строками сверху вниз. Последний в каждом столбце
    // открыт со стороны платформы.
    final exposed =
        {
          for (final brick in bricks) brick.bounds.center.dx: brick,
        }.values.toList();
    final distant =
        exposed
            .where((brick) => (brick.bounds.center.dx - previousX).abs() >= 84)
            .toList();
    final options = distant.isEmpty ? exposed : distant;
    options[_random.nextInt(options.length)].gold = true;
  }

  void _openBonus() {
    if (item == null) {
      item = session.nextItem();
      _answerTime = Duration.zero;
    }
    final current = item;
    if (current == null) {
      _changePhase(BrickPhase.finished);
      return;
    }
    _parkedBalls = balls.length;
    final correct = current.word.translation;
    final distractors =
        current.distractors
            .where((text) => text.trim().isNotEmpty && text != correct)
            .toSet()
            .toList()
          ..shuffle(_random);
    choices = [correct, ...distractors.take(2)]..shuffle(_random);
    final longestLabel = [
      current.word.text,
      ...choices,
    ].map((text) => text.runes.length).reduce(max);
    _readingTime =
        _baseReadingTime +
        Duration(milliseconds: ((longestLabel - 19) * 45).clamp(0, 1100));
    lastAnswer = null;
    missedDrop = false;
    _changePhase(BrickPhase.bonus);
  }

  void _drop() {
    _answerTime += _step;
    final deadline = _readingTime + _fallTime;
    if (_phaseTime < deadline) return;
    final lane = catchLane;
    if (lane == null && !challenge) {
      missedDrop = true;
      _serve(_parkedBalls);
      return;
    }
    lastAnswer = lane == null ? null : choices[lane];
    if (caughtCorrect) {
      score += 100;
      correctCount++;
      _combo++;
      bestCombo = max(_combo, bestCombo);
    } else {
      _combo = 0;
    }
    _changePhase(BrickPhase.feedback);
    session.report(
      lane == null
          ? ReviewOutcome(
            correct: false,
            responseTime: deadline,
            timeLimit: deadline,
            timedOut: true,
          )
          : ReviewOutcome.untimed(
            correct: caughtCorrect,
            responseTime: _answerTime,
            selectedAnswer: lastAnswer,
          ),
    );
  }
}
