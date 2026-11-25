import 'dart:ui' as ui;

import 'package:arcadelingo/ui/campfire_stage.dart';
import 'package:arcadelingo/ui/home_ritual_card.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:arcadelingo/ui/valley_campfire_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/campfire_artwork.dart';
import '../support/ritual_views.dart';

Future<int> _foregroundHash(
  WidgetTester tester,
  ValleyCampfirePainter painter,
) async {
  final value = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final size =
        painter.landscape ? const Size(240, 100) : const Size.square(72);
    painter.paint(Canvas(recorder), size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    try {
      final data =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final pixels = data.buffer.asUint32List(
        data.offsetInBytes,
        data.lengthInBytes ~/ 4,
      );
      expect(pixels.toSet().length, greaterThan(8), reason: 'empty artwork');
      return Object.hashAll(pixels);
    } finally {
      image.dispose();
      picture.dispose();
    }
  });
  return value!;
}

List<ValleyCampfirePainter> _painters(WidgetTester tester) =>
    tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<ValleyCampfirePainter>()
        .toList();

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'all earned stages draw distinct moving scenery and badges in ${brightness.name}',
      (tester) async {
        final current = ValueNotifier(0);
        addTearDown(current.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: wordarcadeTheme(brightness: brightness),
            home: Scaffold(
              body: ValueListenableBuilder<int>(
                valueListenable: current,
                builder:
                    (_, days, _) =>
                        HomeRitualCard(ritual: ritualView(days: days)),
              ),
            ),
          ),
        );
        final context = tester.element(find.byType(HomeRitualCard));
        expect(find.byKey(homeCampfireStageKey), findsNothing);
        expect(_painters(tester).single.stage, isNull);
        final badges = <int>{};
        final landscapes = <int>{};
        for (final stage in CampfireStage.values) {
          await warmCampfire(tester, context, stage.day, brightness);
          current.value = stage.day;
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 1250));
          final movingBadge = _painters(tester).single;
          expect(movingBadge.stage, stage);
          expect(movingBadge.hasArtwork, isTrue);
          expect(movingBadge.frame, greaterThan(0));
          final litBadge = await _foregroundHash(tester, movingBadge);
          await tester.pumpAndSettle();
          final restBadge = await _foregroundHash(
            tester,
            _painters(tester).single,
          );
          expect(restBadge, isNot(litBadge));
          expect(badges.add(restBadge), isTrue);
          await tester.tap(find.byKey(homeCampfireOpenKey));
          await tester.pumpAndSettle();
          final landscape = _painters(tester).singleWhere((p) => p.landscape);
          expect(landscape.stage, stage);
          expect(landscape.hasArtwork, isTrue);
          final still = await _foregroundHash(tester, landscape);
          expect(landscapes.add(still), isTrue);
          await tester.tap(find.byKey(homeCampfireReplayKey));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 650));
          final moving = _painters(tester).singleWhere((p) => p.landscape);
          expect(moving.frame, greaterThan(0));
          expect(
            await _foregroundHash(tester, moving),
            isNot(still),
            reason: 'day ${stage.day} replay',
          );
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
  testWidgets('an expired streak cannot unlock stages from its personal best', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeRitualCard(
            ritual: ritualView(days: 60, lastOffset: 3, best: 101),
          ),
        ),
      ),
    );
    expect(find.byKey(homeCampfireLandscapeKey), findsNothing);
    expect(_painters(tester).single.stage, isNull);
  });
}
