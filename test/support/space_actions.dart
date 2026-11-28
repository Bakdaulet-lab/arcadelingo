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
  final direction = drone.position.dx < flight.ship.dx
      ? LogicalKeyboardKey.arrowLeft
      : LogicalKeyboardKey.arrowRight;
  if ((drone.position.dx - flight.ship.dx).abs() > 6) {
    await tester.sendKeyDownEvent(direction);
    for (var i = 0; i < 100 && (drone.position.dx - flight.ship.dx).abs() > 6; i++) {
      await pilotFrames(tester, 1);
    }
    await tester.sendKeyUpEvent(direction);
  }
  await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
  for (var i = 0; i < 160 && drone.visible; i++) {
    await pilotFrames(tester, 1);
    if (find.byType(SpaceField).evaluate().isEmpty) break;
  }
  await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
  await pilotFrames(tester, 50);
}
