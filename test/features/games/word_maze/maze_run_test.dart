import 'package:arcadelingo/features/games/word_maze/maze_run.dart';
import 'package:flutter_test/flutter_test.dart';

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
      expect(layouts.length, greaterThan(1));
    },
  );

  test(
    'a swipe advances immediately, reverses continuously, and collects once',
    () {
      final run = MazeRun();
      expect(run.advance(20), isNull);
      expect(run.player, (x: 6.0, y: 7.0));
      expect(run.moving, isFalse);
      expect(run.collected, 0);
      run.steer(MazeDirection.left);
      run.advance(.014);
      expect(run.player.x, closeTo(6 - MazeRun.playerSpeed * .014, 1e-8));
      run.advance(1.25 / MazeRun.playerSpeed - .014);
      expect(run.collected, 1);
      final before = run.player;
      run.steer(MazeDirection.right);
      expect(run.player, before);
      expect(run.facing, MazeDirection.right);
      run.advance(.5 / MazeRun.playerSpeed);
      expect(run.player.x, closeTo(before.x + .5, 1e-8));
      expect(run.collected, 1);
      expect(run.pellets, isNot(contains((x: 5, y: 7))));
    },
  );

  test('a buffered turn waits through a wall and takes the first junction', () {
    final run = MazeRun()..steer(MazeDirection.left);
    run.advance(.2 / MazeRun.playerSpeed);
    run.steer(MazeDirection.up);
    run.advance(1.3 / MazeRun.playerSpeed);
    expect(run.player.x, closeTo(4.5, 1e-8));
    expect(run.player.y, 7);
    run.advance(1.1 / MazeRun.playerSpeed);
    expect(run.facing, MazeDirection.up);
    expect(run.player.x, 4);
    expect(run.player.y, closeTo(6.4, 1e-8));
    expect(run.collected, 2);
  });

  test('all gate counts and layouts emit only the gate entered, once', () {
    for (var seed = 0; seed < 6; seed++) {
      for (var count = 1; count <= 3; count++) {
        for (var i = 0; i < count; i++) {
          final run = MazeRun(seed: seed, gateCount: count);
          final gate = run.gates[i];
          if (gate.x != MazeRun.spawn.x) {
            run.steer(
              gate.x < MazeRun.spawn.x
                  ? MazeDirection.left
                  : MazeDirection.right,
            );
            run.advance(4.7 / MazeRun.playerSpeed);
          }
          run.steer(MazeDirection.up);
          final distance = gate.x == MazeRun.spawn.x ? 6.0 : 4.3;
          expect(run.advance((distance - .1) / MazeRun.playerSpeed), isNull);
          expect(run.selectedGate, isNull);
          expect(run.advance(.2 / MazeRun.playerSpeed), MazeEvent.gate);
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
      expect(run.advance(1.5), isNull);
      expect(run.protected, isTrue);
      expect(run.player.x, 11);
      expect(run.player.y, 7);
      expect(run.moving, isFalse);
      expect(run.advance(15), MazeEvent.caught);
      expect(run.selectedGate, isNull);
      final score = run.collected;
      expect(score, 5);
      expect(run.advance(1), isNull);
      run.respawn();
      expect(run.player, (x: 6.0, y: 7.0));
      expect(run.protected, isTrue);
      expect(run.collected, score);
      run.steer(MazeDirection.right);
      expect(run.advance(1.25 / MazeRun.playerSpeed), isNull);
      expect(run.collected, score);
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
      result.add((
        player: run.player,
        ghosts: run.ghosts,
        time: run.elapsedSeconds,
        score: run.collected,
      ));
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
}
