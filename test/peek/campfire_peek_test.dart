@Tags(['peek'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/ui/streak_card.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:arcadelingo/ui/week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ritual_views.dart';
import 'peek_harness.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Костёр на главной, ${brightness.name}', (tester) async {
      tester.view.physicalSize = peekPhysicalSize;
      tester.view.devicePixelRatio = peekDevicePixelRatio;
      addTearDown(tester.view.reset);
      final days = ValueNotifier(6);
      addTearDown(days.dispose);
      const screen = Key('campfire.peek.home');
      await tester.pumpWidget(
        MaterialApp(
          theme: wordarcadeTheme(
            platform: TargetPlatform.android,
            brightness: brightness,
          ),
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: screen,
            child: ValueListenableBuilder<int>(
              valueListenable: days,
              builder:
                  (context, count, _) => PlayView(
                    ritual: ritualView(
                      days: count,
                      lastOffset: count == 6 ? 1 : 0,
                      freezes: count == 7 ? 1 : 0,
                      daysSinceFreeze: count == 6 ? 6 : 0,
                    ),
                    week: weekStrip(
                      today: ritualToday,
                      played: {
                        daysAgo(2),
                        daysAgo(1),
                        if (count == 7) ritualToday,
                      },
                    ),
                    course: StudyCourse.englishFromRussian,
                    games: wordarcadeGames,
                    selectedGameId: wordarcadeGames.first.id,
                    selectedLevel: CefrLevel.a1,
                    onCourseSelected: () {},
                    onLevelSelected: (_) {},
                    onGameSelected: (_) {},
                    onPlay: () {},
                    onLearn: () {},
                    onChallenge: () {},
                    onSources: () {},
                    onProgress: () {},
                    onSettings: () {},
                  ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final context = tester.element(find.byType(PlayView));
        for (final game in wordarcadeGames) {
          if (game.artwork case final artwork?) {
            await precacheImage(
              ResizeImage(AssetImage(artwork), width: 1200),
              context,
            );
          }
        }
      });
      await tester.pumpAndSettle();

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(screen),
      );
      final before = tester.getRect(find.byKey(streakCardKey));
      days.value = 7;
      await tester.pump();
      final after = tester.getRect(find.byKey(streakCardKey));
      final capture = before
          .expandToInclude(after)
          .inflate(3)
          .shift(-boundary.localToGlobal(Offset.zero))
          .intersect(boundary.paintBounds);
      final directory = Directory('$peekOutDir/campfire/${brightness.name}')
        ..createSync(recursive: true);
      Future<void> frame(int index) async {
        await tester.runAsync(() async {
          final layer = boundary.debugLayer! as OffsetLayer;
          final image = await layer.toImage(capture, pixelRatio: 3);
          try {
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            File(
              '${directory.path}/${index.toString().padLeft(2, '0')}.png',
            ).writeAsBytesSync(data!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }

      // Recreate the sixth day, then advance fake time in 30 ms steps.
      days.value = 6;
      await tester.pumpAndSettle();
      await frame(0);
      days.value = 7;
      await tester.pump();
      for (var i = 1; i <= 26; i++) {
        await frame(i);
        await tester.pump(const Duration(milliseconds: 30));
      }
      await peek(tester, 'campfire/${brightness.name}/home');
    });
  }
}
