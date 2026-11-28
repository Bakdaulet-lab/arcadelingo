import 'package:arcadelingo/features/games/word_maze/maze_run.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/maze_route.dart';

Set<MazeCell> _reachable(MazeRun run, {Set<MazeCell> blocked = const {}}) {
  final queue = [MazeRun.spawn];
  final visited = {MazeRun.spawn};
  for (var i = 0; i < queue.length; i++) {
    final cell = queue[i];
    for (final direction in MazeDirection.values) {
      final next = (x: cell.x + direction.dx, y: cell.y + direction.dy);
      if (!run.isWall(next.x, next.y) &&
          !blocked.contains(next) &&
          visited.add(next)) {
        queue.add(next);
      }
    }
  }
  return visited;
}

void main() {
  test(
    'all handcrafted routes have reachable pellets and independent gates',
    () {
      final layouts = <String>{};
      for (var seed = 0; seed < 6; seed++) {
        for (var count = 1; count <= 3; count++) {
          final run = MazeRun(seed: seed, gateCount: count);
          final floor = {
            for (var y = 0; y < MazeRun.rows; y++)
              for (var x = 0; x < MazeRun.columns; x++)
                if (!run.isWall(x, y)) (x: x, y: y),
          };
          expect(_reachable(run), floor);
          expect(run.gates.toSet(), hasLength(count));
          expect(run.isWall(-1, 7), isTrue);
          expect(run.isWall(MazeRun.columns, 7), isTrue);
          expect(run.pellets, isNot(contains(MazeRun.spawn)));
          expect(run.pellets.toSet().difference(floor), isEmpty);
          for (final gate in run.gates) {
            expect(run.pellets, isNot(contains(gate)));
            final otherGates = run.gates.where((cell) => cell != gate).toSet();
            expect(_reachable(run, blocked: otherGates), contains(gate));
          }
          layouts.add(floor.join(','));
        }
      }
      expect(layouts.length, greaterThanOrEqualTo(5));
      expect(MazeRun.columns * MazeRun.rows, greaterThanOrEqualTo(250));
    },
  );

  test(
    'a swipe advances immediately, reverses continuously, and collects once',
    () {
      final run = MazeRun();
      expect(run.advance(20), isNull);
      expect(run.player, (x: 8.0, y: 9.0));
      expect(run.moving, isFalse);
      expect(run.collected, 0);
      run.steer(MazeDirection.left);
      run.advance(.014);
      expect(run.player.x, closeTo(8 - MazeRun.playerSpeed * .014, 1e-8));
      run.advance(1.25 / MazeRun.playerSpeed - .014);
      expect(run.collected, 1);
      final before = run.player;
      run.steer(MazeDirection.right);
      expect(run.player, before);
      expect(run.facing, MazeDirection.right);
      run.advance(.5 / MazeRun.playerSpeed);
      expect(run.player.x, closeTo(before.x + .5, 1e-8));
      expect(run.collected, 1);
      expect(run.pellets, isNot(contains((x: 7, y: 9))));
    },
  );

  test('a buffered turn waits through a wall and takes the first junction', () {
    final run = MazeRun()..steer(MazeDirection.left);
    run.advance(.2 / MazeRun.playerSpeed);
    run.steer(MazeDirection.up);
    run.advance(1.3 / MazeRun.playerSpeed);
    expect(run.player.x, closeTo(6.5, 1e-8));
    expect(run.player.y, 9);
    run.advance(1.1 / MazeRun.playerSpeed);
    expect(run.facing, MazeDirection.up);
    expect(run.player.x, 6);
    expect(run.player.y, closeTo(8.4, 1e-8));
    expect(run.collected, 2);
  });

  test('all gate counts and layouts emit only the gate entered, once', () {
    for (var seed = 0; seed < 6; seed++) {
      for (var count = 1; count <= 3; count++) {
        for (var i = 0; i < count; i++) {
          final run = MazeRun(seed: seed, gateCount: count);
          final route = mazeRoute(run, i);
          for (final step in route.take(route.length - 1)) {
            run.steer(step);
            expect(run.advance(1 / MazeRun.playerSpeed), isNull);
          }
          run.steer(route.last);
          expect(run.advance(.92 / MazeRun.playerSpeed), isNull);
          expect(run.selectedGate, isNull);
          expect(run.advance(.10 / MazeRun.playerSpeed), MazeEvent.gate);
          expect(run.selectedGate, i);
          final position = run.player;
          run.steer(MazeDirection.down);
          expect(run.advance(1), isNull);
          expect(run.player, position);
        }
      }
    }
  });

  test(
    'ghost contact respects grace, locks once, and a retry keeps pellets',
    () {
      final run = MazeRun()..steer(MazeDirection.right);
      expect(run.advance(1.7), isNull);
      expect(run.protected, isTrue);
      expect(run.player.x, 15);
      expect(run.player.y, 9);
      expect(run.moving, isFalse);
      expect(run.advance(15), MazeEvent.caught);
      expect(run.selectedGate, isNull);
      final score = run.collected;
      expect(score, 7);
      expect(run.advance(1), isNull);
      run.respawn();
      expect(run.player, (x: 8.0, y: 9.0));
      expect(run.protected, isTrue);
      expect(run.collected, score);
      run.steer(MazeDirection.right);
      expect(run.advance(1.25 / MazeRun.playerSpeed), isNull);
      expect(run.collected, score);
    },
  );

  test(
    'a new gate wave keeps actors and dots, moves gates away and ramps pursuit',
    () {
      for (var seed = 0; seed < 6; seed++) {
        final run = MazeRun(seed: seed)..steer(MazeDirection.up);
        expect(run.advance(8 / MazeRun.playerSpeed), MazeEvent.gate);
        final gate = run.player;
        final dots = run.collected;
        final guards = run.ghosts;
        run.nextGates(gateCount: 3, correctAnswers: 6);
        expect(run.player, gate);
        expect(run.collected, dots);
        expect(run.ghosts.take(2).toList(), guards);
        expect(run.ghosts, hasLength(3));
        expect(run.selectedGate, isNull);
        expect(run.moving, isTrue);
        for (var i = 0; i < run.gates.length; i++) {
          expect(mazeRoute(run, i).length, greaterThanOrEqualTo(5));
        }
        expect(run.advance(.05), isNull);
        expect(run.player, isNot(gate));
      }
    },
  );

  test('30, 60 and 120 Hz produce the same positions, contact and score', () {
    final result =
        <
          ({
            MazePosition player,
            List<MazePosition> ghosts,
            double time,
            int score,
          })
        >[];
    for (final hz in [30, 60, 120]) {
      final run = MazeRun()..steer(MazeDirection.right);
      MazeEvent? event;
      while (event == null && run.elapsedSeconds < 15) {
        event = run.advance(1 / hz);
        for (final p in [run.player, ...run.ghosts]) {
          expect(run.isWall(p.x.round(), p.y.round()), isFalse);
          expect(
            (p.x - p.x.round()).abs() < 1e-8 ||
                (p.y - p.y.round()).abs() < 1e-8,
            isTrue,
          );
        }
      }
      expect(event, MazeEvent.caught);
      final snapshot = (
        player: run.player,
        ghosts: run.ghosts,
        time: run.elapsedSeconds,
        score: run.collected,
      );
      result.add(snapshot);
    }
    for (final r in result.skip(1)) {
      expect(r.player, result.first.player);
      expect(r.time, closeTo(result.first.time, 1e-8));
      expect(r.score, result.first.score);
      for (var i = 0; i < r.ghosts.length; i++) {
        expect(r.ghosts[i].x, closeTo(result.first.ghosts[i].x, 1e-8));
        expect(r.ghosts[i].y, closeTo(result.first.ghosts[i].y, 1e-8));
      }
    }
  });

  test(
    'a slightly late turn crosses the junction smoothly without jumping',
    () {
      final run = MazeRun()..steer(MazeDirection.left);
      run.advance(2.12 / MazeRun.playerSpeed);
      final before = run.player;
      run.steer(MazeDirection.up);
      expect(run.player.x, closeTo(before.x, 1e-8));
      expect(run.player.y, before.y);
      run.advance(.4 / MazeRun.playerSpeed);
      expect(run.player.x, closeTo(6, 1e-8));
      expect(run.player.y, closeTo(8.72, 1e-8));
    },
  );

  test(
    'guards begin moving with the first input, even while the player is protected',
    () {
      for (var seed = 0; seed < 6; seed++) {
        final run = MazeRun(seed: seed);
        final start = run.ghosts;
        expect(run.advance(.5), isNull);
        expect(run.ghosts, start);
        run.steer(MazeDirection.up);
        expect(run.advance(.18), isNull);
        expect(run.protected, isTrue);
        for (var i = 0; i < start.length; i++) {
          expect(run.ghosts[i], isNot(start[i]));
        }
        expect(run.selectedGate, isNull);
      }
    },
  );
}
