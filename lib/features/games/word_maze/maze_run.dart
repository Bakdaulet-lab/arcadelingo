import 'dart:collection';
import 'dart:math' as math;

typedef MazeCell = ({int x, int y});
typedef MazePosition = ({double x, double y});

enum MazeDirection {
  up(0, -1),
  right(1, 0),
  down(0, 1),
  left(-1, 0);

  const MazeDirection(this.dx, this.dy);
  final int dx;
  final int dy;

  MazeDirection get opposite => values[(index + 2) % 4];
  MazeCell from(MazeCell cell) => (x: cell.x + dx, y: cell.y + dy);
}

enum MazeEvent { gate, caught }

const _epsilon = 1e-9;
const _gateGroups = [
  [(x: 2, y: 3), (x: 8, y: 1), (x: 14, y: 3)],
  [(x: 1, y: 11), (x: 8, y: 5), (x: 15, y: 11)],
  [(x: 4, y: 9), (x: 8, y: 13), (x: 12, y: 9)],
  [(x: 2, y: 13), (x: 8, y: 3), (x: 14, y: 13)],
  [(x: 2, y: 7), (x: 8, y: 11), (x: 14, y: 7)],
  [(x: 4, y: 1), (x: 8, y: 7), (x: 12, y: 1)],
];
const _layouts = [
  [
    '#################',
    '#...............#',
    '#.##.##..##.###.#',
    '#....#.....#....#',
    '#.##.#.#.#.#.##.#',
    '#....#.#.#......#',
    '###.##.#.##.###.#',
    '#......#........#',
    '#.##.#.#.#.####.#',
    '#...............#',
    '#.##.#.#.#.#.##.#',
    '#....#...#.#....#',
    '#.##.###.###.##.#',
    '#...............#',
    '#################',
  ],
  [
    '#################',
    '#....#.....#....#',
    '#.##.#.#.#.#.##.#',
    '#......#.#......#',
    '#.##.#.#.#.#.##.#',
    '#..#.#.....#.#..#',
    '#..#.###.###.#..#',
    '#...............#',
    '###.##.#.##.#.###',
    '#...............#',
    '#.##.###.###.##.#',
    '#....#.....#....#',
    '#.##.#.#.#.#.##.#',
    '#...............#',
    '#################',
  ],
  [
    '#################',
    '#...............#',
    '#.###.##.##.###.#',
    '#...#.......#...#',
    '#.#.#.##.##.#.#.#',
    '#.#....#....#.#.#',
    '#.####.#.##.#.#.#',
    '#......#........#',
    '#.##.#.#.#.##.#.#',
    '#...............#',
    '#.##.#.#.#.#.##.#',
    '#..#...#...#....#',
    '#..#.###.###.##.#',
    '#...............#',
    '#################',
  ],
];

/// Coordinates denote tile centres: (0, 0) is the centre of the top-left tile.
/// A submitted gate or contact stops this run at the exact point of the event.
class MazeRun {
  MazeRun({
    int seed = 0,
    int gateCount = 3,
    int correctAnswers = 0,
    int wave = 0,
  }) : layoutIndex = seed % (_layouts.length * 2),
       _gateRandom = math.Random(seed),
       _upperChaseStart = wave.isOdd,
       _chaserOnRight = seed.isEven {
    _difficulty = (correctAnswers ~/ 3).clamp(0, 4);
    _shieldEnds = wave == 0 ? _graceSeconds : 1.8 - .16 * _difficulty;
    _setGates(
      gateCount,
      wave == 0 ? 0 : 1 + _gateRandom.nextInt(_gateGroups.length - 1),
    );
    for (var y = 1; y < rows - 1; y++) {
      for (var x = 1; x < columns - 1; x++) {
        final cell = (x: x, y: y);
        if (!isWall(x, y) && cell != spawn && !gates.contains(cell)) {
          _pellets.add(cell);
        }
      }
    }
    _placeActors();
  }

  static const columns = 17;
  static const rows = 15;
  static const spawn = (x: 8, y: 9);
  static const playerSpeed = 4.6;
  static const _graceSeconds = 3.0;
  static const _lateTurnDistance = .16;
  static const _contactRadius = .51;
  static const _patrol = [
    (x: 4, y: 9),
    (x: 12, y: 9),
    (x: 15, y: 7),
    (x: 8, y: 3),
    (x: 1, y: 7),
    (x: 8, y: 13),
  ];
  static const _guardCorners = [
    (x: 1, y: 1),
    (x: 15, y: 1),
    (x: 1, y: 13),
    (x: 15, y: 13),
  ];

  final int layoutIndex;
  final math.Random _gateRandom;
  late List<MazeCell> _gates;
  List<MazeCell> get gates => _gates;
  late int _difficulty;
  int _gateWave = 0;
  int get gateWave => _gateWave;
  double _shieldEnds = _graceSeconds;
  final bool _chaserOnRight;
  final bool _upperChaseStart;
  final _pellets = <MazeCell>{};
  late final Iterable<MazeCell> pellets = UnmodifiableSetView(_pellets);
  late _Walker _player;
  late List<_Walker> _ghosts;
  var _patrolIndex = 0;
  var _elapsed = 0.0;
  var _collected = 0;
  var _started = false;
  var _facing = MazeDirection.up;
  MazeDirection? _requested;
  MazeEvent? _event;
  int? _selected;

  MazePosition get player => _player.position;
  List<MazePosition> get ghosts => [
    for (final ghost in _ghosts) ghost.position,
  ];
  MazeDirection get facing => _facing;
  bool get moving => _event == null && _player.heading != null;
  bool get protected => _elapsed < _shieldEnds - _epsilon;
  double get elapsedSeconds => _elapsed;
  int get collected => _collected;
  int? get selectedGate => _selected;

  bool isWall(int x, int y) =>
      x < 0 ||
      y < 0 ||
      x >= columns ||
      y >= rows ||
      _layouts[layoutIndex % _layouts.length][y].codeUnitAt(
            layoutIndex < _layouts.length ? x : columns - 1 - x,
          ) ==
          35;

  bool _open(MazeCell cell) => !isWall(cell.x, cell.y);

  void _placeActors() {
    _player = _Walker(spawn, playerSpeed);
    final chaserStart = (
      x: _chaserOnRight ? 15 : 1,
      y: _upperChaseStart ? 1 : 13,
    );
    _ghosts = [
      _Walker(chaserStart, _chaseSpeed),
      _Walker((x: _chaserOnRight ? 1 : 15, y: 13), _patrolSpeed),
    ];
    if (_difficulty >= 2) _addFlanker();
    _patrolIndex = _chaserOnRight ? 0 : 1;
  }

  double get _chaseSpeed => 2.65 + .28 * _difficulty;
  double get _patrolSpeed => 2.35 + .22 * _difficulty;

  int _distance(MazeCell a, MazeCell b) =>
      (a.x - b.x).abs() + (a.y - b.y).abs();

  void _addFlanker() {
    // Bring in the third guard at a distant corner, never on top of the runner.
    final occupied = [_player.cell, for (final guard in _ghosts) guard.cell];
    int clearance(MazeCell cell) =>
        occupied.map((p) => _distance(cell, p)).reduce(math.min);
    final corner = _guardCorners.reduce(
      (a, b) => clearance(a) >= clearance(b) ? a : b,
    );
    _ghosts.add(_Walker(corner, _patrolSpeed));
  }

  void _setGates(int count, int group) {
    final sites = _gateGroups[group];
    _gates = switch (count) {
      1 => [sites[1]],
      2 => [sites[0], sites[2]],
      3 => sites,
      _ => throw RangeError.range(count, 1, 3, 'gateCount'),
    };
    _pellets.removeAll(_gates);
  }

  /// Changes the answers while leaving the runner, guards and pickups in place.
  void nextGates({required int gateCount, required int correctAnswers}) {
    if (_event != MazeEvent.gate) return;
    final origin = _player.cell;
    final groups = [
      for (var i = 0; i < _gateGroups.length; i++)
        if (_gateGroups[i].every((site) => _distance(origin, site) >= 5)) i,
    ];
    _setGates(gateCount, groups[_gateRandom.nextInt(groups.length)]);
    _gateWave++;
    _difficulty = (correctAnswers ~/ 3).clamp(0, 4);
    _ghosts.first.speed = _chaseSpeed;
    for (final guard in _ghosts.skip(1)) {
      guard.speed = _patrolSpeed;
    }
    if (_difficulty >= 2 && _ghosts.length == 2) _addFlanker();
    _selected = null;
    _event = null;
    _shieldEnds = math.max(_shieldEnds, _elapsed + 1.2);
    _chooseTurn();
    if (!moving) {
      // A side gate can lie at the end of a lane. Follow its corner until
      // the next swipe instead of leaving the runner facing a wall.
      final options = MazeDirection.values.where((d) => _open(d.from(origin)));
      steer(
        options.firstWhere(
          (d) => d != facing.opposite,
          orElse: () => options.first,
        ),
      );
    }
  }

  /// A caught player gets another approach to the same gates and pickups.
  void respawn() {
    if (_event != MazeEvent.caught) return;
    _event = null;
    _started = false;
    _elapsed = 0;
    _shieldEnds = _graceSeconds;
    _facing = MazeDirection.up;
    _requested = null;
    _placeActors();
  }

  void steer(MazeDirection direction) {
    if (_event != null) return;
    _requested = direction;
    if (_player.progress == 0) {
      _chooseTurn();
    } else if (_player.heading?.opposite == direction) {
      _player.reverse();
      _facing = direction;
      _requested = null;
    } else if (_player.progress <= _lateTurnDistance &&
        _player.heading != direction &&
        _player.lastHeading == _player.heading &&
        _open(direction.from(_player.cell))) {
      // Return the last few pixels to a just-missed junction along the lane.
      // The direction remains buffered until the player reaches its centre.
      _player.reverse();
    }
  }

  void _chooseTurn() {
    final requested = _requested;
    if (requested != null && _open(requested.from(_player.cell))) {
      _requested = null;
      _started = true;
      _facing = requested;
    }
    _player.heading =
        _started && _open(_facing.from(_player.cell)) ? _facing : null;
  }

  /// Integrate straight segments up to the next junction or contact. The
  /// ticker cadence only changes when intermediate positions are drawn.
  MazeEvent? advance(double dtSeconds) {
    if (!_started || _event != null || dtSeconds <= 0 || !dtSeconds.isFinite) {
      return null;
    }
    var remaining = dtSeconds;
    while (remaining > _epsilon) {
      final shielded = protected;
      var step = math.min(remaining, _player.secondsToCentre);
      for (var i = 0; i < _ghosts.length; i++) {
        final ghost = _ghosts[i];
        ghost.heading ??= _ghostTurn(ghost, i);
        step = math.min(step, ghost.secondsToCentre);
      }
      if (shielded) {
        step = math.min(step, _shieldEnds - _elapsed);
      }
      var contact = double.infinity;
      if (!shielded) {
        for (final ghost in _ghosts) {
          contact = math.min(contact, _timeToContact(ghost));
        }
      }
      step = math.min(step, contact);
      final arrival = _player.travel(step);
      for (final ghost in _ghosts) {
        ghost.travel(step);
      }
      _elapsed += step;
      remaining -= step;
      if (arrival) {
        if (_pellets.remove(_player.cell)) _collected++;
        final index = gates.indexOf(_player.cell);
        if (index != -1) {
          _selected = index;
          return _event = MazeEvent.gate;
        }
        _chooseTurn();
      }
      if (contact <= step + _epsilon) return _event = MazeEvent.caught;
    }
    return null;
  }

  MazeDirection _ghostTurn(_Walker ghost, int index) {
    if (index == 1 && ghost.cell == _patrol[_patrolIndex]) {
      _patrolIndex = (_patrolIndex + 1) % _patrol.length;
    }
    final options = [
      for (final direction in MazeDirection.values)
        if (_open(direction.from(ghost.cell))) direction,
    ];
    if (options.length > 1) options.remove(ghost.lastHeading?.opposite);
    if (options.length == 1) return options.first;
    final MazeCell target;
    if (index == 0) {
      final position = player;
      target = (x: position.x.round(), y: position.y.round());
    } else if (index == 1) {
      target = _patrol[_patrolIndex];
    } else {
      var ahead = _player.cell;
      for (var step = 0; step < 3; step++) {
        final next = facing.from(ahead);
        if (!_open(next)) break;
        ahead = next;
      }
      target = ahead;
    }
    final distances = _distancesFrom(target);
    int distance(MazeDirection direction) {
      final next = direction.from(ghost.cell);
      return distances[next.y * columns + next.x];
    }

    return options.reduce((a, b) => distance(b) < distance(a) ? b : a);
  }

  /// Breadth-first distances are only needed when a pursuer has a choice.
  List<int> _distancesFrom(MazeCell target) {
    const unreachable = rows * columns;
    final distances = List.filled(unreachable, unreachable);
    final queue = [target];
    distances[target.y * columns + target.x] = 0;
    for (var i = 0; i < queue.length; i++) {
      final cell = queue[i];
      final nextDistance = distances[cell.y * columns + cell.x] + 1;
      for (final direction in MazeDirection.values) {
        final next = direction.from(cell);
        if (!_open(next)) continue;
        final address = next.y * columns + next.x;
        if (distances[address] != unreachable) continue;
        distances[address] = nextDistance;
        queue.add(next);
      }
    }
    return distances;
  }

  /// Swept circle contact also catches two actors crossing between frames.
  double _timeToContact(_Walker ghost) {
    final a = _player.position;
    final b = ghost.position;
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final c = dx * dx + dy * dy - _contactRadius * _contactRadius;
    if (c <= 0) return 0;
    final vx = _player.vx - ghost.vx;
    final vy = _player.vy - ghost.vy;
    final approach = dx * vx + dy * vy;
    if (approach >= 0) return double.infinity;
    final speed2 = vx * vx + vy * vy;
    final discriminant = approach * approach - speed2 * c;
    if (discriminant < 0) return double.infinity;
    return c / (-approach + math.sqrt(discriminant));
  }
}

class _Walker {
  _Walker(this.cell, this.speed);

  MazeCell cell;
  double speed;
  MazeDirection? heading;
  MazeDirection? lastHeading;
  double progress = 0;

  MazePosition get position => (
    x: cell.x + progress * (heading?.dx ?? 0),
    y: cell.y + progress * (heading?.dy ?? 0),
  );
  double get vx => speed * (heading?.dx ?? 0);
  double get vy => speed * (heading?.dy ?? 0);
  double get secondsToCentre =>
      heading == null ? double.infinity : (1 - progress) / speed;

  void reverse() {
    final direction = heading!;
    cell = direction.from(cell);
    heading = direction.opposite;
    progress = 1 - progress;
  }

  bool travel(double seconds) {
    final direction = heading;
    if (direction == null) return false;
    progress += seconds * speed;
    if (progress < 1 - _epsilon) return false;
    cell = direction.from(cell);
    lastHeading = direction;
    heading = null;
    progress = 0;
    return true;
  }
}
