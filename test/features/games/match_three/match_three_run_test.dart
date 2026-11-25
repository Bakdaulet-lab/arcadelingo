import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/match_three/match_three_run.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';

const _llave = ReviewItem(
  word: Word(id: 'llave', text: 'llave', translation: 'ключ'),
  distractors: ['дверь', 'билет', 'окно'],
);

void _settle(MatchThreeRun run) {
  for (var i = 0; i < 40 && run.isAnimating; i++) {
    run.advance();
  }
  expect(run.isAnimating, isFalse);
}

// Read visible neighbors independently of the game's match scanner.
List<Set<int>> _linesAfter(List<MatchGem?> cells, int from, int to) {
  final grid = [...cells];
  final gem = grid[from];
  grid[from] = grid[to];
  grid[to] = gem;
  final lines = <Set<int>>[];
  for (final start in [from, to]) {
    for (final stride in [1, MatchThreeRun.size]) {
      final connected = {start};
      for (final sign in [-1, 1]) {
        var last = start;
        var next = start + sign * stride;
        while (MatchThreeRun.adjacent(last, next) &&
            grid[next] == grid[start]) {
          connected.add(next);
          last = next;
          next += sign * stride;
        }
      }
      if (connected.length >= 3) lines.add(connected);
    }
  }
  return lines;
}

Iterable<({int from, int to, List<Set<int>> lines})> _moves(
  MatchThreeRun run,
) sync* {
  for (var from = 0; from < run.cells.length; from++) {
    for (final to in [from + 1, from + MatchThreeRun.size]) {
      if (!MatchThreeRun.adjacent(from, to) || run.cells[from] == run.cells[to])
        continue;
      final lines = _linesAfter(run.cells, from, to);
      if (lines.isNotEmpty) yield (from: from, to: to, lines: lines);
    }
  }
}

void main() {
  test(
    'seeded openings vary spatially and preserve an ordinary four for the guide',
    () {
      final patterns = <String>{};
      for (var seed = 0; seed < 24; seed++) {
        final run = MatchThreeRun(FakeReviewSession([_llave]), Random(seed));
        final colors = run.cells.toSet().toList();
        // Canonicalise colors so a palette shuffle alone cannot pass this check.
        patterns.add(run.cells.map(colors.indexOf).join());
        final same = MatchThreeRun(FakeReviewSession([_llave]), Random(seed));
        expect(same.cells, run.cells);
        final guide = _linesAfter(
          run.cells,
          MatchThreeRun.guideFrom,
          MatchThreeRun.guideTo,
        );
        expect(guide.map((line) => line.length), [4]);
        run.swap(MatchThreeRun.guideFrom, MatchThreeRun.guideTo);
        run.advance();
        expect(run.chargeKind, MatchChargeKind.row);
      }
      expect(patterns, hasLength(24));
    },
  );

  for (final five in [false, true]) {
    test(
      'a ${five ? 'long line' : 'junction'} awards a word and fires exactly one cross',
      () {
        for (var seed = 0; seed < 150; seed++) {
          final session = FakeReviewSession([_llave, _llave]);
          final run = MatchThreeRun(session, Random(seed));
          for (final move in _moves(run)) {
            final long = move.lines.any((line) => line.length >= 5);
            final junction = move.lines.any(
              (a) => move.lines.any(
                (b) => !identical(a, b) && a.intersection(b).length == 1,
              ),
            );
            if (!(five ? long : junction && !long)) continue;
            expect(run.swap(move.from, move.to), isTrue);
            run.advance();
            expect(run.chargeKind, MatchChargeKind.cross);
            _settle(run);
            expect(run.phase, MatchThreePhase.question);
            expect(run.chargeProgress, MatchThreeRun.chargeGoal);
            final at = run.cells.indexOf(MatchGem.charged);
            expect(run.answer('ключ', Duration.zero), isTrue);
            run.advance();
            expect(run.blastOrigin, at);
            expect(run.clearing, {
              for (var i = 0; i < 36; i++)
                if (i % 6 == at % 6 || i ~/ 6 == at ~/ 6) i,
            });
            run.advance();
            expect(run.blastOrigin, isNull);
            expect(run.chargeKind, isNull);
            expect(run.chargeProgress, 0);
            _settle(run);
            expect(session.nextItemCalls, 1);
            expect(session.reports, hasLength(1));
            return;
          }
        }
        fail('no qualifying seeded board');
      },
    );
  }

  test(
    'plain matches fill the meter, cascades reward the player, and rounds settle',
    () {
      var earnedFromTriples = 0;
      var rewardedCascade = false;
      for (var seed = 0; seed < 12; seed++) {
        final session = FakeReviewSession(List.filled(30, _llave));
        final run = MatchThreeRun(session, Random(seed));
        while (run.phase == MatchThreePhase.ready) {
          final moves = _moves(run).toList();
          expect(moves, isNotEmpty);
          final move = moves.firstWhere(
            (m) => m.lines.length == 1 && m.lines.single.length == 3,
            orElse: () => moves.first,
          );
          final oldMoves = run.moves;
          final before = run.chargeProgress;
          final requests = session.nextItemCalls;
          run.swap(move.from, move.to);
          run.advance();
          expect(run.moves, oldMoves - 1);
          if (move.lines.length == 1 && move.lines.single.length == 3) {
            expect(run.chargeProgress, before + 1);
            if (run.chargeProgress == MatchThreeRun.chargeGoal) {
              expect(run.chargeKind, MatchChargeKind.row);
              earnedFromTriples++;
            }
          }
          for (var i = 0; i < 90 && run.isAnimating; i++) {
            final depth = run.cascadeDepth;
            final count = run.clearing.length;
            final score = run.score;
            run.advance();
            if (count > 0 && depth >= 2) {
              expect(run.score - score, greaterThan(10 * count));
              rewardedCascade = true;
            }
          }
          if (run.phase == MatchThreePhase.question) {
            run.answer('ключ', Duration.zero);
            _settle(run);
          }
          expect(session.nextItemCalls - requests, inInclusiveRange(0, 1));
          expect(session.reports.length, session.nextItemCalls);
          expect(
            run.phase,
            isIn([MatchThreePhase.ready, MatchThreePhase.finished]),
          );
        }
        expect(run.moves, 0);
      }
      expect(earnedFromTriples, greaterThan(0));
      expect(rewardedCascade, isTrue);
    },
  );

  test('обмены без совпадения возвращаются и сохраняют ходы', () {
    final session = FakeReviewSession([_llave]);
    final run = MatchThreeRun(session, Random(10));
    final before = List.of(run.cells);
    expect(before, hasLength(36));
    expect(run.swap(0, 12), isFalse);
    expect(run.swap(0, 1), isTrue);
    _settle(run);
    expect(run.phase, MatchThreePhase.ready);
    expect(run.cells, before);
    expect(run.moves, MatchThreeRun.moveLimit);
    expect(run.score, 0);
    expect(session.nextItemCalls, 0);
  });

  test('четвёрка открывает слово, правильный перевод очищает строку', () {
    final session = FakeReviewSession([_llave, _llave]);
    final run = MatchThreeRun(session, Random(10));
    expect(run.swap(9, 15), isTrue);
    _settle(run);
    expect(run.phase, MatchThreePhase.question);
    expect(run.moves, MatchThreeRun.moveLimit - 1);
    expect(run.item, same(_llave));
    expect(run.choices, hasLength(3));
    expect(run.swap(0, 1), isFalse);
    final chargedRow = run.cells.indexOf(MatchGem.charged) ~/ 6;
    final scoreBefore = run.score;
    expect(run.answer('ключ', Duration.zero), isTrue);
    expect(run.answer('ключ', Duration.zero), isFalse);
    expect(session.reports.single.outcome.correct, isTrue);
    run.advance();
    expect(run.phase, MatchThreePhase.clearing);
    expect(run.clearing, {for (var i = 0; i < 6; i++) chargedRow * 6 + i});
    _settle(run);
    expect(run.phase, MatchThreePhase.ready);
    expect(run.cells, isNot(contains(MatchGem.charged)));
    expect(run.cells, everyElement(isNotNull));
    expect(run.score, greaterThanOrEqualTo(scoreBefore + 120));
    expect(session.nextItemCalls, 1);
  });

  test('неверный перевод записывается один раз и оставляет обычные фишки', () {
    final session = FakeReviewSession([_llave]);
    final run = MatchThreeRun(session, Random(10));
    run.swap(9, 15);
    _settle(run);
    final charged = run.cells.indexOf(MatchGem.charged);
    final scoreBefore = run.score;
    final wrong = run.choices.firstWhere((value) => value != 'ключ');
    expect(run.answer(wrong, Duration.zero), isTrue);
    expect(session.reports.single.outcome.selectedAnswer, wrong);
    expect(session.reports.single.outcome.correct, isFalse);
    expect(run.score, scoreBefore);
    run.advance();
    expect(run.clearing, {charged});
    _settle(run);
    expect(run.phase, MatchThreePhase.finished);
    run.abandon();
    expect(session.reports, hasLength(1));
  });
}
