import 'dart:math' as math;

import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_field_swipe.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'maze_run.dart';

part 'maze_painters.dart';

class MazeField extends StatefulWidget {
  const MazeField({
    required this.run,
    required this.frames,
    required this.onTurn,
    required this.boardLabel,
    this.gateLabels = const [],
    super.key,
  });

  final MazeRun run;
  final Listenable frames;
  final ValueChanged<MazeDirection>? onTurn;
  final String boardLabel;
  final List<String> gateLabels;

  @override
  State<MazeField> createState() => _MazeFieldState();
}

class _MazeFieldState extends State<MazeField> {
  final _focus = FocusNode();
  var _heading = _RunnerHeading();

  @override
  void didUpdateWidget(MazeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.run != oldWidget.run) _heading = _RunnerHeading();
    if (oldWidget.onTurn == null && widget.onTurn != null) {
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    final turn = widget.onTurn;
    if (turn == null) return KeyEventResult.ignored;
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.keyW => MazeDirection.up,
      LogicalKeyboardKey.arrowRight ||
      LogicalKeyboardKey.keyD => MazeDirection.right,
      LogicalKeyboardKey.arrowDown ||
      LogicalKeyboardKey.keyS => MazeDirection.down,
      LogicalKeyboardKey.arrowLeft ||
      LogicalKeyboardKey.keyA => MazeDirection.left,
      _ => null,
    };
    if (direction == null) return KeyEventResult.ignored;
    if (event is KeyDownEvent) turn(direction);
    return KeyEventResult.handled;
  }

  void _swipe(Offset _, Offset delta) {
    _focus.requestFocus();
    final direction =
        delta.dx.abs() >= delta.dy.abs()
            ? (delta.dx > 0 ? MazeDirection.right : MazeDirection.left)
            : (delta.dy > 0 ? MazeDirection.down : MazeDirection.up);
    widget.onTurn?.call(direction);
  }

  @override
  Widget build(BuildContext context) {
    final turn = widget.onTurn;
    final strings = context.strings;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: AspectRatio(
        aspectRatio: MazeRun.columns / MazeRun.rows,
        child: Focus(
          autofocus: turn != null,
          focusNode: _focus,
          includeSemantics: false,
          onKeyEvent: _key,
          child: Semantics(
            label: widget.boardLabel,
            container: true,
            customSemanticsActions:
                turn == null
                    ? null
                    : {
                      CustomSemanticsAction(label: strings.snakeUp):
                          () => turn(MazeDirection.up),
                      CustomSemanticsAction(label: strings.snakeRight):
                          () => turn(MazeDirection.right),
                      CustomSemanticsAction(label: strings.snakeDown):
                          () => turn(MazeDirection.down),
                      CustomSemanticsAction(label: strings.snakeLeft):
                          () => turn(MazeDirection.left),
                    },
            child: ArcadeFieldSwipe(
              distance: 7,
              continuous: true,
              onSwipe: turn == null ? null : _swipe,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: _SceneryPainter(
                          run: widget.run,
                          dark: dark,
                          labels: widget.gateLabels,
                          textScale:
                              MediaQuery.textScalerOf(context).scale(12) / 12,
                        ),
                      ),
                    ),
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: _RunnerPainter(
                          run: widget.run,
                          dark: dark,
                          frames: widget.frames,
                          reduced: MediaQuery.disableAnimationsOf(context),
                          heading: _heading,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The same numbered seal is drawn at the gate and beside its full word.
class MazeGateBadge extends StatelessWidget {
  const MazeGateBadge({required this.index, super.key});

  final int index;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: '${index + 1}',
      child: SizedBox.square(
        dimension: 26,
        child: CustomPaint(painter: _BadgePainter(index, dark)),
      ),
    );
  }
}
