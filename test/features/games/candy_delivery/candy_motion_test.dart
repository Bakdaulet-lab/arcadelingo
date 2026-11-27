import 'dart:ui';

import 'package:arcadelingo/features/games/candy_delivery/candy_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release keeps both the position and the full tangent velocity', () {
    const dt = .00001;
    for (final t in [.1, .62, 1.2, 2.0, 2.8, 4.6]) {
      final bob = CandyMotion.swing(t);
      final next = CandyMotion.swing(t + dt);
      final rope = bob.position - CandyMotion.pin;
      final flight = CandyFlight(bob);
      expect(rope.distance, closeTo(104, .0001));
      expect(flight.at(0), bob.position);
      expect((flight.at(dt) - next.position).distance / dt, lessThan(.02));
      expect(
        rope.dx * bob.velocity.dx + rope.dy * bob.velocity.dy,
        closeTo(0, 1e-7),
      );
    }
  });

  test('ballistic flight and landing are independent of frame cadence', () {
    final hitLanes = <int?>{};
    for (var tick = 0; tick <= 250; tick++) {
      final bob = CandyMotion.swing(tick / 50);
      final shot = CandyFlight(bob);
      final half = shot.duration / 2;
      expect(
        shot.at(half).dx,
        closeTo(bob.position.dx + bob.velocity.dx * half, 1e-7),
      );
      expect(
        shot.at(half).dy,
        closeTo(
          bob.position.dy + bob.velocity.dy * half + 175 * half * half,
          1e-7,
        ),
      );
      expect(shot.at(shot.duration).dy, closeTo(223, 1e-8));
      expect(shot.at(shot.duration + .13), shot.at(shot.duration));
      hitLanes.add(shot.lane);
    }
    expect(hitLanes, {null, 0, 1, 2});
    for (final aim in [-1, 0, 1]) {
      expect(CandyFlight(CandyMotion.still(aim)).lane, aim + 1);
    }
  });

  test('a sparse diagonal swipe cuts the rope, a distant stroke misses', () {
    const bob = Offset(218, 120);
    expect(
      CandyMotion.crosses(const Offset(120, 85), const Offset(270, 69), bob),
      isTrue,
    );
    expect(
      CandyMotion.crosses(const Offset(60, 50), const Offset(110, 80), bob),
      isFalse,
    );
    expect(
      CandyMotion.crosses(const Offset(50, 260), const Offset(280, 260), bob),
      isFalse,
    );
  });
}
