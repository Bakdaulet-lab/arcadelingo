import 'package:arcadelingo/features/games/space_word/space_field.dart';
import 'package:arcadelingo/features/games/space_word/space_word_game.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pilotFrames(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> shootSpaceWord(WidgetTester tester, String spelling) async {
  final start = find.byKey(SpaceWordKeys.start);
  if (start.evaluate().isNotEmpty) {
    await tester.tap(start);
    await tester.pump();
  }
  final field = tester.widget<SpaceField>(find.byType(SpaceField));
  final flight = field.flight;
  final index = field.labels.indexOf(spelling);
  expect(index, greaterThanOrEqualTo(0));
  final drone = flight.drones.singleWhere((drone) => drone.index == index);
  // A wide sign below another can block a direct shot at its centre. Choose
  // the exposed part of the target just as the player would on the field.
  List<double> openColumns() {
    final candidates = [
      for (var x = 26.0; x <= 334; x += 2)
        if ((x - drone.position.dx).abs() < drone.width / 2 - 8 &&
            !flight.drones.any(
              (other) =>
                  other != drone &&
                  other.visible &&
                  other.position.dy > drone.position.dy &&
                  other.position.dy < flight.ship.dy &&
                  (other.position.dx - x).abs() < other.width / 2 + 8,
            ))
          x,
    ];
    return candidates;
  }

  double aimX() {
    final candidates = openColumns();
    return candidates.isEmpty
        ? drone.position.dx
        : candidates[candidates.length ~/ 2];
  }

  final direction =
      aimX() < flight.ship.dx
          ? LogicalKeyboardKey.arrowLeft
          : LogicalKeyboardKey.arrowRight;
  if ((aimX() - flight.ship.dx).abs() > 4) {
    await tester.sendKeyDownEvent(direction);
    for (var i = 0; i < 100 && (aimX() - flight.ship.dx).abs() > 4; i++) {
      await pilotFrames(tester, 1);
    }
    await tester.sendKeyUpEvent(direction);
  }
  // If another sign spans the firing lane, fly between the rows before firing.
  if (openColumns().isEmpty) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
    for (
      var i = 0;
      i < 95 && flight.ship.dy > drone.position.dy + drone.height / 2 + 33;
      i++
    ) {
      await pilotFrames(tester, 1);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
  }
  await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
  for (var i = 0; i < 160 && drone.visible; i++) {
    await pilotFrames(tester, 1);
    if (find.byType(SpaceField).evaluate().isEmpty) break;
  }
  await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
  await pilotFrames(tester, 50);
}
