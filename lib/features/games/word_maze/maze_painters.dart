part of 'maze_field.dart';

// Artwork uses cell coordinates. Transforming the canvas once keeps every
// position, turn and gate aligned at any phone size.
void _scaleBoard(Canvas canvas, Size size) =>
    canvas.scale(size.width / MazeRun.columns, size.height / MazeRun.rows);

Paint _fill(Color color) => Paint()..color = color;
Paint _line(Color color, double width) =>
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width;

typedef _GateInk = ({Color fill, Color type});
const _nightGates = [
  (fill: Color(0xFF6DEDD6), type: Color(0xFF06352F)),
  (fill: Color(0xFFFFD079), type: Color(0xFF432707)),
  (fill: Color(0xFFD9B6FF), type: Color(0xFF3F205A)),
];
const _paperGates = [
  (fill: Color(0xFF216B64), type: Color(0xFFFFFBED)),
  (fill: Color(0xFF935015), type: Color(0xFFFFFAE9)),
  (fill: Color(0xFF735184), type: Color(0xFFFFF8FF)),
];
_GateInk _gateInk(int index, bool dark) =>
    (dark ? _nightGates : _paperGates)[index];

// Lay out text in normal font units, then paint into the cell-space canvas.
const _fontUnits = 32.0;
TextPainter _type(String value, double height, Color color) => TextPainter(
  text: TextSpan(
    text: value,
    style: TextStyle(
      fontFamily: wordarcadeFont,
      fontSize: height * _fontUnits,
      height: 1,
      fontWeight: FontWeight.w700,
      fontVariations: const [FontVariation('wght', 680)],
      color: color,
    ),
  ),
  textDirection: TextDirection.ltr,
  maxLines: 1,
)..layout();

void _centerText(Canvas canvas, TextPainter text, Offset at) {
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.scale(1 / _fontUnits);
  text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
  canvas.restore();
}

Path _seal(int index, double r) {
  final rect = Rect.fromCircle(center: Offset.zero, radius: r);
  return switch (index) {
    0 => Path()..addOval(rect),
    1 =>
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r * .42))),
    _ =>
      Path()
        ..moveTo(0, -r)
        ..lineTo(r * .91, -r * .52)
        ..lineTo(r * .91, r * .52)
        ..lineTo(0, r)
        ..lineTo(-r * .91, r * .52)
        ..lineTo(-r * .91, -r * .52)
        ..close(),
  };
}

void _drawSeal(
  Canvas canvas,
  int index,
  bool dark,
  Offset center,
  double radius,
) {
  final colors = _gateInk(index, dark);
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.drawPath(_seal(index, radius), _fill(colors.fill));
  canvas.drawPath(
    _seal(index, radius * .82),
    _line(colors.type.withValues(alpha: .24), radius * .065),
  );
  final number = _type('${index + 1}', radius * 1.25, colors.type);
  _centerText(canvas, number, Offset.zero);
  number.dispose();
  canvas.restore();
}

class _BadgePainter extends CustomPainter {
  _BadgePainter(this.index, this.dark);
  final int index;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width, size.height);
    _drawSeal(canvas, index, dark, const Offset(.5, .5), .49);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BadgePainter old) =>
      index != old.index || dark != old.dark;
}

class _SceneryPainter extends CustomPainter {
  _SceneryPainter({
    required this.run,
    required this.dark,
    required this.labels,
    required this.textScale,
  }) : gateWave = run.gateWave;
  final MazeRun run;
  final bool dark;
  final List<String> labels;
  final int gateWave;
  final double textScale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    _scaleBoard(canvas, size);
    final rect = Rect.fromLTWH(
      0,
      0,
      MazeRun.columns.toDouble(),
      MazeRun.rows.toDouble(),
    );
    final floor =
        dark
            ? const [Color(0xFF15202E), Color(0xFF151724), Color(0xFF0E1520)]
            : const [Color(0xFFFBF3DC), Color(0xFFF6EBD5), Color(0xFFE9D9BD)];
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: floor,
        ).createShader(rect),
    );
    _walls(canvas);
    final readableSign = .50 * textScale * size.width / MazeRun.columns >= 14;
    for (var i = 0; i < run.gates.length; i++) {
      final cell = run.gates[i];
      final center = Offset(cell.x + .5, cell.y + .5);
      final ink = _gateInk(i, dark);
      // The top rail has room for short signs. Inner gates use just the
      // matching seal so a leader line never hides a route across the board.
      if (readableSign &&
          i < labels.length &&
          (cell.y == 1 ||
              (cell.y == 3 &&
                  (cell.x <= 2 || cell.x >= MazeRun.columns - 3)))) {
        _label(canvas, labels[i], center, ink);
      }
      canvas.drawCircle(
        center,
        .48,
        _fill(ink.fill.withValues(alpha: dark ? .2 : .12)),
      );
      _drawSeal(canvas, i, dark, center, .44);
    }
    final frameColor = dark ? const Color(0xFF536073) : const Color(0xFF9B8062);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(.025), const Radius.circular(.56)),
      _line(frameColor.withValues(alpha: .72), .055),
    );
    canvas.restore();
  }

  void _walls(Canvas canvas) {
    final network = Path();
    final pillars = Path();
    for (var y = 0; y < MazeRun.rows; y++) {
      for (var x = 0; x < MazeRun.columns; x++) {
        if (!run.isWall(x, y)) continue;
        final c = Offset(x + .5, y + .5);
        if (x + 1 < MazeRun.columns && run.isWall(x + 1, y)) {
          network
            ..moveTo(c.dx, c.dy)
            ..relativeLineTo(1, 0);
        }
        if (y + 1 < MazeRun.rows && run.isWall(x, y + 1)) {
          network
            ..moveTo(c.dx, c.dy)
            ..relativeLineTo(0, 1);
        }
        if (MazeDirection.values.every(
          (d) => !run.isWall(x + d.dx, y + d.dy),
        )) {
          pillars.addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: c, width: .57, height: .57),
              const Radius.circular(.16),
            ),
          );
        }
      }
    }
    final rim = dark ? const Color(0xFF4D7989) : const Color(0xFFAD9070);
    final enamel = dark ? const Color(0xFF273E55) : const Color(0xFFD9C4A5);
    final glint = dark ? const Color(0xFF487385) : const Color(0xFFEAD9BB);
    canvas.save();
    canvas.translate(0, .075);
    canvas.drawPath(
      network,
      _line(dark ? const Color(0xFF0C111D) : const Color(0xFFCBB595), .71),
    );
    canvas.restore();
    canvas.drawPath(network, _line(rim, .66));
    canvas.drawPath(network, _line(enamel, .54));
    canvas.drawPath(pillars, _fill(enamel));
    canvas.drawPath(pillars, _line(rim, .075));
    canvas.save();
    canvas.translate(-.04, -.07);
    canvas.drawPath(network, _line(glint, .072));
    canvas.restore();
  }

  void _label(Canvas canvas, String word, Offset gate, _GateInk ink) {
    // The entire upper rail is a wall. Short signs fit there without masking
    // a walkable cell. Every full label is also shown in the accessible HUD.
    if (word.isEmpty || word.length > 24 || word.contains('\n')) return;
    final text = _type(word, .50 * textScale, ink.fill);
    final width = text.width / _fontUnits + .48;
    final height = text.height / _fontUnits + .16;
    if (width <= 3.83 && height <= .83) {
      final boardWidth = MazeRun.columns.toDouble();
      final x = gate.dx.clamp(.23 + width / 2, boardWidth - .23 - width / 2);
      final center = Offset(x, .5);
      final box = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: width, height: height),
        const Radius.circular(.18),
      );
      final wire = Path()..moveTo(x, .5);
      if (gate.dy > 2) {
        final rail = gate.dx < boardWidth / 2 ? .52 : boardWidth - .52;
        wire
          ..lineTo(rail, .5)
          ..lineTo(rail, gate.dy);
      }
      wire.lineTo(gate.dx, gate.dy);
      canvas.drawPath(wire, _line(ink.fill.withValues(alpha: .75), .068));
      canvas.drawRRect(
        box,
        _fill(dark ? const Color(0xFF14232A) : const Color(0xFFFEF7E7)),
      );
      canvas.drawRRect(box, _line(ink.fill.withValues(alpha: .85), .042));
      _centerText(canvas, text, center);
    }
    text.dispose();
  }

  @override
  bool shouldRepaint(_SceneryPainter old) =>
      run != old.run ||
      gateWave != old.gateWave ||
      dark != old.dark ||
      textScale != old.textScale ||
      !listEquals(labels, old.labels);
}

class _RunnerHeading {
  double? _target;
  double _from = 0;
  double _turnedAt = 0;

  double at(MazeRun run, bool reduced) {
    final target = switch (run.facing) {
      MazeDirection.right => 0.0,
      MazeDirection.down => math.pi / 2,
      MazeDirection.left => math.pi,
      MazeDirection.up => -math.pi / 2,
    };
    final now = run.elapsedSeconds;
    if (_target == null || reduced || now < _turnedAt) {
      _target = _from = target;
      _turnedAt = now;
      return target;
    }
    if (_target != target) {
      _from = _value(now);
      _target = target;
      _turnedAt = now;
    }
    return _value(now);
  }

  double _value(double now) {
    final progress = ((now - _turnedAt) / .075).clamp(0.0, 1.0);
    final delta = _target! - _from;
    final shortest = math.atan2(math.sin(delta), math.cos(delta));
    return _from + shortest * (1 - (1 - progress) * (1 - progress));
  }
}

class _RunnerPainter extends CustomPainter {
  _RunnerPainter({
    required this.run,
    required this.dark,
    required this.reduced,
    required this.heading,
    required this.frames,
  }) : super(repaint: frames);
  final MazeRun run;
  final bool dark, reduced;
  final _RunnerHeading heading;
  final Listenable frames;
  int _cachedCount = -1;
  late Path _dots;
  Offset _pickup = Offset.zero;
  double _pickedAt = double.negativeInfinity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    _scaleBoard(canvas, size);
    final pellet = dark ? const Color(0xFFFFD797) : const Color(0xFF95612E);
    if (_cachedCount != run.collected) {
      if (_cachedCount >= 0) {
        _pickup = Offset(run.player.x.round() + .5, run.player.y.round() + .5);
        _pickedAt = run.elapsedSeconds;
      }
      final dots = Path();
      for (final p in run.pellets) {
        dots.addOval(
          Rect.fromCircle(center: Offset(p.x + .5, p.y + .5), radius: .099),
        );
      }
      _dots = dots;
      _cachedCount = run.collected;
    }
    canvas.drawPath(_dots, _fill(pellet));
    final progress = (run.elapsedSeconds - _pickedAt) / .18;
    if (!reduced && progress < 1) {
      final radius = .23 + .32 * progress;
      final spark = _line(pellet.withValues(alpha: .83 * (1 - progress)), .058);
      for (final vector in const [
        Offset(.7, .7),
        Offset(-.7, .7),
        Offset(.7, -.7),
        Offset(-.7, -.7),
      ]) {
        canvas.drawLine(
          _pickup + vector * radius,
          _pickup + vector * (radius + .08),
          spark,
        );
      }
    }
    var i = 0;
    for (final ghost in run.ghosts) {
      _sentinel(canvas, Offset(ghost.x + .5, ghost.y + .5), i++);
    }
    final p = run.player;
    _runner(canvas, Offset(p.x + .5, p.y + .5));
    canvas.restore();
  }

  void _runner(Canvas canvas, Offset position) {
    final core = dark ? const Color(0xFF9CFFE2) : const Color(0xFFC56B38);
    final outline = dark ? const Color(0xFF165E54) : const Color(0xFF75452D);
    final visor = dark ? const Color(0xFF14454B) : const Color(0xFF51372B);
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(heading.at(run, reduced));
    if (run.protected) {
      canvas.drawCircle(
        Offset.zero,
        .47,
        _line(core.withValues(alpha: .55), .045),
      );
    }
    if (run.moving && !reduced) {
      canvas.drawLine(
        const Offset(-.36, -.095),
        const Offset(-.62, -.095),
        _line(core.withValues(alpha: .43), .072),
      );
      canvas.drawLine(
        const Offset(-.36, .095),
        const Offset(-.50, .095),
        _line(core.withValues(alpha: .33), .053),
      );
    }
    final hull =
        Path()
          ..moveTo(.42, 0)
          ..quadraticBezierTo(.25, -.36, -.19, -.33)
          ..quadraticBezierTo(-.40, -.31, -.35, -.16)
          ..lineTo(-.28, 0)
          ..lineTo(-.35, .16)
          ..quadraticBezierTo(-.40, .31, -.19, .33)
          ..quadraticBezierTo(.25, .36, .42, 0)
          ..close();
    canvas.drawPath(hull, _fill(core));
    canvas.drawPath(hull, _line(outline, .065));
    final glass =
        Path()
          ..moveTo(.08, -.22)
          ..quadraticBezierTo(.24, -.18, .31, 0)
          ..quadraticBezierTo(.24, .18, .08, .22)
          ..quadraticBezierTo(.16, 0, .08, -.22)
          ..close();
    canvas.drawPath(glass, _fill(visor));
    canvas.drawLine(
      const Offset(-.19, -.18),
      const Offset(-.02, -.15),
      _line(const Color(0xFFFFFADE), .055),
    );
    canvas.restore();
  }

  void _sentinel(Canvas canvas, Offset position, int index) {
    final bob =
        reduced ? 0.0 : math.sin(run.elapsedSeconds * 4.3 + index * 1.7) * .038;
    final body = switch (index) {
      0 => dark ? const Color(0xFFFC81A4) : const Color(0xFFA93E52),
      1 => dark ? const Color(0xFFFFAA6C) : const Color(0xFFAB5A27),
      _ => dark ? const Color(0xFFB894ED) : const Color(0xFF775899),
    };
    final rim = dark ? const Color(0xFF6D314B) : const Color(0xFF713648);
    final glass = dark ? const Color(0xFF391C39) : const Color(0xFF552C3C);
    canvas.save();
    canvas.translate(position.dx, position.dy + bob);
    final armor =
        Path()
          ..moveTo(0, -.39)
          ..lineTo(.27, -.23)
          ..quadraticBezierTo(.43, -.1, .32, .15)
          ..lineTo(.15, .32)
          ..lineTo(0, .24)
          ..lineTo(-.15, .32)
          ..lineTo(-.32, .15)
          ..quadraticBezierTo(-.43, -.10, -.27, -.23)
          ..close();
    canvas.drawPath(armor, _fill(body));
    canvas.drawPath(armor, _line(rim, .055));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-.245, -.12, .245, .10),
        const Radius.circular(.1),
      ),
      _fill(glass),
    );
    final p = run.player;
    final gaze = (p.x + .5 - position.dx).clamp(-1.0, 1.0) * .06;
    canvas.drawCircle(
      Offset(gaze, -.014),
      .066,
      _fill(const Color(0xFFFFF2C7)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RunnerPainter old) =>
      run != old.run ||
      frames != old.frames ||
      dark != old.dark ||
      reduced != old.reduced;
}
