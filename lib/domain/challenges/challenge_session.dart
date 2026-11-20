import 'dart:math';

import '../review/review_contract.dart';

enum ArcadeChallenge {
  sprint(null),
  streak(15),
  claw(3),
  brick(3);

  const ArcadeChallenge(this.wordLimit);
  final int? wordLimit;
}

/// Independent practice from one deck and level, available even after the
/// daily review queue is complete. A timed sprint ends in the game itself.
class ChallengeSession implements ReviewSession {
  ChallengeSession({
    required Iterable<ReviewItem> items,
    required CefrLevel level,
    required Random random,
    required int? limit,
  }) : assert(limit == null || limit > 0),
       _pool = items.where((item) => item.word.level == level).toList(),
       _random = random,
       _limit = limit {
    _pool.shuffle(_random);
  }

  final List<ReviewItem> _pool;
  final Random _random;
  final int? _limit;
  int _index = 0;
  int _answered = 0;
  bool _pending = false;

  @override
  int get answered => _answered;

  @override
  int get total => _pool.isEmpty ? 0 : _limit ?? _pool.length;

  @override
  bool get isFinished => !_pending && (_pool.isEmpty || _answered == _limit);

  @override
  ReviewItem? nextItem() {
    if (_pending) throw StateError('Report the current challenge word first');
    if (isFinished) return null;
    if (_index == _pool.length) {
      final previous = _pool.last;
      _pool.shuffle(_random);
      if (_pool.length > 1 && identical(_pool.first, previous)) {
        final replacement = 1 + _random.nextInt(_pool.length - 1);
        _pool[0] = _pool[replacement];
        _pool[replacement] = previous;
      }
      _index = 0;
    }
    _pending = true;
    return _pool[_index++];
  }

  @override
  void report(ReviewOutcome outcome) {
    if (!_pending) throw StateError('No challenge word is awaiting an answer');
    _pending = false;
    _answered++;
  }
}
