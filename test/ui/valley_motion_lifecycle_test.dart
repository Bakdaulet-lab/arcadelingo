import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:arcadelingo/ui/campfire_stage.dart';
import 'package:arcadelingo/ui/streak_campfire.dart';
import 'package:arcadelingo/ui/streak_flame.dart';
import 'package:arcadelingo/ui/valley_campfire_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/campfire_artwork.dart';

Future<void> show(
  WidgetTester tester,
  int days, {
  Brightness brightness = Brightness.dark,
  bool reduced = false,
  bool visible = true,
  FlameMood mood = FlameMood.lit,
  int replay = 0,
}) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Theme(
        data: ThemeData(brightness: brightness),
        child: TickerMode(
          enabled: visible,
          child: Center(
            child: StreakCampfire(
              days: days,
              tier: flameTier(days),
              mood: mood,
              replayToken: replay,
              landscape: true,
              size: const Size(240, 100),
            ),
          ),
        ),
      ),
    ),
  ),
);

ValleyCampfirePainter current(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is ValleyCampfirePainter,
    ),
  );
  return paint.painter! as ValleyCampfirePainter;
}

Future<void> warm(WidgetTester tester, int day, Brightness brightness) =>
    warmCampfire(
      tester,
      tester.element(find.byType(StreakCampfire)),
      day,
      brightness,
    );

Future<Uint8List> pixels(CustomPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(ui.Canvas(recorder), const Size(240, 100));
  final picture = recorder.endRecording();
  final image = await picture.toImage(240, 100);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  testWidgets(
    'an interrupted transition settles on the requested stage and theme',
    (tester) async {
      await show(tester, 0);
      await warm(tester, 21, Brightness.dark);
      await warm(tester, 28, Brightness.dark);
      await warm(tester, 28, Brightness.light);
      await show(tester, 28, brightness: Brightness.light, reduced: true);
      await tester.pump();
      final expected = current(tester).artwork!;
      final expectedSheet = expected.sheet.clone();
      final expectedPlate = expected.plate!.clone();
      addTearDown(expectedSheet.dispose);
      addTearDown(expectedPlate.dispose);

      await show(tester, 21);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 375));
      expect(current(tester).frame, greaterThan(0));
      await show(tester, 28);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 85));
      expect(current(tester).previous, isNotNull);
      await show(tester, 28, brightness: Brightness.light, reduced: true);
      await tester.pumpAndSettle();

      final settled = current(tester);
      expect(settled.stage, CampfireStage.tallFlame);
      expect(settled.frame, 0);
      expect(settled.previous, isNull);
      expect(
        settled.artwork!.sheet.image.isCloneOf(expectedSheet.image),
        isTrue,
      );
      expect(
        settled.artwork!.plate!.image.isCloneOf(expectedPlate.image),
        isTrue,
      );
    },
  );

  testWidgets(
    'background, hidden routes and reduced motion park the actual scene',
    (tester) async {
      await show(tester, 0);
      await warm(tester, 42, Brightness.dark);
      await show(tester, 42, visible: false);
      await tester.pump();
      expect(current(tester).hasArtwork, isTrue);
      await tester.pump(const Duration(seconds: 1));
      expect(current(tester).frame, 0);
      await show(tester, 42);
      await tester.pump(const Duration(milliseconds: 500));
      expect(current(tester).frame, 12);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 1));
      expect(current(tester).frame, 0);
      await show(tester, 42, reduced: true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await show(tester, 42, reduced: true, replay: 1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(current(tester).frame, 0);
      expect(current(tester).intensity, 0);
      await show(tester, 42, replay: 1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(current(tester).frame, 12);
      await tester.pumpAndSettle();
      expect(current(tester).frame, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );

  testWidgets(
    'an unlit stage replays on demand; earning a day visibly warms its pixels',
    (tester) async {
      await show(tester, 0);
      await warm(tester, 7, Brightness.dark);
      await show(tester, 7, mood: FlameMood.unlit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(current(tester).frame, 0);
      await show(tester, 7, mood: FlameMood.unlit, replay: 1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(current(tester).frame, 12);
      await tester.pumpAndSettle();
      expect(current(tester).frame, 0);

      await show(tester, 8, replay: 1);
      await tester.pump(const Duration(milliseconds: 216));
      final accented = current(tester);
      expect(accented.intensity, closeTo(1, .001));
      final quiet = ValleyCampfirePainter(
        stage: accented.stage,
        landscape: true,
        artwork: accented.artwork,
        previous: null,
        frames: accented.frames,
        accent: const AlwaysStoppedAnimation(1),
        repaint: accented.repaint,
        tier: accented.tier,
        mood: accented.mood,
        scheme: accented.scheme,
      );
      await tester.runAsync(() async {
        final a = await pixels(accented);
        final b = await pixels(quiet);
        expect(a, isNot(orderedEquals(b)));
        expect(a.sublist(0, 100), b.sublist(0, 100)); // The sky stays still.
      });
      await tester.pumpAndSettle();
      expect(current(tester).intensity, 0);
    },
  );
}
