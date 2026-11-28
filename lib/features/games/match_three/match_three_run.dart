import 'dart:collection';
import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';

enum MatchGem { aqua, rose, amber, plum, mint, sapphire, charged }

enum MatchChargeKind { row, cross }

enum MatchThreePhase {
  ready,
  swapping,
  reverting,
  clearing,
  falling,
  question,
  feedback,
  finished,
}

typedef GemTravel = ({int rows, int columns});

/// A move settles all cascades before offering its single charged gem.
/// The review session supplies translations and owns their learning outcomes.
class MatchThreeRun {
  MatchThreeRun(this.session, this._random)
    : phase =
          session.isFinished
              ? MatchThreePhase.finished
              : MatchThreePhase.ready {
    _openBoard();
  }

  static const size = 6;
  static const moveLimit = 18;
  static const chargeGoal = 3;
  static const guideFrom = 9;
  static const guideTo = 15;
  static const _colors = [
    MatchGem.aqua,
    MatchGem.rose,
    MatchGem.amber,
    MatchGem.plum,
    MatchGem.mint,
    MatchGem.sapphire,
  ];
  final ReviewSession session;
  final Random _random;
  final _cells = List<MatchGem?>.filled(size * size, null);
  late final List<MatchGem?> cells = UnmodifiableListView(_cells);
  MatchThreePhase phase;
  int moves = moveLimit;
  int score = 0;
  int correctCount = 0;
  int bestCombo = 0;
  int chargeProgress = 0;
  MatchChargeKind? chargeKind;
  int cascadeDepth = 0;
  int? blastOrigin;

  int get cascadeMultiplier => cascadeDepth.clamp(1, 3);
  int _combo = 0;
  ReviewItem? item;
  List<String> choices = const [];
  String? selectedAnswer;
  Set<int> clearing = const {};
  Map<int, GemTravel> travel = const {};
  bool invalidMove = false;
  bool rowCleared = false;
  int _from = 0;
  int _to = 0;
  int? _createCharge;
  bool _canCharge = false;
  bool _scoreClear = true;

  bool get isAnimating => switch (phase) {
    MatchThreePhase.swapping ||
    MatchThreePhase.reverting ||
    MatchThreePhase.clearing ||
    MatchThreePhase.falling ||
    MatchThreePhase.feedback => true,
    _ => false,
  };

  bool get answerCorrect =>
      selectedAnswer != null && selectedAnswer == item?.word.translation;
  bool get showGuide =>
      moves == moveLimit && !invalidMove && phase == MatchThreePhase.ready;

  static int row(int index) => index ~/ size;
  static int column(int index) => index % size;

  static bool adjacent(int a, int b) =>
      a >= 0 &&
      b >= 0 &&
      a < size * size &&
      b < size * size &&
      (row(a) - row(b)).abs() + (column(a) - column(b)).abs() == 1;

  bool swap(int from, int to) {
    if (phase != MatchThreePhase.ready || !adjacent(from, to)) return false;
    if (_cells[from] == _cells[to]) return false;
    _from = from;
    _to = to;
    _canCharge = true;
    cascadeDepth = 0;
    invalidMove = false;
    rowCleared = false;
    _swapCells(from, to);
    phase = MatchThreePhase.swapping;
    return true;
  }

  bool answer(String value, Duration elapsed) {
    if (phase != MatchThreePhase.question || !choices.contains(value)) {
      return false;
    }
    selectedAnswer = value;
    phase = MatchThreePhase.feedback;
    if (answerCorrect) {
      correctCount++;
      bestCombo = max(bestCombo, ++_combo);
    } else {
      _combo = 0;
    }
    session.report(
      ReviewOutcome.untimed(
        correct: answerCorrect,
        responseTime: elapsed,
        selectedAnswer: value,
      ),
    );
    return true;
  }

  void abandon([Duration elapsed = Duration.zero]) {
    if (phase == MatchThreePhase.question) {
      session.report(
        ReviewOutcome.untimed(correct: false, responseTime: elapsed),
      );
    }
    item = null;
    phase = MatchThreePhase.finished;
  }

  void advance() {
    switch (phase) {
      case MatchThreePhase.swapping:
        final lines = _matches();
        if (lines.isEmpty) {
          _swapCells(_from, _to);
          phase = MatchThreePhase.reverting;
        } else {
          moves--;
          _prepareMatches(lines);
        }
      case MatchThreePhase.reverting:
        invalidMove = true;
        travel = const {};
        phase = MatchThreePhase.ready;
      case MatchThreePhase.clearing:
        if (_scoreClear) {
          final multiplier = blastOrigin == null ? cascadeMultiplier : 1;
          score += 10 * clearing.length * multiplier;
        }
        for (final index in clearing) {
          if (_cells[index] == MatchGem.charged) {
            chargeKind = null;
            chargeProgress = 0;
          }
          _cells[index] = index == _createCharge ? MatchGem.charged : null;
        }
        blastOrigin = null;
        _createCharge = null;
        clearing = const {};
        _dropGems();
      case MatchThreePhase.falling:
        final lines = _matches();
        if (lines.isEmpty) {
          _settle();
        } else {
          _prepareMatches(lines);
        }
      case MatchThreePhase.feedback:
        final index = _cells.indexOf(MatchGem.charged);
        final start = row(index) * size;
        cascadeDepth = 0;
        rowCleared = answerCorrect;
        if (rowCleared) {
          blastOrigin = index;
          score += 60;
          clearing = {
            for (var i = 0; i < size; i++) start + i,
            if (chargeKind == MatchChargeKind.cross)
              for (var i = 0; i < size; i++) column(index) + i * size,
          };
        } else {
          clearing = {index};
        }
        _scoreClear = rowCleared;
        item = null;
        phase = MatchThreePhase.clearing;
      case MatchThreePhase.ready ||
          MatchThreePhase.question ||
          MatchThreePhase.finished:
        break;
    }
  }

  void _swapCells(int a, int b) {
    _exchange(a, b);
    travel = {
      a: (rows: row(b) - row(a), columns: column(b) - column(a)),
      b: (rows: row(a) - row(b), columns: column(a) - column(b)),
    };
  }

  void _exchange(int a, int b) {
    final gem = _cells[a];
    _cells[a] = _cells[b];
    _cells[b] = gem;
  }

  List<List<int>> _matches() {
    final groups = <List<int>>[];
    for (final (stride, separation) in const [(1, size), (size, 1)]) {
      for (var line = 0; line < size; line++) {
        var group = <int>[];
        MatchGem? previous;
        for (var i = 0; i <= size; i++) {
          final index = line * separation + i * stride;
          final gem = i == size ? null : _cells[index];
          if (gem != previous || gem == null || gem == MatchGem.charged) {
            if (group.length >= 3) groups.add(group);
            group = [];
          }
          if (gem != null && gem != MatchGem.charged) group.add(index);
          previous = gem;
        }
      }
    }
    return groups;
  }

  void _prepareMatches(List<List<int>> lines) {
    cascadeDepth++;
    final matched = <int>{};
    int? junction;
    var longest = lines.first;
    for (final line in lines) {
      if (line.length > longest.length) longest = line;
      for (final index in line) {
        if (!matched.add(index)) junction ??= index;
      }
    }
    final cross = junction != null || longest.length >= 5;
    if (_canCharge) {
      chargeProgress += lines.length;
      if (cross || longest.length >= 4 || chargeProgress >= chargeGoal) {
        chargeProgress = chargeGoal;
        chargeKind = cross ? MatchChargeKind.cross : MatchChargeKind.row;
        _createCharge =
            junction ??
            (longest.contains(_to) ? _to : longest[longest.length ~/ 2]);
        _canCharge = false;
      }
    } else if (cross && chargeKind == MatchChargeKind.row) {
      // A later cascade can upgrade the same word crystal before it opens.
      chargeKind = MatchChargeKind.cross;
    }
    clearing = matched;
    travel = const {};
    _scoreClear = true;
    phase = MatchThreePhase.clearing;
  }

  void _dropGems() {
    final falling = <int, GemTravel>{};
    for (var x = 0; x < size; x++) {
      var target = size - 1;
      for (var source = size - 1; source >= 0; source--) {
        final gem = _cells[source * size + x];
        if (gem == null) continue;
        final index = target * size + x;
        _cells[index] = gem;
        if (source != target) {
          falling[index] = (rows: source - target, columns: 0);
        }
        target--;
      }
      final count = target + 1;
      while (target >= 0) {
        final index = target * size + x;
        _cells[index] = _colors[_random.nextInt(_colors.length)];
        falling[index] = (rows: -count, columns: 0);
        target--;
      }
    }
    travel = falling;
    phase = MatchThreePhase.falling;
  }

  void _settle() {
    travel = const {};
    if (_cells.contains(MatchGem.charged)) {
      final next = session.nextItem();
      if (next == null) {
        phase = MatchThreePhase.finished;
        return;
      }
      item = next;
      selectedAnswer = null;
      final correct = next.word.translation;
      final distractors =
          next.distractors
              .where((value) => value.trim().isNotEmpty && value != correct)
              .toSet()
              .toList()
            ..shuffle(_random);
      choices = [correct, ...distractors.take(2)]..shuffle(_random);
      phase = MatchThreePhase.question;
      return;
    }
    if (moves == 0 || session.isFinished) {
      phase = MatchThreePhase.finished;
      return;
    }
    if (!_hasLegalMove()) _replaceBoard();
    cascadeDepth = 0;
    phase = MatchThreePhase.ready;
  }

  bool _hasLegalMove() {
    for (var a = 0; a < _cells.length; a++) {
      for (final b in [a + 1, a + size]) {
        if (!adjacent(a, b) || _cells[a] == _cells[b]) continue;
        _exchange(a, b);
        final match = _matches().isNotEmpty;
        _exchange(a, b);
        if (match) return true;
      }
    }
    return false;
  }

  void _replaceBoard() {
    do {
      _fillBoard();
    } while (!_hasLegalMove());
  }

  /// Keep a teachable first move without replaying the same puzzle every round.
  void _openBoard() {
    while (true) {
      _fillBoard();
      final guideGem = _cells[guideFrom];
      if (_cells[guideTo] == guideGem) continue;
      for (final offset in const [-2, -1, 1]) {
        _cells[guideTo + offset] = guideGem;
      }
      if (_matches().isNotEmpty) continue;
      _exchange(guideFrom, guideTo);
      final matches = _matches();
      _exchange(guideFrom, guideTo);
      if (matches.length == 1 && matches.single.length == 4) return;
    }
  }

  void _fillBoard() {
    for (var i = 0; i < _cells.length; i++) {
      final options = [..._colors];
      if (column(i) >= 2 && _cells[i - 1] == _cells[i - 2]) {
        options.remove(_cells[i - 1]);
      }
      if (row(i) >= 2 && _cells[i - size] == _cells[i - 2 * size]) {
        options.remove(_cells[i - size]);
      }
      _cells[i] = options[_random.nextInt(options.length)];
    }
  }
}
