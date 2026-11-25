import 'package:arcadelingo/features/games/word_maze/maze_field.dart';
import 'package:arcadelingo/features/games/word_maze/word_maze_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> mazeGateWords(WidgetTester tester) {
  final field = tester.widget<MazeField>(find.byType(MazeField));
  return [
    for (var i = 0; i < field.run.gates.length; i++)
      tester.widget<Text>(find.byKey(MazeKeys.gate(i))).data!,
  ];
}

/// Plays the opening lane from spawn through the requested gate using input
/// events, including a buffered ninety-degree turn on the side routes.
Future<void> enterMazeGate(
  WidgetTester tester,
  int index, {
  bool swipe = false,
}) async {
  final field = find.byType(MazeField);
  await tester.ensureVisible(field);
  await tester.pump();
  final run = tester.widget<MazeField>(field).run;
  final gate = run.gates[index];
  final start = run.player;
  Future<void> steer(LogicalKeyboardKey key, Offset delta) async {
    if (swipe) {
      await tester.drag(field, delta);
    } else {
      await tester.sendKeyEvent(key);
    }
    await tester.pump();
  }

  if (gate.x != start.x) {
    final left = gate.x < start.x;
    await steer(
      left ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight,
      Offset(left ? -48 : 48, 0),
    );
    for (var i = 0; i < 120 && (run.player.x - gate.x).abs() > .42; i++) {
      await tester.pump(const Duration(milliseconds: 24));
    }
    expect((run.player.x - gate.x).abs(), lessThan(.43));
  }
  await steer(LogicalKeyboardKey.arrowUp, const Offset(0, -48));
  for (var i = 0; i < 160 && run.selectedGate == null; i++) {
    await tester.pump(const Duration(milliseconds: 24));
  }
  expect(run.selectedGate, index);
  await tester.pump(const Duration(milliseconds: 350));
}
