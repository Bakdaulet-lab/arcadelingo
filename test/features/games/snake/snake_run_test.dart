import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/snake/snake_run.dart';
import 'package:flutter_test/flutter_test.dart';

const _key = Word(id: 'key', text: 'llave', translation: 'ключ');
const _table = Word(id: 'table', text: 'mesa', translation: 'стол');
const _clock = Word(id: 'clock', text: 'reloj', translation: 'часы');
const _door = Word(id: 'door', text: 'puerta', translation: 'дверь');

class _BoardSession implements BoardReviewSession {
  _BoardSession(Iterable<Word> words)
    : _remaining = [for (final word in words) ReviewItem(word: word)] {
    total = _remaining.length;
  }

  final List<ReviewItem> _remaining;
  final outcomes = <ReviewOutcome>[];
  final reportedWords = <Word>[];

  @override
  List<ReviewItem> get remainingItems => List.unmodifiable(_remaining);

  @override
  late final int total;

  @override
  int get answered => outcomes.length;

  @override
  bool get isFinished => _remaining.isEmpty;

  @override
  ReviewItem? nextItem() => throw StateError('The apples use the board queue');

  @override
  void report(ReviewOutcome outcome) =>
      throw StateError('The apples report through the board contract');

  @override
  void reportPair(ReviewItem item, ReviewOutcome outcome) {
    if (!_remaining.remove(item)) {
      throw StateError('This word was already reported');
    }
    reportedWords.add(item.word);
    outcomes.add(outcome);
  }
}

SnakeRun _newRun(
  _BoardSession session, {
  List<Word> vocabulary = const [_key, _table, _clock, _door],
}) => SnakeRun(session, vocabulary, _OpeningRandom());

class _OpeningRandom implements Random {
  final _later = Random(16);
  bool _opening = true;

  @override
  int nextInt(int max) {
    if (!_opening) return _later.nextInt(max);
    _opening = false;
    return 1;
  }

  @override
  bool nextBool() => _later.nextBool();

  @override
  double nextDouble() => _later.nextDouble();
}

void _pass(SnakeRun run, int ticks) {
  for (var tick = 0; tick < ticks; tick++) {
    run.step(SnakeRun.stepTime * (tick + 1));
  }
}

void main() {
  test('an alternate meaning cannot hide a valid answer on a wrong apple', () {
    const personal = Word(id: 'custom:1', text: 'lift', translation: 'поднять');
    const otherSense = Word(
      id: 'custom:2',
      text: 'raise',
      translation: 'собрать',
    );
    const alsoCorrect = Word(
      id: 'raise',
      text: ' RAISE ',
      translation: 'поднять / возвысить',
    );
    final run = _newRun(
      _BoardSession([personal]),
      vocabulary: [personal, otherSense, alsoCorrect, _door],
    );
    expect(
      run.apples.map((apple) => apple.word),
      unorderedEquals([personal, _door]),
    );
  });

  test('fresh sessions can place the correct answer at any opening apple', () {
    const vocabulary = [_key, _table, _clock];
    final correctCells = <SnakeCell>{
      for (var seed = 0; seed < 30; seed++)
        SnakeRun(
          _BoardSession([_key]),
          vocabulary,
          Random(seed),
        ).apples.singleWhere((apple) => apple.word == _key).cell,
    };
    expect(correctCells, {(x: 3, y: 2), (x: 8, y: 6), (x: 8, y: 9)});
  });

  test('opening pose and first answer match the preview', () {
    final session = _BoardSession([_key, _table]);
    final run = _newRun(session);
    expect(run.phase, SnakePhase.ready);
    expect(run.body, [
      (x: 5, y: 6),
      (x: 4, y: 6),
      (x: 3, y: 6),
      (x: 2, y: 6),
      (x: 2, y: 7),
      (x: 2, y: 8),
    ]);
    expect(run.item?.word, _key);
    final correctApple = run.apples.singleWhere((apple) => apple.word == _key);
    expect(correctApple.cell, (x: 8, y: 6));
    expect(session.answered, 0);
    _pass(run, 2);
    expect(run.body.first, (x: 5, y: 6));

    expect(run.steer(SnakeDirection.right), isTrue);
    expect(run.start(), isTrue);
    _pass(run, 3);
    expect(run.phase, SnakePhase.feedback);
    expect(run.body.first, (x: 8, y: 6));
    expect(run.previousBody.first, (x: 7, y: 6));
    expect(run.body.length, 7);
    expect(run.selectedAnswer, _key);
    expect(run.answerCorrect, isTrue);
    expect(run.score, 100);
    expect(run.correctCount, 1);
    expect(run.bestCombo, 1);
    expect(session.reportedWords, [_key]);
    expect(session.outcomes.single.correct, isTrue);
    expect(session.outcomes.single.isUntimed, isTrue);
    expect(session.outcomes.single.responseTime, SnakeRun.stepTime * 3);
    expect(session.outcomes.single.selectedAnswer, 'llave');
    expect(run.apples.map((apple) => apple.word), isNot(contains(_key)));

    _pass(run, 6);
    expect(run.body.first, (x: 8, y: 6));
    expect(session.answered, 1);
    run.next();
    expect(run.phase, SnakePhase.ready);
    expect(run.item?.word, _table);
    final appleCells = [for (final apple in run.apples) apple.cell];
    expect(appleCells.toSet(), hasLength(3));
    expect(appleCells.toSet().intersection(run.body.toSet()), isEmpty);
  });

  test('wrong apple pauses and records learning feedback without growth', () {
    final session = _BoardSession([_key]);
    final run = _newRun(session);
    final wrongApple = run.apples.singleWhere(
      (apple) => apple.cell == (x: 8, y: 9),
    );
    expect(run.steer(SnakeDirection.down), isTrue);
    expect(run.start(), isTrue);
    _pass(run, 3);
    expect(run.body.first, (x: 5, y: 9));
    expect(run.steer(SnakeDirection.right), isTrue);
    _pass(run, 3);
    expect(run.phase, SnakePhase.feedback);
    expect(run.body.length, 6);
    expect(run.score, 0);
    expect(run.selectedAnswer, wrongApple.word);
    expect(run.answerCorrect, isFalse);
    expect(session.reportedWords, [_key]);
    expect(session.outcomes.single.correct, isFalse);
    expect(
      session.outcomes.single.selectedAnswer,
      '${wrongApple.word.text} — ${wrongApple.word.translation}',
    );
    run.next();
    expect(run.phase, SnakePhase.finished);
    expect(run.hitTail, isFalse);
  });

  test('a tail collision does not report an answer to the review session', () {
    final session = _BoardSession([_key, _table]);
    final run = _newRun(session);
    run.steer(SnakeDirection.down);
    run.start();
    _pass(run, 1);
    run.steer(SnakeDirection.left);
    _pass(run, 1);
    run.steer(SnakeDirection.up);
    _pass(run, 1);
    expect(run.phase, SnakePhase.finished);
    expect(run.hitTail, isTrue);
    expect(session.answered, 0);
    expect(session.remainingItems.map((item) => item.word), [_key, _table]);
  });

  test('two turns use successive cells and reject reversals and repeats', () {
    final session = _BoardSession([_key]);
    final run = _newRun(session);
    run.start();
    expect(run.steer(SnakeDirection.left), isFalse);
    expect(run.steer(SnakeDirection.up), isTrue);
    expect(run.steer(SnakeDirection.up), isFalse);
    expect(run.steer(SnakeDirection.down), isFalse);
    expect(run.steer(SnakeDirection.left), isTrue);
    expect(run.steer(SnakeDirection.down), isFalse);
    _pass(run, 1);
    expect(run.direction, SnakeDirection.up);
    expect(run.body.first, (x: 5, y: 5));
    _pass(run, 1);
    expect(run.body.first, (x: 4, y: 5));
    _pass(run, 5);
    expect(run.body.first, (x: 11, y: 5));
    expect(run.phase, SnakePhase.moving);
    expect(session.answered, 0);
    expect(run.steer(SnakeDirection.up), isTrue);
    run.pause();
    expect(run.steer(SnakeDirection.down), isFalse);
    _pass(run, 7);
    expect(run.phase, SnakePhase.paused);
    expect(run.body.first, (x: 11, y: 5));
    expect(run.start(), isTrue);
    _pass(run, 1);
    expect(run.body.first, (x: 10, y: 5));
  });

  test('a buffered turn before an apple does not carry to the next word', () {
    final run = _newRun(_BoardSession([_key, _table]));
    run.start();
    _pass(run, 2);
    run.steer(SnakeDirection.up);
    _pass(run, 1);
    run.steer(SnakeDirection.right);
    _pass(run, 1);
    run.steer(SnakeDirection.down);
    run.steer(SnakeDirection.right);
    _pass(run, 1);
    expect(run.phase, SnakePhase.feedback);
    run.next();
    run.start();
    _pass(run, 1);
    expect(run.body.first, (x: 8, y: 7));
  });

  test(
    'choices are unique at the current level and avoid duplicate translations',
    () {
      const higherLevel = Word(
        id: 'achievement',
        text: 'logro',
        translation: 'достижение',
        level: CefrLevel.b1,
      );
      const alternative = Word(
        id: 'switch',
        text: 'interruptor',
        translation: ' КЛЮЧ ',
      );
      const duplicateLabel = Word(
        id: 'wrench',
        text: ' Llave ',
        translation: 'гаечный ключ',
      );
      final run = _newRun(
        _BoardSession([_key]),
        vocabulary: [_key, _table, higherLevel, alternative, duplicateLabel],
      );
      expect(
        run.apples.map((apple) => apple.word),
        unorderedEquals([_key, _table]),
      );
    },
  );

  test(
    'empty review queue finishes immediately without producing an apple',
    () {
      final run = _newRun(_BoardSession([]));
      expect(run.phase, SnakePhase.finished);
      expect(run.item, isNull);
      expect(run.apples, isEmpty);
      expect(run.start(), isFalse);
    },
  );
}
