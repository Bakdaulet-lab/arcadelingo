import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpHome(
  WidgetTester tester,
  Brightness brightness, {
  required ValueChanged<String> onSelected,
  required VoidCallback onPlay,
  bool reducedMotion = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 800);
  addTearDown(tester.view.reset);
  final games = List.generate(
    12,
    (index) => GameEntry(
      id: 'game$index',
      title: 'Game $index',
      build: (_) => const SizedBox(),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: wordarcadeTheme(brightness: brightness),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reducedMotion),
            child: child!,
          ),
      home: PlayView(
        games: games,
        selectedGameId: games.last.id,
        onGameSelected: onSelected,
        onPlay: onPlay,
        onProgress: () {},
        onSettings: () {},
        onSources: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// Render-space scaling measures the visible control, independent of the
// widget or animation class chosen for the feedback.
double _scale(WidgetTester tester, Finder label) =>
    tester.renderObject<RenderBox>(label).getTransformTo(null).entry(0, 0);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('$brightness: card and Play respond to a press and recover', (
      tester,
    ) async {
      final selections = <String>[];
      var plays = 0;
      await _pumpHome(
        tester,
        brightness,
        onSelected: selections.add,
        onPlay: () => plays++,
      );
      final card = find.text('Game 0');
      final play = find.descendant(
        of: find.byKey(AppKeys.play),
        matching: find.byType(Text),
      );
      for (final label in [card, play]) {
        final baseline = _scale(tester, label);
        final finger = await tester.startGesture(tester.getCenter(label));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 32));
        final halfway = _scale(tester, label);
        expect(halfway, lessThan(baseline));
        await tester.pump(const Duration(milliseconds: 120));
        final held = _scale(tester, label);
        expect(held, lessThan(halfway));
        expect(held, greaterThan(baseline * .94));
        await finger.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 32));
        expect(_scale(tester, label), inExclusiveRange(held, baseline));
        await tester.pumpAndSettle();
        expect(_scale(tester, label), closeTo(baseline, .00001));
      }
      expect(selections, ['game0']);
      expect(plays, 1);

      // A tap can begin and end in a single frame.
      await tester.tap(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 35));
      expect(_scale(tester, card), lessThan(1));
      await tester.pumpAndSettle();
      expect(_scale(tester, card), closeTo(1, .00001));
      expect(selections, ['game0', 'game0']);
    });

    testWidgets('$brightness: scrolling cancels the card press', (
      tester,
    ) async {
      final selections = <String>[];
      await _pumpHome(
        tester,
        brightness,
        onSelected: selections.add,
        onPlay: () {},
      );
      final card = find.text('Game 0');
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      final finger = await tester.startGesture(tester.getCenter(card));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 120));
      expect(_scale(tester, card), lessThan(1));
      await finger.moveBy(const Offset(0, -35));
      await finger.moveBy(const Offset(0, -45));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(scroll.position.pixels, greaterThan(0));
      expect(_scale(tester, card), closeTo(1, .00001));
      await finger.up();
      await tester.pumpAndSettle();
      expect(selections, isEmpty);
    });

    testWidgets('$brightness: reduced motion keeps both controls stationary', (
      tester,
    ) async {
      final selections = <String>[];
      var plays = 0;
      await _pumpHome(
        tester,
        brightness,
        reducedMotion: true,
        onSelected: selections.add,
        onPlay: () => plays++,
      );
      for (final control in [find.text('Game 0'), find.byKey(AppKeys.play)]) {
        final finger = await tester.startGesture(tester.getCenter(control));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 40));
        expect(_scale(tester, control), closeTo(1, .00001));
        await finger.up();
        await tester.pumpAndSettle();
        expect(_scale(tester, control), closeTo(1, .00001));
      }
      expect(selections, ['game0']);
      expect(plays, 1);
    });
  }
}
