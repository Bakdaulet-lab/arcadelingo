import 'dart:math' as math;
import 'dart:ui';

class CandyPose {
  const CandyPose(this.position, this.velocity);
  final Offset position;
  final Offset velocity;
}

abstract final class CandyMotion {
  static const pin = Offset(180, 23);
  static const fieldSize = Size(360, 292);
  static const lanes = [64.0, 180.0, 296.0];
  static const catchY = 223.0;
  static const _length = 104.0;
  static const _amplitude = .79;
  static const _speed = 1.41;

  static CandyPose swing(double seconds) {
    final phase = seconds * _speed;
    final angle = _amplitude * math.sin(phase);
    final angularSpeed = _amplitude * _speed * math.cos(phase);
    final sinAngle = math.sin(angle);
    final cosAngle = math.cos(angle);
    return CandyPose(
      pin + Offset(sinAngle, cosAngle) * _length,
      Offset(cosAngle, -sinAngle) * (_length * angularSpeed),
    );
  }

  static CandyPose still(int aim) => CandyPose(
    pin + const Offset(0, _length),
    Offset(aim.clamp(-1, 1) * 152.0, 0),
  );

  /// Compare whole finger segments: a fast swipe may deliver just two samples.
  static bool crosses(Offset start, Offset end, Offset bob) {
    final rope = bob - pin;
    final stroke = end - start;
    double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
    if (cross(stroke, pin - start) * cross(stroke, bob - start) < 0 &&
        cross(rope, start - pin) * cross(rope, end - pin) < 0) {
      return true;
    }
    const toleranceSquared = 36.0;
    return _distanceSquared(start, pin, bob) <= toleranceSquared ||
        _distanceSquared(end, pin, bob) <= toleranceSquared ||
        _distanceSquared(pin, start, end) <= toleranceSquared ||
        _distanceSquared(bob, start, end) <= toleranceSquared;
  }

  static double _distanceSquared(Offset point, Offset start, Offset end) {
    final delta = end - start;
    final relative = point - start;
    if (delta.distanceSquared == 0) return relative.distanceSquared;
    final dot = relative.dx * delta.dx + relative.dy * delta.dy;
    final t = (dot / delta.distanceSquared).clamp(0.0, 1.0);
    return (relative - delta * t).distanceSquared;
  }
}

class CandyFlight {
  CandyFlight(this.release);

  static const gravity = 350.0;
  final CandyPose release;

  late final double duration =
      (-release.velocity.dy +
          math.sqrt(
            release.velocity.dy * release.velocity.dy +
                2 * gravity * (CandyMotion.catchY - release.position.dy),
          )) /
      gravity;

  Offset at(double seconds) {
    final t = seconds.clamp(0.0, duration);
    return release.position +
        release.velocity * t +
        Offset(0, gravity * t * t / 2);
  }

  late final int? lane = _catchLane(at(duration).dx);

  static int? _catchLane(double x) {
    for (var i = 0; i < CandyMotion.lanes.length; i++) {
      if ((CandyMotion.lanes[i] - x).abs() <= 38) return i;
    }
    return null;
  }
}
