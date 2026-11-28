import 'package:arcadelingo/ui/arcade_reveal_pair.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('a long correction stays at full text size, $brightness', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 240);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      const prompt = Key('prompt');
      const answer = Key('answer');
      await tester.pumpWidget(
        MaterialApp(
          theme: wordarcadeTheme(brightness: brightness),
          home: const Scaffold(
            body: ArcadeRevealPair(
              word: 'to draw a reasonable conclusion',
              answer: 'сделать обоснованный вывод из имеющихся фактов',
              wordKey: prompt,
              answerKey: answer,
            ),
          ),
        ),
      );
      for (final key in [prompt, answer]) {
        final finder = find.byKey(key);
        final box = tester.renderObject<RenderBox>(finder);
        final pixel =
            box.localToGlobal(const Offset(1, 0)) -
            box.localToGlobal(Offset.zero);
        expect(pixel.dx, closeTo(1, .01));
      }
      final scroll = find.byType(SingleChildScrollView);
      final viewport = tester.getRect(scroll).inflate(.1);
      expect(viewport.contains(tester.getTopLeft(find.byKey(prompt))), isTrue);
      final scrolling = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrolling.position.maxScrollExtent, greaterThan(0));
      await tester.drag(scroll, const Offset(0, -185));
      await tester.pumpAndSettle();
      expect(scrolling.position.pixels, greaterThan(0));
      scrolling.position.jumpTo(scrolling.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        viewport.contains(tester.getBottomRight(find.byKey(answer))),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
