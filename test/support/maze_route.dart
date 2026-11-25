import 'package:arcadelingo/features/games/word_maze/maze_run.dart';

/// Shortest route to the intended gate without collecting a different answer.
List<MazeDirection> mazeRoute(MazeRun run, int index) {
  final start = (x: run.player.x.round(), y: run.player.y.round());
  final goal = run.gates[index];
  final queue = [start];
  final paths = <MazeCell, List<MazeDirection>>{start: []};
  for (var i = 0; i < queue.length; i++) {
    final cell = queue[i];
    if (cell == goal) return paths[cell]!;
    for (final direction in MazeDirection.values) {
      final next = direction.from(cell);
      if (run.isWall(next.x, next.y) ||
          paths.containsKey(next) ||
          (next != goal && run.gates.contains(next))) {
        continue;
      }
      paths[next] = [...paths[cell]!, direction];
      queue.add(next);
    }
  }
  throw StateError('Gate $goal is unreachable from $start');
}
