import 'dart:async';
import 'dart:ui' as ui;

import 'package:arcadelingo/features/games/candy_delivery/candy_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Widget board(
  GlobalKey<CandyFieldState> key,
  void Function(int?) land,
  VoidCallback onCut, {
  bool reduced = false,
  int aim = 0,
}) => MaterialApp(
  home: Center(
    child: SizedBox(
      width: 360,
      child: CandyField(
        key: key,
        rabbits: const [0, 1, 2],
        targetLane: 1,
        aim: aim,
        reducedMotion: reduced,
        onCut: onCut,
        onLand: land,
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'tall glade keeps the sweet round and offsets swipe coordinates to the drawn rope',
    (tester) async {
      final landed = <int?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 360,
              child: CandyField(
                aspectRatio: .92,
                rabbits: const [0, 1, 2],
                reducedMotion: true,
                aim: 1,
                onLand: landed.add,
              ),
            ),
          ),
        ),
      );
      final field = find.byType(CandyField);
      final rect = tester.getRect(field);
      expect(rect.height, closeTo(360 / .92, .01));
      final foreground = tester.renderObject<RenderRepaintBoundary>(
        find.descendant(of: field, matching: find.byType(RepaintBoundary)).last,
      );
      final centerY = (127 * rect.height / 292).round();
      final opacities = await tester.runAsync(() async {
        final image = await foreground.toImage();
        try {
          final bytes =
              (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          return [
            for (final dy in [12, 20])
              bytes.getUint8(((centerY + dy) * image.width + 184) * 4 + 3),
          ];
        } finally {
          image.dispose();
        }
      });
      expect(opacities!.first, 255);
      expect(
        opacities.last,
        0,
        reason: 'The sweet grows no taller on a tall phone.',
      );
      final swipe = await tester.startGesture(
        rect.topLeft + const Offset(130, 155),
      );
      await swipe.moveTo(rect.topLeft + const Offset(222, 155));
      await swipe.up();
      expect(landed, [2]);
    },
  );

  testWidgets('a covered flight cannot deliver after motion settings change', (
    tester,
  ) async {
    final field = GlobalKey<CandyFieldState>();
    final navigator = GlobalKey<NavigatorState>();
    final reduced = ValueNotifier(false);
    addTearDown(reduced.dispose);
    final landings = <int?>[];
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: ValueListenableBuilder<bool>(
          valueListenable: reduced,
          builder:
              (context, quiet, _) => CandyField(
                key: field,
                reducedMotion: quiet,
                aim: 0,
                rabbits: const [0, 1, 2],
                onLand: landings.add,
              ),
        ),
      ),
    );
    field.currentState!.cut();
    await tester.pump();
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(landings, isEmpty);
    reduced.value = true;
    await tester.pump();
    await tester.pump();
    expect(landings, isEmpty);
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(landings, hasLength(1));
  });

  testWidgets(
    'sparse swipe cuts once and cannot splice two different fingers',
    (tester) async {
      final key = GlobalKey<CandyFieldState>();
      final landings = <int?>[];
      var cuts = 0;
      await tester.pumpWidget(board(key, landings.add, () => cuts++));
      final origin = tester.getTopLeft(find.byType(CandyField));
      final gesture = await tester.startGesture(
        origin + const Offset(93, 52),
        pointer: 7,
      );
      final other = await tester.startGesture(
        origin + const Offset(280, 52),
        pointer: 9,
      );
      await other.moveTo(origin + const Offset(80, 52));
      await other.up();
      expect(cuts, 0);
      await gesture.moveTo(origin + const Offset(275, 52));
      expect(cuts, 1);
      expect(landings, isEmpty);
      key.currentState!.cut();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(landings, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 5));
      expect(landings, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(landings, hasLength(1));
      await tester.pump(const Duration(seconds: 2));
      expect(cuts, 1);
      expect(landings, hasLength(1));
    },
  );

  testWidgets(
    'reduced motion can reach each lane immediately and exactly once',
    (tester) async {
      for (final aim in [-1, 0, 1]) {
        final key = GlobalKey<CandyFieldState>();
        final messages = <String>[];
        await tester.pumpWidget(
          board(
            key,
            (lane) => messages.add('land $lane'),
            () => messages.add('cut'),
            reduced: true,
            aim: aim,
          ),
        );
        key.currentState!
          ..cut()
          ..cut();
        expect(messages, ['cut', 'land ${aim + 1}']);
      }
    },
  );
}
