import 'dart:ui';

import 'package:arcadelingo/features/games/space_word/space_flight.dart';
import 'package:flutter_test/flutter_test.dart';

SpaceFlight flight({int correct = 1}) =>
    SpaceFlight()
      ..startWave(options: ['nube', 'sol', 'luna'], correctIndex: correct, wave: 1);

List<FlightEvent> frames(SpaceFlight game, int count, {int fps = 60, bool firing = false}) {
  final events = <FlightEvent>[];
  for (var i = 0; i < count; i++) {
    final event = game.advance(1 / fps, firing: firing);
    if (event != null) events.add(event);
  }
  return events;
}

void main() {
  test('relative drag starts on the next frame, reaches every quadrant, and stops cleanly', () {
    final game = flight();
    final start = game.ship;
    game.moveTo(const Offset(36, 39));
    game.advance(1 / 60);
    expect(game.ship.dx, lessThan(start.dx));
    expect(game.ship.dy, lessThan(start.dy));
    expect((game.ship - start).distance, lessThan(30));
    frames(game, 70);
    expect((game.ship - const Offset(36, 39)).distance, lessThan(.5));
    game.steer(const Offset(1, 1));
    frames(game, 12);
    final beforeRelease = game.ship;
    game.stopInput();
    frames(game, 12);
    expect(game.ship, beforeRelease);
    game.moveTo(const Offset(500, 500));
    frames(game, 100);
    expect(game.ship.dx, inInclusiveRange(330, 345));
    expect(game.ship.dy, inInclusiveRange(382, 403));
  });

  test('the same input gives the same position and cooldown at 30, 60 and 120 Hz', () {
    final games = [for (final fps in [30, 60, 120]) flight()..steer(const Offset(.3, -.8))];
    for (final (i, fps) in [30, 60, 120].indexed) {
      frames(games[i], fps ~/ 2, fps: fps, firing: true);
    }
    for (final candidate in games.skip(1)) {
      expect((candidate.ship - games.first.ship).distance, lessThan(.005));
      expect(candidate.bolts.length, games.first.bolts.length);
      expect(candidate.bolts.length, greaterThan(0));
      expect((candidate.bolts.last.position - games.first.bolts.last.position).distance, lessThan(.005));
    }
  });

  test('a shot travels from the nose before it hits, and reports a target once', () {
    for (final correct in [1, 2]) {
      final game = flight(correct: correct);
      expect(game.shoot(), isTrue);
      expect(game.shoot(), isFalse);
      final muzzle = game.bolts.single.position;
      expect(muzzle.dx, game.ship.dx);
      expect(muzzle.dy, lessThan(game.ship.dy));
      expect(frames(game, 4), isEmpty);
      expect(game.bolts.single.position.dy, lessThan(muzzle.dy - 15));
      final events = frames(game, 56, firing: true);
      expect(events.where((e) => e.index == 1), hasLength(1));
      expect(game.drones[1].visible, isFalse);
    }
  });

  test('avoiding a passing rock costs nothing, contact costs a single shield', () {
    final safe = flight();
    final danger = flight();
    final obstacle = danger.rocks.first;
    danger.moveTo(obstacle.position);
    final safeEvents = frames(safe, 64);
    final hitEvents = frames(danger, 64);
    expect(safeEvents.where((e) => e.index == null), isEmpty);
    expect(hitEvents.where((e) => e.index == null), hasLength(1));
    expect(danger.immunity, greaterThan(0));
  });

  test('larger waves retain the pilot and add hazards beyond the playfield', () {
    final game = flight();
    game.steer(const Offset(-1, 0));
    frames(game, 12);
    final before = game.ship;
    final original = game.rocks.map((r) => r.position).toList();
    game.startWave(options: ['book', 'door'], correctIndex: 0, wave: 3);
    expect(game.ship, before);
    expect(game.rocks.take(original.length).map((r) => r.position), original);
    expect(game.rocks.length, original.length+1);
    expect(game.rocks.last.position.dy, lessThan(0));
    expect(game.drones.map((d) => d.index), [0,1]);
  });

  test('wide word labels stay on screen horizontally and do not overlap while descending', () {
    final game = flight();
    game.setDroneSizes(const [Size(245, 66), Size(267, 66), Size(216, 66)]);
    for (var i=0;i<950;i++) {
      final visible = game.drones.where((d) => d.visible).toList();
      for (final (j, d) in visible.indexed) {
        final rect = Rect.fromCenter(center:d.position, width:d.width, height:d.height);
        expect(rect.left,greaterThanOrEqualTo(0));
        expect(rect.right,lessThanOrEqualTo(360));
        for(final other in visible.skip(j+1)) {
          expect(rect.overlaps(Rect.fromCenter(center:other.position,width:other.width,height:other.height)),isFalse);
        }
      }
      game.advance(1/60);
    }
  });
}
