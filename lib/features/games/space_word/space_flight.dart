import 'dart:math' as math;
import 'dart:ui';

enum SpaceBurstKind { correct, wrong, rock, shield }

class FlightEvent {
  const FlightEvent(this.index);

  /// Index into the current wave's options. Null denotes a hull collision.
  final int? index;
}

class SpaceDrone {
  SpaceDrone(this.index, this._size);
  final int index;
  Size _size;
  Offset position = Offset.zero;
  double _startY = 0;
  double _hiddenUntil = 0;
  bool visible = true;
  double get width => _size.width;
  double get height => _size.height;
}

class SpaceRock {
  SpaceRock(this.id, this.position, this._velocity, this.radius)
    : angle = id * 1.54;
  final int id;
  final double radius;
  Offset position;
  Offset _velocity;
  double angle;
  double _deflection = 0;
  int _passes = 0;
}

class SpaceBolt {
  SpaceBolt(this.position);
  Offset position;
}

class SpaceBurst {
  SpaceBurst(this.position, this.kind);
  final Offset position;
  final SpaceBurstKind kind;
  double progress = 0;
}

/// All geometry is in design coordinates. The field scales pointer input and
/// paint together, so drawing and hit testing stay aligned at every size.
class SpaceFlight {
  static const worldSize = Size(360, 420);
  static const _step = 1 / 240;
  static const _shotInterval = .20;
  static const _start = Offset(180, 344);

  Offset ship = _start;
  Offset _aim = _start;
  Offset _stick = Offset.zero;
  double bank = 0;
  double immunity = 0;
  double time = 0;
  double _remainder = 0;
  double _cooldown = 0;
  double _travel = 0;
  double _cycle = 480;
  int _difficulty = 0;
  int _correct = 0;

  final drones = <SpaceDrone>[];
  final rocks = [
    SpaceRock(0, const Offset(32, 205), const Offset(21, 39), 15),
    SpaceRock(1, const Offset(235, 191), const Offset(15, 40), 15),
    SpaceRock(2, const Offset(100, 262), const Offset(-13, 31), 11),
    SpaceRock(3, const Offset(148, 12), const Offset(-11, 36), 10),
    SpaceRock(4, const Offset(321, 304), const Offset(-12, 34), 11),
  ];
  final bolts = <SpaceBolt>[];
  final bursts = <SpaceBurst>[];

  void startWave({
    required List<String> options,
    required int correctIndex,
    required int wave,
  }) {
    RangeError.checkValidIndex(correctIndex, options, 'correctIndex');
    _correct = correctIndex;
    _difficulty = (wave - 1).clamp(0, 4);
    _travel = 0;
    bolts.clear();
    drones
      ..clear()
      ..addAll([
        for (var i = 0; i < options.length; i++)
          SpaceDrone(
            i,
            Size((46.0 + options[i].length * 6).clamp(88, 290), 40),
          ),
      ]);
    _arrange();
    while (rocks.length < 5 + _difficulty ~/ 2) {
      final id = rocks.length;
      final fromLeft = id.isOdd;
      rocks.add(
        SpaceRock(
          id,
          Offset(fromLeft ? 50 : 300, -36),
          Offset(fromLeft ? 28 : -26, 45),
          12,
        ),
      );
    }
  }

  /// The field supplies measured sign dimensions after layout. Shared drift and
  /// a shared wrap distance keep even multi-line signs from overtaking each other.
  void setDroneSizes(List<Size> sizes) {
    if (sizes.length != drones.length) return;
    var changed = false;
    for (var i = 0; i < sizes.length; i++) {
      final size = Size(
        sizes[i].width.clamp(1, 328),
        sizes[i].height.clamp(28, 150),
      );
      if (drones[i]._size != size) {
        drones[i]._size = size;
        changed = true;
      }
    }
    if (changed) _arrange();
  }

  void _arrange() {
    final slot = 350 / drones.length;
    final stacked = drones.any((d) => d.width + 7 > slot);
    var top = 26.0;
    var largest = 0.0;
    for (final d in drones) {
      largest = math.max(largest, d.height);
      d._startY =
          stacked
              ? top + d.height / 2
              : const [103.0, 67.0, 133.0][(d.index + _difficulty) % 3];
      top += d.height + 17;
    }
    _cycle = math.max(worldSize.height + largest + 14, top + 16);
    _positionDrones();
    // A new formation must not charge hull damage at the pilot's existing
    // position. Keep its overlapping craft out until it has safely moved on.
    for (final d in drones) {
      if (_touching(d)) d._hiddenUntil = time + 1;
    }
    _positionDrones();
  }

  void _positionDrones() {
    for (final d in drones) {
      final half = d.width / 2;
      final lane = worldSize.width * (d.index + .5) / drones.length;
      final x = (lane + 6 * math.sin(time * .9)).clamp(
        half + 2,
        worldSize.width - half - 2,
      );
      final y = (d._startY + _travel + d.height / 2) % _cycle - d.height / 2;
      d.position = Offset(x, y);
      d.visible = time >= d._hiddenUntil;
    }
  }

  Offset _inBounds(Offset p) => Offset(
    p.dx.clamp(25, worldSize.width - 25),
    p.dy.clamp(30, worldSize.height - 31),
  );
  void moveTo(Offset position) => _aim = _inBounds(position);
  // Discard overshoot at the boundary, so the very first reverse movement
  // brings the ship back into the field even if the finger kept moving outward.
  void dragBy(Offset delta) => moveTo(_aim + delta);
  void steer(Offset direction) =>
      _stick = direction / math.max(1, direction.distance);
  void stopInput() {
    _aim = ship;
    _stick = Offset.zero;
  }

  bool shoot() {
    if (_cooldown > 1e-8) return false;
    bolts.add(SpaceBolt(ship - const Offset(0, 23)));
    _cooldown = _shotInterval;
    return true;
  }

  /// A bounded catch-up interval prevents a suspended frame from jumping
  /// through the field. Unconsumed substeps survive an answer notification.
  FlightEvent? advance(double seconds, {bool firing = false}) {
    if (!seconds.isFinite || seconds <= 0 || drones.isEmpty) return null;
    _remainder += math.min(.12, seconds);
    while (_remainder + 1e-10 >= _step) {
      _remainder -= _step;
      final event = _tick(firing);
      if (event != null) return event;
    }
    return null;
  }

  FlightEvent? _tick(bool firing) {
    time += _step;
    _cooldown = math.max(0, _cooldown - _step);
    immunity = math.max(0, immunity - _step);
    final before = ship;
    if (_stick != Offset.zero) {
      ship = _inBounds(ship + _stick * (244 * _step));
      _aim = ship;
    } else {
      final delta = _aim - ship;
      final distance = delta.distance;
      if (distance > 0) {
        ship +=
            delta * math.min(1 - math.exp(-26 * _step), 690 * _step / distance);
      }
    }
    final desiredBank = ((ship.dx - before.dx) / _step * .0011).clamp(
      -.25,
      .25,
    );
    bank += (desiredBank - bank) * (1 - math.exp(-17 * _step));
    if (firing) shoot();
    _travel += (23 + _difficulty * 2) * _step;
    _positionDrones();
    for (final r in rocks) {
      final speed = 1 + .09 * _difficulty;
      r.position += (r._velocity * speed + Offset(r._deflection, 0)) * _step;
      r._deflection *= math.exp(-4 * _step);
      r.angle += (r.id.isEven ? -.33 : .43) * _step;
      if (r.position.dx < r.radius && r._velocity.dx < 0 ||
          r.position.dx > worldSize.width - r.radius && r._velocity.dx > 0) {
        r._velocity = Offset(-r._velocity.dx, r._velocity.dy);
        r._deflection = 0;
      }
      if (r.position.dy > worldSize.height + r.radius + 10) _recycle(r);
    }
    for (var i = bursts.length - 1; i >= 0; i--) {
      final b = bursts[i];
      b.progress += _step / .36;
      if (b.progress >= 1) bursts.removeAt(i);
    }
    return _moveBolts() ?? _checkHull();
  }

  void _recycle(SpaceRock r) {
    r._passes++;
    r.position = Offset(
      22.0 + (r.id * 83 + r._passes * 97) % 315,
      -27 - r.id % 3 * 12.0,
    );
    r._deflection = 0;
  }

  FlightEvent? _moveBolts() {
    for (var i = bolts.length - 1; i >= 0; i--) {
      final bolt = bolts[i];
      final before = bolt.position;
      bolt.position = before - const Offset(0, 550 * _step);
      final endY = bolt.position.dy - 3;
      SpaceDrone? drone;
      SpaceRock? rock;
      // Along the swept segment, the largest y enters the bolt's path first.
      var closest = double.negativeInfinity;
      for (final d in drones) {
        if (!d.visible || (d.position.dx - before.dx).abs() > d.width / 2) {
          continue;
        }
        final bottom = d.position.dy + d.height / 2;
        final top = d.position.dy - d.height / 2;
        if (before.dy + 3 >= top && endY <= bottom && bottom > closest) {
          closest = bottom;
          drone = d;
        }
      }
      for (final r in rocks) {
        final dx = before.dx - r.position.dx;
        final radius = r.radius + 2;
        if (dx.abs() > radius) continue;
        final half = math.sqrt(radius * radius - dx * dx);
        final bottom = r.position.dy + half;
        if (before.dy + 3 >= r.position.dy - half &&
            endY <= bottom &&
            bottom > closest) {
          closest = bottom;
          rock = r;
        }
      }
      if (rock != null) {
        bolts.removeAt(i);
        rock._deflection = before.dx < rock.position.dx ? 38 : -38;
        bursts.add(SpaceBurst(bolt.position, SpaceBurstKind.rock));
      } else if (drone != null) {
        bolts.removeAt(i);
        drone._hiddenUntil = double.infinity;
        drone.visible = false;
        bursts.add(
          SpaceBurst(
            drone.position,
            drone.index == _correct
                ? SpaceBurstKind.correct
                : SpaceBurstKind.wrong,
          ),
        );
        return FlightEvent(drone.index);
      } else if (endY < -18) {
        bolts.removeAt(i);
      }
    }
    return null;
  }

  bool _touching(SpaceDrone d) =>
      (ship.dx - d.position.dx).abs() < d.width / 2 + 7 &&
      (ship.dy - d.position.dy).abs() < d.height / 2 + 5;

  FlightEvent? _checkHull() {
    if (immunity > 0) return null;
    for (final r in rocks) {
      final radius = 10 + r.radius;
      if ((ship - r.position).distanceSquared < radius * radius) {
        _recycle(r);
        return _shieldHit();
      }
    }
    for (final d in drones) {
      if (d.visible && _touching(d)) {
        d._hiddenUntil = time + 1.6;
        d.visible = false;
        return _shieldHit();
      }
    }
    return null;
  }

  FlightEvent _shieldHit() {
    immunity = 1.65;
    bursts.add(SpaceBurst(ship, SpaceBurstKind.shield));
    return const FlightEvent(null);
  }
}
