import 'dart:math' as math;

import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

abstract final class ClawKeys {
  static const prompt = Key('claw.prompt');
  static const slots = Key('claw.slots');
  static const left = Key('claw.left');
  static const right = Key('claw.right');
  static const grab = Key('claw.grab');
  static const hint = Key('claw.hint');
  static const next = Key('claw.next');
  static const result = Key('claw.result');
  static const summary = Key('claw.summary');
  static Key topCapsule(int column) => ValueKey('claw.capsule.$column');
}

/// Стекло, капсулы и клешня рисуются друг над другом, чтобы захваченная
/// капсула двигалась вместе с клешнёй, а свободные оставались на полке.
class ClawMachineField extends StatelessWidget {
  const ClawMachineField({
    required this.stacks,
    required this.column,
    required this.hintedColumn,
    required this.motion,
    required this.capturing,
    required this.reducedMotion,
    required this.refillColumn,
    required this.refillSerial,
    required this.onAim,
    super.key,
  });

  final List<List<String>> stacks;
  final int column;
  final int? hintedColumn;
  final Animation<double> motion;
  final bool capturing;
  final bool reducedMotion;
  final int? refillColumn;
  final int refillSerial;
  final ValueChanged<int>? onAim;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: .93,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final paper = Theme.of(context).brightness == Brightness.light;
          final size = constraints.biggest;
          final spacing = (size.width - 24) / stacks.length;
          final diameter = spacing - 3;
          final scale = (size.width / 330).clamp(.7, 1.15);

          Offset capsuleCenter(int lane, int height) => Offset(
            12 + spacing * (lane + .5),
            size.height - 23 - diameter * (.5 + height * .84) - (lane % 3) * 4,
          );

          void aimAt(double x) {
            final lane = ((x - 12) / spacing).floor().clamp(
              0,
              stacks.length - 1,
            );
            onAim?.call(lane);
          }

          final pile = [
            for (final (lane, stack) in stacks.indexed)
              for (final (height, letter) in stack.indexed)
                (
                  captured: lane == column && height == stack.length - 1,
                  view: _placeCapsule(
                    key: ValueKey((lane, height)),
                    center: capsuleCenter(lane, height),
                    diameter: diameter,
                    dropId:
                        !reducedMotion &&
                                lane == refillColumn &&
                                height == stack.length - 1
                            ? refillSerial
                            : null,
                    child: _Capsule(
                      letter: letter,
                      lane: lane,
                      covered: height < stack.length - 1,
                      selected: lane == column && height == stack.length - 1,
                      hinted:
                          lane == hintedColumn && height == stack.length - 1,
                      onTap:
                          height == stack.length - 1 && onAim != null
                              ? () => onAim!(lane)
                              : null,
                      key:
                          height == stack.length - 1
                              ? ClawKeys.topCapsule(lane)
                              : null,
                    ),
                  ),
                ),
          ];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart:
                onAim == null
                    ? null
                    : (details) => aimAt(details.localPosition.dx),
            onHorizontalDragUpdate:
                onAim == null
                    ? null
                    : (details) => aimAt(details.localPosition.dx),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: capsuleCenter(column, 0).dx),
              duration:
                  reducedMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 165),
              curve: Curves.easeOutCubic,
              builder:
                  (context, x, _) => AnimatedBuilder(
                    animation: motion,
                    builder: (context, _) {
                      final phase =
                          capturing && !reducedMotion ? motion.value : 0.0;
                      final pose = _GrabPose.at(phase);
                      final pileTop = capsuleCenter(
                        column,
                        stacks[column].length - 1,
                      );
                      final rest = 79 * scale;
                      final low = pileTop.dy - 33 * scale;
                      final hinge = Offset(x, rest + (low - rest) * pose.depth);
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            excludeFromSemantics: true,
                            behavior: HitTestBehavior.opaque,
                            onTapUp:
                                onAim == null
                                    ? null
                                    : (details) =>
                                        aimAt(details.localPosition.dx),
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: _CabinetPainter(paper: paper),
                              ),
                            ),
                          ),
                          for (final capsule in pile)
                            if (!pose.pickedUp || !capsule.captured)
                              capsule.view,
                          Positioned.fill(
                            child: IgnorePointer(
                              child: RepaintBoundary(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (pose.pickedUp && pose.capsuleScale > 0)
                                      _placeCapsule(
                                        center: hinge.translate(0, 33 * scale),
                                        diameter: diameter,
                                        child: Opacity(
                                          opacity: pose.capsuleOpacity,
                                          child: Transform.scale(
                                            scale: pose.capsuleScale,
                                            child: _Capsule(
                                              letter: stacks[column].last,
                                              lane: column,
                                              hinted: column == hintedColumn,
                                            ),
                                          ),
                                        ),
                                      ),
                                    CustomPaint(
                                      painter: _ClawPainter(
                                        paper: paper,
                                        hinge: hinge,
                                        scale: scale,
                                        grip: pose.grip,
                                        glint: pose.glint,
                                        guideEnd:
                                            onAim == null
                                                ? null
                                                : pileTop.dy - diameter / 2 - 6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
            ),
          );
        },
      ),
    ),
  );

  Widget _placeCapsule({
    required Offset center,
    required double diameter,
    required Widget child,
    int? dropId,
    Key? key,
  }) => Positioned(
    key: key,
    left: center.dx - diameter / 2,
    top: center.dy - diameter / 2,
    width: diameter,
    height: diameter,
    child:
        dropId == null
            ? child
            : TweenAnimationBuilder<double>(
              key: ValueKey(dropId),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 245),
              curve: Curves.bounceOut,
              builder:
                  (context, t, child) => Transform.translate(
                    offset: Offset(0, -(1 - t) * diameter * 1.3),
                    child: child,
                  ),
              child: child,
            ),
  );
}

/// Все фазы держатся на одних часах, в том числе при сворачивании.
class _GrabPose {
  const _GrabPose(this.depth, this.grip, this.release, this.pickedUp);

  factory _GrabPose.at(double t) {
    final descend = Curves.easeInOutCubic.transform(_interval(t, 0, .40));
    final lift = Curves.easeInOutCubic.transform(_interval(t, .52, .91));
    final close = Curves.easeInOut.transform(_interval(t, .40, .52));
    final release = _interval(t, .89, 1);
    return _GrabPose(descend - lift, close * (1 - release), release, t >= .52);
  }

  final double depth;
  final double grip;
  final double release;
  final bool pickedUp;

  double get capsuleScale => 1 - Curves.easeInCubic.transform(release);
  double get capsuleOpacity => 1 - release * release;
  double get glint => math.sin(math.pi * release);

  static double _interval(double t, double start, double end) =>
      ((t - start) / (end - start)).clamp(0.0, 1.0);
}

class _Capsule extends StatelessWidget {
  const _Capsule({
    required this.letter,
    required this.lane,
    this.covered = false,
    this.selected = false,
    this.hinted = false,
    this.onTap,
    super.key,
  });

  final String letter;
  final int lane;
  final bool covered;
  final bool selected;
  final bool hinted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paper = scheme.brightness == Brightness.light;
    final palette =
        paper
            ? const [Color(0xFFF1C372), Color(0xFFBBD1AB), Color(0xFFCCB5DA)]
            : const [Color(0xFFFFBE64), Color(0xFF69D5C4), Color(0xFFC8A0FF)];
    final tint = palette[(letter.codeUnitAt(0) + lane) % palette.length];
    final edge = hinted || (paper && selected) ? scheme.primary : tint;
    final body = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected || hinted ? edge : tint.withValues(alpha: .5),
          width: selected || hinted ? 2 : 1,
        ),
        gradient: RadialGradient(
          center: const Alignment(-.37, -.75),
          radius: 1.04,
          colors:
              paper
                  ? [
                    scheme.surfaceContainerLow,
                    tint,
                    Color.lerp(tint, scheme.onSurface, .37)!,
                  ]
                  : [
                    tint,
                    tint.withValues(alpha: .52),
                    const Color(0xFF211331),
                  ],
          stops: const [0, .48, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: paper ? const Color(0x403B291E) : const Color(0xAA070610),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
          if (hinted)
            BoxShadow(color: edge.withValues(alpha: .65), blurRadius: 13),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 5,
            left: 10,
            child: Transform.rotate(
              angle: -.45,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .38),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const SizedBox(width: 13, height: 3),
              ),
            ),
          ),
          FractionallySizedBox(
            widthFactor: .94,
            child: Transform.rotate(
              angle: (lane.isEven ? -.12 : .12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: .65),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const SizedBox(height: 4),
              ),
            ),
          ),
          FractionallySizedBox(
            widthFactor: .53,
            heightFactor: .61,
            child: Transform.rotate(
              angle: (lane.isEven ? -.12 : .12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.lerp(tint, Colors.white, .27),
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: const [
                    BoxShadow(color: Color(0x40000000), blurRadius: 4),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      letter,
                      style: withWeight(
                        Theme.of(context).textTheme.titleLarge!,
                        FontWeight.bold,
                      ).copyWith(
                        color:
                            paper ? scheme.onSurface : const Color(0xFF24162D),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return ExcludeSemantics(
        child: covered ? Opacity(opacity: .55, child: body) : body,
      );
    }
    return Semantics(
      label: context.strings.capsule(letter, hintShown: hinted),
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ExcludeSemantics(child: body),
      ),
    );
  }
}

class _CabinetPainter extends CustomPainter {
  const _CabinetPainter({required this.paper});

  final bool paper;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(bounds, const Radius.circular(22));
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              paper
                  ? const [
                    Color(0xFFF2D9B5),
                    Color(0xFFDFC5A4),
                    Color(0xFFEAD7BB),
                    Color(0xFFC9A37F),
                  ]
                  : const [
                    Color(0xFF935CC1),
                    Color(0xFF312240),
                    Color(0xFF4E3176),
                    Color(0xFF221A32),
                  ],
          stops: const [0, .28, .76, 1],
        ).createShader(bounds),
    );
    final window = Rect.fromLTWH(7, 13, size.width - 14, size.height - 32);
    final glass = RRect.fromRectAndRadius(window, const Radius.circular(15));
    canvas.drawRRect(
      glass,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -.75),
          radius: .96,
          colors:
              paper
                  ? const [
                    Color(0xFFFFFBEE),
                    Color(0xFFFFF1D8),
                    Color(0xFFE6CBA8),
                  ]
                  : const [
                    Color(0xFF3B2A58),
                    Color(0xFF201931),
                    Color(0xFF131223),
                  ],
        ).createShader(window),
    );
    canvas.drawRRect(
      glass,
      Paint()
        ..color = paper ? const Color(0xFFA88463) : const Color(0xFFA085C1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25,
    );
    canvas.save();
    canvas.clipRRect(glass);
    final reflection =
        Path()
          ..moveTo(12, 14)
          ..lineTo(64, 14)
          ..lineTo(16, size.height * .65)
          ..close();
    canvas.drawPath(
      reflection,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x42E2BFFF), Color(0x00C6AAFF)],
        ).createShader(window),
    );
    final rail = Rect.fromLTWH(12, 32, size.width - 24, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rail, const Radius.circular(4)),
      Paint()..shader = (paper ? _paperMetal : _metal).createShader(rail),
    );
    for (final x in [size.width * .27, size.width * .73]) {
      final fixture = Rect.fromCenter(
        center: Offset(x, 23),
        width: 32,
        height: 4,
      );
      canvas.drawOval(
        fixture.inflate(2),
        Paint()
          ..color = const Color(0x54FFDBB8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawOval(fixture, Paint()..color = const Color(0xFFFFE1C8));
    }
    canvas.restore();
    for (final x in [12.0, size.width - 12]) {
      canvas.drawCircle(
        Offset(x, size.height - 9),
        2.1,
        Paint()
          ..color = paper ? const Color(0xFF987250) : const Color(0xFFAA96BF),
      );
    }
  }

  @override
  bool shouldRepaint(_CabinetPainter oldDelegate) => paper != oldDelegate.paper;
}

const _metal = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFF1E4FA), Color(0xFF8A769A), Color(0xFF4D3D61)],
  stops: [0, .37, 1],
);

const _paperMetal = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFFFF3D9), Color(0xFFAC8664), Color(0xFF755236)],
  stops: [0, .37, 1],
);

class _ClawPainter extends CustomPainter {
  const _ClawPainter({
    required this.paper,
    required this.hinge,
    required this.scale,
    required this.grip,
    required this.glint,
    required this.guideEnd,
  });

  final bool paper;
  final Offset hinge;
  final double scale;
  final double grip;
  final double glint;
  final double? guideEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final metal = paper ? _paperMetal : _metal;
    if (guideEnd case final end?) {
      final guide =
          Paint()
            ..color = paper ? const Color(0xAA9A3F27) : const Color(0x665FEDCA)
            ..strokeWidth = 1
            ..strokeCap = StrokeCap.round;
      for (var y = hinge.dy + 49 * scale; y + 3 <= end; y += 8) {
        canvas.drawLine(Offset(hinge.dx, y), Offset(hinge.dx, y + 3), guide);
      }
    }
    final cable = Path()..moveTo(hinge.dx, 42);
    for (var y = 42.0; y <= hinge.dy; y += .9) {
      cable.lineTo(hinge.dx + math.sin(y * .92) * 3.2, y);
    }
    canvas.drawPath(
      cable,
      Paint()
        ..color = paper ? const Color(0xFF8D6C51) : const Color(0xFF78688B)
        ..strokeWidth = 2.1
        ..style = PaintingStyle.stroke,
    );
    final carriage = Rect.fromCenter(
      center: Offset(hinge.dx, 36),
      width: 44 * scale,
      height: 27,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(carriage, const Radius.circular(7)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              paper
                  ? const [
                    Color(0xFFDA9977),
                    Color(0xFF9A3F27),
                    Color(0xFF743521),
                  ]
                  : const [
                    Color(0xFFBA87E6),
                    Color(0xFF583784),
                    Color(0xFF31204C),
                  ],
        ).createShader(carriage),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(hinge.dx, 42),
          width: 26 * scale,
          height: 3,
        ),
        const Radius.circular(2),
      ),
      Paint()
        ..color = paper ? const Color(0xFFFFDB88) : const Color(0xFF74E6D3),
    );

    canvas.save();
    canvas.translate(hinge.dx, hinge.dy);
    canvas.scale(scale, scale);
    final housing = Rect.fromCenter(center: Offset.zero, width: 29, height: 18);
    for (final sign in [-1, 1]) {
      final spread = 34 - 7 * grip;
      final jaw =
          Path()
            ..moveTo(sign * 11, 1)
            ..cubicTo(sign * 15, 11, sign * spread, 11, sign * spread, 26)
            ..quadraticBezierTo(sign * spread, 37, sign * (spread - 7), 44);
      canvas.drawPath(
        jaw,
        Paint()
          ..shader = metal.createShader(const Rect.fromLTWH(-34, 0, 68, 45))
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(housing, const Radius.circular(5)),
      Paint()..shader = metal.createShader(housing),
    );
    canvas.drawCircle(
      Offset.zero,
      3.8,
      Paint()
        ..color = paper ? const Color(0xFF744D32) : const Color(0xFF473559),
    );
    if (glint > 0) {
      final paint =
          Paint()
            ..color = const Color(0xFF7CF4D3).withValues(alpha: .7 * glint);
      for (var index = 0; index < 6; index++) {
        final angle = index * math.pi / 3;
        final radius = 26 + 11 * glint;
        canvas.drawCircle(
          Offset(math.cos(angle) * radius, 32 + math.sin(angle) * radius),
          1.8 * glint,
          paint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ClawPainter oldDelegate) =>
      oldDelegate.paper != paper ||
      oldDelegate.hinge != hinge ||
      oldDelegate.scale != scale ||
      oldDelegate.grip != grip ||
      oldDelegate.glint != glint ||
      oldDelegate.guideEnd != guideEnd;
}
