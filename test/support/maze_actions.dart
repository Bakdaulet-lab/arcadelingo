import 'package:arcadelingo/features/games/word_maze/maze_field.dart';
import 'package:arcadelingo/features/games/word_maze/maze_run.dart';
import 'package:arcadelingo/features/games/word_maze/word_maze_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'maze_route.dart';

List<String> mazeGateWords(WidgetTester tester) {
  final field = tester.widget<MazeField>(find.byType(MazeField));
  return [
    for (var i = 0; i < field.run.gates.length; i++)
      tester.widget<Text>(find.byKey(MazeKeys.gate(i))).data!,
  ];
}

/// Drives the actual board through each corner using keyboard or touch.
Future<void> enterMazeGate(
  WidgetTester tester,
  int index, {
  bool swipe = false,
}) async {
  final field = find.byType(MazeField);
  await tester.ensureVisible(field);
  await tester.pump();
  final run = tester.widget<MazeField>(field).run;
  final wave = run.gateWave;
  final route = mazeRoute(run, index);
  var cell = (x: run.player.x.round(), y: run.player.y.round());
  for (var i = 0; i < route.length;) {
    final direction = route[i];
    do {
      cell = direction.from(cell);
      i++;
    } while (i < route.length && direction == route[i]);
    if (swipe) {
      await tester.drag(
        field,
        Offset(direction.dx * 48.0, direction.dy * 48.0),
      );
    } else {
      final key = switch (direction) {
        MazeDirection.up => LogicalKeyboardKey.arrowUp,
        MazeDirection.down => LogicalKeyboardKey.arrowDown,
        MazeDirection.left => LogicalKeyboardKey.arrowLeft,
        MazeDirection.right => LogicalKeyboardKey.arrowRight,
      };
      await tester.sendKeyEvent(key);
    }
    await tester.pump();
    for (var frame = 0; frame < 180; frame++) {
      await tester.pump(const Duration(milliseconds: 24));
      if (run.selectedGate != null || run.gateWave != wave) break;
      if (i < route.length &&
          (run.player.x - cell.x).abs() + (run.player.y - cell.y).abs() < .2) {
        break;
      }
    }
  }
  if (run.gateWave == wave) expect(run.selectedGate, index);
  await tester.pump(const Duration(milliseconds: 350));
}
