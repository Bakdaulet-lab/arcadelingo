import 'dart:math';

import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

import 'brick_breaker_answers.dart';
import 'brick_breaker_run.dart';
import 'brick_paddle_input.dart';

part 'brick_breaker_art.dart';

class BrickBreakerField extends StatefulWidget {
  const BrickBreakerField({required this.run, required this.onMove, super.key});

  final BrickBreakerRun run;
  final ValueChanged<double> onMove;

  @override
  State<BrickBreakerField> createState() => _BrickBreakerFieldState();
}

class _BrickBreakerFieldState extends State<BrickBreakerField> {
  // Arena frames move the already measured labels. Shaping runs again only
  // for a new set of choices or when the available typography/width changes.
  (List<String>, double, TextStyle, TextScaler, TextDirection, Locale)?
  _snapshot;
  late BrickAnswerLayout _layout;
  Widget? _answers;
  int? _selectedLane;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = withWeight(
      theme.textTheme.titleMedium!,
      FontWeight.w600,
    ).copyWith(fontSize: 16, height: 1.32);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final locale = Localizations.localeOf(context);
    final run = widget.run;
    final bonus = run.phase == BrickPhase.bonus;
    final showCatch = bonus || run.phase == BrickPhase.feedback;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = width / BrickBreakerRun.width;
        final snapshot = (
          showCatch ? run.choices : const <String>[],
          width,
          style,
          scaler,
          direction,
          locale,
        );
        if (snapshot != _snapshot) {
          _snapshot = snapshot;
          _answers = null;
          _layout = BrickAnswerLayout(
            run: run,
            width: width,
            style: style,
            scaler: scaler,
            direction: direction,
            locale: locale,
          );
        }
        if (bonus && (_answers == null || _selectedLane != run.catchLane)) {
          _selectedLane = run.catchLane;
          _answers = RepaintBoundary(
            child: BrickBreakerAnswers(
              choices: run.choices,
              selected: _selectedLane,
              layout: _layout,
            ),
          );
        }
        return SizedBox(
          height: scale * BrickBreakerRun.height + _layout.extraHeight,
          child: BrickPaddleInput(
            run: run,
            scale: scale,
            fieldTop: _layout.extraHeight,
            onMove: widget.onMove,
            tappedLane:
                bonus ? (point) => _layout.touchedLane(point, run) : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ColoredBox(
                color: colors.surface,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      top: _layout.extraHeight,
                      child: _BrickFieldArtwork(
                        run,
                        colors,
                        paper: theme.brightness == Brightness.light,
                        effects: !MediaQuery.disableAnimationsOf(context),
                      ),
                    ),
                    if (bonus)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: _layout.rackHeight,
                        child: Transform.translate(
                          offset: Offset(0, _layout.top(run)),
                          child: _answers,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
