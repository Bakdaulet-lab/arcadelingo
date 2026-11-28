import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'candy_glen_art.dart';
import 'candy_motion.dart';

/// The postcard behind the string is static; only the foreground repaints
/// on a tick. Reset the attempt (and its clock) with a fresh widget key.
class CandyField extends StatefulWidget {
  const CandyField({
    super.key,
    required this.rabbits,
    required this.onLand,
    required this.reducedMotion,
    required this.aim,
    this.aspectRatio = 360 / 292,
    this.onCut,
    this.targetLane,
    this.semanticsLabel,
  }) : assert(aspectRatio > 0);

  final List<int> rabbits;
  final ValueChanged<int?> onLand;
  final VoidCallback? onCut;
  final bool reducedMotion;
  final int aim;
  final double aspectRatio;
  final int? targetLane;
  final String? semanticsLabel;

  @override
  State<CandyField> createState() => CandyFieldState();
}

class CandyFieldState extends State<CandyField>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _scene = _CandyScene();
  late final Ticker _ticker;
  Duration _lastFrame = Duration.zero;
  bool _visible = true;
  late bool _foreground;
  bool _pendingQuietLanding = false;
  int? _pointer;
  Offset _start = Offset.zero;
  Offset _lastPoint = Offset.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _updatePreferences();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible =
        TickerMode.of(context) && (ModalRoute.isCurrentOf(context) ?? true);
    _adjustClock();
  }

  @override
  void didUpdateWidget(CandyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updatePreferences();
    _adjustClock();
  }

  void _updatePreferences() {
    _scene.reducedMotion = widget.reducedMotion;
    _scene.aim = widget.aim;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _adjustClock();
  }

  void _adjustClock() {
    if (_foreground &&
        _visible &&
        _scene.reducedMotion &&
        _scene.flight != null) {
      if (_scene.landed) {
        _scene.finishMotion();
      } else if (!_pendingQuietLanding) {
        // didUpdateWidget can run under a covering route or during a build.
        // Announce the landing only once the game is foreground and laid out.
        _pendingQuietLanding = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pendingQuietLanding = false;
          if (mounted &&
              _foreground &&
              _visible &&
              _scene.reducedMotion &&
              !_scene.landed) {
            _land();
          }
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      }
    }
    final shouldRun =
        _visible && _foreground && !_scene.reducedMotion && !_scene.settled;
    if (!shouldRun) {
      if (_ticker.isActive) _ticker.stop();
      _lastFrame = Duration.zero;
      _clearStroke();
    } else if (!_ticker.isActive) {
      _lastFrame = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    _scene.clock +=
        (elapsed - _lastFrame).inMicroseconds / Duration.microsecondsPerSecond;
    _lastFrame = elapsed;
    final flight = _scene.flight;
    if (flight != null && !_scene.landed && _scene.airTime >= flight.duration) {
      _land();
    }
    if (_scene.settled && _ticker.isActive) _ticker.stop();
    _scene.repaint();
  }

  /// The button and an actual swipe release the exact pose last seen.
  void cut() => _release(.43);

  void _release(double fraction) {
    if (_scene.flight != null || !_foreground || !_visible) return;
    final release = _scene.bob;
    _scene.flight = CandyFlight(release);
    _scene.releasedAt = _scene.clock;
    _scene.cutFraction = fraction;
    _clearStroke();
    widget.onCut?.call();
    if (widget.reducedMotion) _land();
    _scene.repaint();
  }

  void _land() {
    final flight = _scene.flight!;
    if (_scene.reducedMotion) _scene.finishMotion();
    setState(() => _scene.landed = true);
    widget.onLand(flight.lane);
    _scene.repaint();
  }

  Offset _toBoard(Offset local) {
    final size = context.size!;
    return Offset(
      local.dx * CandyMotion.fieldSize.width / size.width,
      local.dy * CandyMotion.fieldSize.height / size.height,
    );
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null ||
        _scene.flight != null ||
        event.buttons != kPrimaryButton) {
      return;
    }
    _pointer = event.pointer;
    _start = _lastPoint = _toBoard(event.localPosition);
    _scene.stroke.add(_start);
  }

  void _move(int pointer, Offset position) {
    if (_pointer != pointer) return;
    final p = _toBoard(position);
    final previous = _lastPoint;
    _lastPoint = p;
    _scene.stroke.add(p);
    if (_scene.stroke.length > 8) _scene.stroke.removeAt(0);
    final end = _scene.bob.position;
    if ((p - _start).distance > 7 && CandyMotion.crosses(previous, p, end)) {
      // Locate the crossing along the actual string, even when one pointer
      // move spans its whole width. A grazing stroke uses its nearest endpoint.
      final rope = end - CandyMotion.pin;
      final movement = p - previous;
      final relative = previous - CandyMotion.pin;
      final denominator = rope.dx * movement.dy - rope.dy * movement.dx;
      final fraction =
          denominator.abs() > .001
              ? (relative.dx * movement.dy - relative.dy * movement.dx) /
                  denominator
              : (relative.dx * rope.dx + relative.dy * rope.dy) /
                  rope.distanceSquared;
      _release(fraction.clamp(.05, .95));
    } else {
      _scene.repaint();
    }
  }

  void _clearStroke() {
    _pointer = null;
    if (_scene.stroke.isEmpty) return;
    _scene.stroke.clear();
    _scene.repaint();
  }

  @override
  Widget build(BuildContext context) {
    final day = Theme.of(context).brightness == Brightness.light;
    final lane = _scene.landed ? _scene.flight?.lane : null;
    return Semantics(
      image: true,
      label: widget.semanticsLabel,
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerMove: (event) => _move(event.pointer, event.localPosition),
            onPointerUp: (event) {
              if (_pointer != event.pointer) return;
              _move(event.pointer, event.localPosition);
              _clearStroke();
            },
            onPointerCancel: (event) {
              if (_pointer == event.pointer) _clearStroke();
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                CandyGlenArt(
                  day: day,
                  rabbits: widget.rabbits,
                  happyLane: lane == widget.targetLane ? lane : null,
                ),
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _CandyPainter(_scene, day, widget.targetLane),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _scene.dispose();
    super.dispose();
  }
}

class _CandyScene extends ChangeNotifier {
  double clock = .87;
  double releasedAt = 0;
  double cutFraction = .43;
  bool reducedMotion = false;
  bool landed = false;
  int aim = 0;
  final List<Offset> stroke = [];
  CandyFlight? flight;

  CandyPose get bob =>
      reducedMotion ? CandyMotion.still(aim) : CandyMotion.swing(clock);
  double get airTime => clock - releasedAt;
  double get afterImpact =>
      reducedMotion ? 1 : math.max(0, airTime - flight!.duration);
  bool get settled => landed && afterImpact >= .55;

  // Remember the final clock too: re-enabling motion must never rewind a
  // delivered candy to its release position.
  void finishMotion() => clock = releasedAt + flight!.duration + .56;

  void repaint() => notifyListeners();
}

class _CandyPainter extends CustomPainter {
  _CandyPainter(this.scene, this.day, this.targetLane) : super(repaint: scene);
  final _CandyScene scene;
  final bool day;
  final int? targetLane;

  static final _wrapper =
      Path()
        ..moveTo(12, -3)
        ..lineTo(23, -10)
        ..quadraticBezierTo(26, -11, 25, -7)
        ..lineTo(24, -2)
        ..lineTo(27, 2)
        ..lineTo(23, 4)
        ..lineTo(23, 9)
        ..lineTo(12, 4)
        ..close();
  static final _folds =
      Path()
        ..moveTo(13, 1)
        ..lineTo(22, -4)
        ..moveTo(14, 2)
        ..lineTo(22, 5);
  static final _swirl =
      Path()
        ..moveTo(.7, .1)
        ..cubicTo(7, -1, 11, -9, 12, -17)
        ..lineTo(21, -5)
        ..cubicTo(13, -6, 7, 5, .7, .1)
        ..close();
  static final _disk = Path()..addOval(const Rect.fromLTWH(-16, -16, 32, 32));
  static final _spark =
      Path()
        ..moveTo(0, -1)
        ..quadraticBezierTo(.12, -.12, .8, 0)
        ..quadraticBezierTo(.12, .12, 0, 1)
        ..quadraticBezierTo(-.12, .12, -.8, 0)
        ..quadraticBezierTo(-.12, -.12, 0, -1);
  static const _edge = Color(0xff663849);
  static const _cream = Color(0xfffff0c2);

  Paint _fill(Color c) => Paint()..color = c;
  Paint _stroke(Color c, double width) =>
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;

  void _cord(Canvas c, Offset a, Offset b) {
    final delta = b - a;
    final length = delta.distance;
    if (length < .01) return;
    c.drawLine(
      a,
      b,
      _stroke(day ? const Color(0xff715035) : const Color(0xff604854), 4.6),
    );
    c.drawLine(
      a,
      b,
      _stroke(day ? const Color(0xffc89555) : const Color(0xffdfb981), 2.8),
    );
    final thread = _stroke(const Color(0xffffe7ad), 1.4);
    final tangent = delta / length;
    final normal = Offset(-tangent.dy, tangent.dx) * .65;
    for (var d = 1.0; d + 2 < length; d += 5.8) {
      c.drawLine(
        a + tangent * d - normal,
        a + tangent * (d + 2) + normal,
        thread,
      );
    }
  }

  void _sweet(Canvas c, Offset center, double angle, double scale) {
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(angle);
    c.scale(scale);
    final berry = day ? const Color(0xffc73f60) : const Color(0xffe05b84);
    for (final sign in const [-1.0, 1.0]) {
      c.save();
      c.scale(sign, 1);
      c.drawPath(_wrapper, _fill(const Color(0xffff95a6)));
      c.drawPath(_wrapper, _stroke(_edge, 1.3));
      c.drawPath(_folds, _stroke(berry, 1.1));
      c.restore();
    }
    c.drawPath(_disk, _fill(_cream));
    c.save();
    c.clipPath(_disk);
    for (var i = 0; i < 5; i++) {
      c.drawPath(_swirl, _fill(berry));
      c.rotate(math.pi * 2 / 5);
    }
    c.restore();
    c.drawPath(_disk, _stroke(_edge, 1.5));
    c.drawOval(
      const Rect.fromLTWH(-9.8, -9.7, 7.6, 3.4),
      _fill(const Color(0xc0ffffff)),
    );
    c.restore();
  }

  @override
  void paint(Canvas c, Size size) {
    if (size.isEmpty) return;
    final unit = size.width / CandyMotion.fieldSize.width;
    final vertical = size.height / (CandyMotion.fieldSize.height * unit);
    // The sky grows taller, not the lollipop: place marks on the taller
    // trajectory, but paint their radii, angle and outlines at one scale.
    Offset place(Offset point) => Offset(point.dx, point.dy * vertical);
    c.save();
    c.scale(unit);
    const pin = CandyMotion.pin;
    final flight = scene.flight;
    late Offset center;
    late double rotation;
    var scale = 1.0;
    if (flight == null) {
      final pose = scene.bob;
      center = pose.position;
      rotation = _tilt(center);
      _cord(c, place(pin), place(center));
      for (var i = 1; i <= 3; i++) {
        final t = i * .105;
        final mark =
            center +
            pose.velocity * t +
            Offset(0, .5 * CandyFlight.gravity * t * t);
        c.drawCircle(
          place(mark),
          2 - .19 * i,
          _fill(day ? const Color(0x9bfff4d0) : const Color(0x9bfff0c6)),
        );
      }
    } else {
      final t = scene.reducedMotion ? flight.duration : scene.airTime;
      final atRelease = flight.release.position;
      final cutPoint = Offset.lerp(pin, atRelease, scene.cutFraction)!;
      final recoil = Curves.easeOutCubic.transform((t / .28).clamp(0.0, 1.0));
      final looseEnd =
          Offset.lerp(
            cutPoint,
            Offset(
              pin.dx + (cutPoint.dx - pin.dx) * .22,
              pin.dy + (cutPoint - pin).distance * .82,
            ),
            recoil,
          )!;
      _cord(c, place(pin), place(looseEnd));
      center = flight.at(t);
      rotation =
          _tilt(atRelease) +
          t.clamp(0.0, flight.duration) * (flight.release.velocity.dx / 50);
      if (t < .17) {
        final tail = (cutPoint - atRelease) * (1 - t / .17);
        _cord(c, place(center), place(center + tail));
      }
      if (!scene.landed) {
        for (var i = 5; i >= 1; i--) {
          final past = t - i * .026;
          if (past > 0) {
            c.drawCircle(
              place(flight.at(past)),
              3 - i * .35,
              _fill(day ? const Color(0x88ffb59c) : const Color(0x8cffe2c5)),
            );
          }
        }
      } else {
        final settle = Curves.easeOutCubic.transform(
          (scene.afterImpact / .3).clamp(0.0, 1.0),
        );
        final lane = flight.lane;
        final end = Offset(
          lane == null ? center.dx.clamp(14.0, 346.0) : CandyMotion.lanes[lane],
          lane == null ? 260 : 250,
        );
        center = Offset.lerp(center, end, settle)!;
        scale = 1 - .44 * settle;
        rotation += (.35 - rotation) * settle;
        if (lane != null && lane == targetLane) {
          final spread = (scene.afterImpact / .48).clamp(0.0, 1.0);
          for (var i = 0; i < 5; i++) {
            final a = math.pi * (1.05 + i * .23);
            c.save();
            c.translate(
              end.dx + math.cos(a) * (20 + 17 * spread),
              221 * vertical + math.sin(a) * (18 + 15 * spread),
            );
            c.scale((2.4 + (i % 2) * 1.5) * Curves.easeOut.transform(spread));
            c.drawPath(
              _spark,
              _fill(day ? const Color(0xffbd6636) : const Color(0xffffe798)),
            );
            c.restore();
          }
        }
      }
    }
    c.drawCircle(
      place(pin),
      5,
      _fill(day ? const Color(0xff744934) : const Color(0xff554052)),
    );
    c.drawCircle(
      place(pin) - const Offset(0, 1),
      2.7,
      _fill(const Color(0xffffdc96)),
    );
    _sweet(c, place(center), rotation, scale);
    if (scene.stroke.length > 1) {
      final points = scene.stroke;
      final path = Path()..moveTo(points.first.dx, points.first.dy * vertical);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy * vertical);
      }
      c.drawPath(
        path,
        _stroke(day ? const Color(0xccfff4c3) : const Color(0xccbafbe5), 3),
      );
    }
    c.restore();
  }

  double _tilt(Offset center) => -.15 + .002 * (center.dx - CandyMotion.pin.dx);

  @override
  bool shouldRepaint(_CandyPainter oldDelegate) =>
      day != oldDelegate.day ||
      scene != oldDelegate.scene ||
      targetLane != oldDelegate.targetLane ||
      scene.reducedMotion;
}
