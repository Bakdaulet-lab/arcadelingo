import 'dart:math' as math;

import 'package:arcadelingo/features/games/word_maze/maze_field.dart';
import 'package:arcadelingo/features/games/word_maze/maze_run.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'respawn resets the displayed heading with the simulation clock',
    (tester) async {
      final frames = ValueNotifier<int>(0);
      addTearDown(frames.dispose);
      final run = _Pose();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 320,
              child: MazeField(
                run: run,
                frames: frames,
                onTurn: run.steer,
                boardLabel: 'Maze',
              ),
            ),
          ),
        ),
      );
      final layer =
          tester
              .renderObjectList<RenderCustomPaint>(
                find.descendant(
                  of: find.byType(MazeField),
                  matching: find.byType(CustomPaint),
                ),
              )
              .last;
      void draw(Canvas canvas) => layer.painter!.paint(canvas, layer.size);
      expect(draw, paints..rotate(angle: 0));
      run
        ..direction = MazeDirection.up
        ..seconds = 3;
      frames.value++;
      await tester.pump();
      run.seconds = 3.12;
      expect(draw, paints..rotate(angle: -math.pi / 2));
      // Respawning in MazeRun resets its elapsed time and keeps this board.
      run.seconds = 0;
      expect(draw, paints..rotate(angle: -math.pi / 2));
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'continuous swipes, keys and accessible directions in $brightness',
      (tester) async {
        final frames = ValueNotifier<int>(0);
        addTearDown(frames.dispose);
        final turns = <MazeDirection>[];
        final run = MazeRun();
        Future<void> show(ValueChanged<MazeDirection>? onTurn) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: wordarcadeTheme(brightness: brightness),
              home: Center(
                child: SizedBox(
                  width: 320,
                  child: MazeField(
                    run: run,
                    frames: frames,
                    onTurn: onTurn,
                    boardLabel: 'Поле лабиринта',
                    gateLabels: const ['llave', 'calle', 'leche'],
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
        }

        await show(null);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        expect(turns, isEmpty);
        await show(turns.add);
        final field = find.bySemanticsLabel('Поле лабиринта');
        final touch = await tester.startGesture(tester.getCenter(field));
        await touch.moveBy(const Offset(11, 3));
        await tester.pump();
        expect(turns, [MazeDirection.right]);
        await touch.moveBy(const Offset(-2, -14));
        expect(turns.last, MazeDirection.up);
        await touch.up();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
        expect(turns, [
          MazeDirection.right,
          MazeDirection.up,
          MazeDirection.left,
          MazeDirection.down,
        ]);
        final actions =
            tester
                .getSemantics(field)
                .getSemanticsData()
                .customSemanticsActionIds!;
        expect(
          actions
              .map((id) => CustomSemanticsAction.getAction(id)!.label)
              .toSet(),
          {'Вверх', 'Вправо', 'Вниз', 'Влево'},
        );
        await show(null);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        expect(turns.length, 4);
      },
    );
  }

  testWidgets(
    'one engine frame repaints actors without redrawing the static maze',
    (tester) async {
      final frames = ValueNotifier<int>(0);
      addTearDown(frames.dispose);
      final run = MazeRun();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 320,
              child: MazeField(
                run: run,
                frames: frames,
                onTurn: run.steer,
                boardLabel: 'Maze',
              ),
            ),
          ),
        ),
      );
      final layers =
          tester
              .renderObjectList<RenderCustomPaint>(
                find.descendant(
                  of: find.byType(MazeField),
                  matching: find.byType(CustomPaint),
                ),
              )
              .toList();
      expect(layers.length, greaterThanOrEqualTo(2));
      await tester.pump();
      run.steer(MazeDirection.up);
      run.advance(1 / 60);
      frames.value++;
      expect(layers.where((layer) => layer.debugNeedsPaint), hasLength(1));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}

class _Pose extends MazeRun {
  MazeDirection direction = MazeDirection.right;
  double seconds = 2;
  @override
  MazeDirection get facing => direction;
  @override
  double get elapsedSeconds => seconds;
}
