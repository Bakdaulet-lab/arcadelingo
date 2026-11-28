import 'package:arcadelingo/features/games/space_word/space_field.dart';
import 'package:arcadelingo/features/games/space_word/space_flight.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const labels = ['nube', 'sol', 'luna'];

Widget board(SpaceFlight flight, {bool playing = true, VoidCallback? onPause}) {
  return MaterialApp(
    home: Center(
      child: SizedBox(
        width: 360,
        height: 420,
        child: SpaceField(
          flight: flight,
          labels: labels,
          playing: playing,
          reducedMotion: false,
          onEvent: (_) {},
          onPause: onPause ?? () {},
          semanticsLabel: 'Space Word',
        ),
      ),
    ),
  );
}

Future<void> step(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('relative drag steers on both axes and fires through the turn', (
    tester,
  ) async {
    final flight = SpaceFlight()..startWave(options: labels, correctIndex: 2, wave: 1);
    await tester.pumpWidget(board(flight));
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(SpaceField));
    final initial = flight.ship;
    final contact = await tester.startGesture(origin + const Offset(114, 292));
    await step(tester, 1);
    expect((flight.ship - initial).distance, lessThan(1));
    expect(flight.bolts, isNotEmpty);
    await contact.moveBy(const Offset(68, -93));
    await step(tester, 13);
    expect(flight.ship.dx, greaterThan(initial.dx + 40));
    expect(flight.ship.dy, lessThan(initial.dy - 55));
    await contact.up();
    await tester.pumpWidget(board(flight, playing: false));
    final pausedAt = flight.ship;
    final pausedClock = flight.time;
    await step(tester, 24);
    expect(flight.ship, pausedAt);
    expect(flight.time, pausedClock);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('keyboard thrust, fire, and focus loss are independent', (tester) async {
    final flight = SpaceFlight()..startWave(options: labels, correctIndex: 2, wave: 1);
    var pauses = 0;
    await tester.pumpWidget(board(flight, onPause: () => pauses++));
    await tester.pump();
    final initial = flight.ship;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await step(tester, 12);
    expect(flight.ship.dx, lessThan(initial.dx - 25));
    expect(flight.bolts, isEmpty);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await step(tester, 2);
    expect(flight.bolts, isNotEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    final stopped = flight.time;
    await step(tester, 12);
    expect(flight.time, stopped);
    expect(pauses, 1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pumpWidget(const SizedBox());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
