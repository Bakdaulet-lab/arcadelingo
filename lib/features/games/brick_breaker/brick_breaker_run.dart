import 'dart:math';
import 'dart:ui';

import 'package:arcadelingo/domain/review/review_contract.dart';

enum BrickPhase { serve, flying, bonus, feedback, finished }

class BrickBall {
  BrickBall(this.position, this.velocity) : _previous = position;

  Offset _previous;
  Offset position;
  Offset velocity;
}

class ArcadeBrick {
  ArcadeBrick(this.bounds, this.row);

  final Rect bounds;
  late final Rect collisionBounds = bounds.inflate(BrickBreakerRun.ballRadius);
  final int row;
  bool gold = false;
}

typedef BrickImpact = ({ArcadeBrick brick, Duration time});
typedef _BallHit = ({double time, bool side, bool paddle, ArcadeBrick? brick});

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
  static const dropStart = 138.0;
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
  ({Offset point, Duration time})? paddleContact;
  double? _caughtX;
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

  Duration get _feedbackTime {
    if (caughtCorrect) return const Duration(milliseconds: 850);
    final length = item?.word.translation.runes.length ?? 0;
    return Duration(milliseconds: 1200 + min(2100, 28 * length));
  }

  double get dropY {
    final progress =
        (_phaseTime + _remainder - _readingTime).inMicroseconds /
        _fallTime.inMicroseconds;
    final t = progress.clamp(0.0, 1.0);
    final eased = t * t * (3 - 2 * t);
    return dropStart + (paddleY - dropStart) * eased;
  }

  /// Субкадровое положение между двумя уже проверенными физикой точками.
  Offset displayedBallPosition(BrickBall ball) =>
      phase == BrickPhase.flying
          ? Offset.lerp(
            ball._previous,
            ball.position,
            _remainder.inMicroseconds / _step.inMicroseconds,
          )!
          : ball.position;

  double impactProgress(BrickImpact impact) =>
      (_clock + _remainder - impact.time).inMicroseconds /
      impactLifetime.inMicroseconds;

  double? get paddleContactProgress {
    final hit = paddleContact;
    if (hit == null || phase != BrickPhase.flying) return null;
    final progress = (_clock + _remainder - hit.time).inMicroseconds / 230000;
    return progress < 1 ? progress : null;
  }

  double get catchProgress =>
      ((_phaseTime + _remainder).inMicroseconds / 500000).clamp(0.0, 1.0);

  double? get caughtX => phase == BrickPhase.feedback ? _caughtX : null;

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
    final next = x.clamp(paddleHalfWidth, width - paddleHalfWidth);
    if (paddle == next) return;
    paddle = next;
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
    paddleContact = null;
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
      ball._previous = ball.position;
      var remaining = _seconds;
      // A tick travels at most three world units. A corner can still produce
      // two contacts; continue with the unused time after each one.
      for (var contacts = 0; contacts < 4 && remaining > 0; contacts++) {
        final hit = _nextHit(ball, remaining);
        if (hit == null) break;
        ball.position += ball.velocity * hit.time;
        remaining -= hit.time;
        if (hit.paddle) {
          paddleContact = (
            point: Offset(ball.position.dx, paddleY),
            time: _clock,
          );
          final aim = ((ball.position.dx - paddle) / paddleHalfWidth).clamp(
            -1,
            1,
          );
          final aimedSpeed = aim.toDouble() * 225;
          // Leave even a perfectly centred shot a way out of an empty column.
          final dx =
              aimedSpeed.abs() < 34
                  ? (aimedSpeed < 0 ? -34.0 : 34.0)
                  : aimedSpeed;
          ball.velocity = Offset(dx, -sqrt(280 * 280 - dx * dx));
        } else {
          ball.velocity =
              hit.side
                  ? Offset(-ball.velocity.dx, ball.velocity.dy)
                  : Offset(ball.velocity.dx, -ball.velocity.dy);
        }
        final brick = hit.brick;
        if (brick == null) continue;
        bricks.remove(brick);
        impacts.add((brick: brick, time: _clock));
        score += 10;
        if (brick.gold) {
          _markNextGold(brick.bounds.center.dx);
          _openBonus();
          return;
        }
      }
      ball.position += ball.velocity * remaining;
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

  _BallHit? _nextHit(BrickBall ball, double remaining) {
    final p = ball.position;
    final v = ball.velocity;
    _BallHit? hit;
    if (v.dx != 0) {
      final wall = v.dx < 0 ? ballRadius : width - ballRadius;
      final time = (wall - p.dx) / v.dx;
      if (time >= 0 && time <= remaining) {
        hit = (time: time, side: true, paddle: false, brick: null);
        remaining = time;
      }
    }
    if (v.dy != 0) {
      final descending = v.dy > 0;
      final edge = descending ? paddleY - ballRadius : ballRadius;
      final time = (edge - p.dy) / v.dy;
      if (time >= 0 && time <= remaining) {
        final x = p.dx + v.dx * time;
        if (!descending || (x - paddle).abs() <= paddleHalfWidth + ballRadius) {
          hit = (time: time, side: false, paddle: descending, brick: null);
          remaining = time;
        }
      }
    }
    final end = p + v * remaining;
    // The bricks are ordered by row. Most ticks are in open space.
    if (bricks.isEmpty ||
        min(p.dy, end.dy) > bricks.last.collisionBounds.bottom) {
      return hit;
    }
    for (final brick in bricks) {
      final box = brick.collisionBounds;
      if (max(p.dx, end.dx) < box.left ||
          min(p.dx, end.dx) > box.right ||
          max(p.dy, end.dy) < box.top ||
          min(p.dy, end.dy) > box.bottom) {
        continue;
      }
      // Intersect the swept centre with the brick expanded by the ball radius.
      final xEnter =
          v.dx == 0
              ? double.negativeInfinity
              : ((v.dx > 0 ? box.left : box.right) - p.dx) / v.dx;
      final yEnter =
          v.dy == 0
              ? double.negativeInfinity
              : ((v.dy > 0 ? box.top : box.bottom) - p.dy) / v.dy;
      final time = max(xEnter, yEnter);
      if (time < 0 || time > remaining) continue;
      final xExit =
          v.dx == 0
              ? double.infinity
              : ((v.dx > 0 ? box.right : box.left) - p.dx) / v.dx;
      final yExit =
          v.dy == 0
              ? double.infinity
              : ((v.dy > 0 ? box.bottom : box.top) - p.dy) / v.dy;
      if (time > min(xExit, yExit)) continue;
      hit = (time: time, side: xEnter > yEnter, paddle: false, brick: brick);
      remaining = time;
    }
    return hit;
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
    final lengths = [
      current.word.text,
      ...choices,
    ].map((text) => text.runes.length);
    // Players scan the prompt and all the lanes before committing to a catch.
    final total = lengths.fold(0, (count, length) => count + length);
    final extra =
        max(0, lengths.reduce(max) - 19) * 25 + max(0, total - 36) * 26;
    _readingTime = _baseReadingTime + Duration(milliseconds: min(extra, 6000));
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
    _caughtX = lane == null ? null : laneCenter(lane);
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
