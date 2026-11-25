@Tags(['peek'])
library;

import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:arcadelingo/ui/week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/campfire_artwork.dart';
import '../support/ritual_views.dart';
import 'peek_harness.dart';

void _ignore() {}

void main() {
  const cases = [
    (name: 'dark', width: 360.0, scale: 1.0, brightness: Brightness.dark),
    (name: 'narrow', width: 320.0, scale: 1.0, brightness: Brightness.dark),
    (name: 'large_text', width: 320.0, scale: 2.0, brightness: Brightness.dark),
    (name: 'light', width: 360.0, scale: 1.0, brightness: Brightness.light),
  ];

  for (final sample in cases) {
    testWidgets('панель запуска — ${sample.name}', (tester) async {
      tester.view.physicalSize = Size(sample.width * 3, 780 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = sample.scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: wordarcadeTheme(
            brightness: sample.brightness,
            platform: TargetPlatform.android,
          ),
          home: PlayView(
            games: wordarcadeGames,
            selectedGameId: fallingWordsEntry.id,
            course: StudyCourse.englishFromRussian,
            selectedLevel: CefrLevel.a1,
            onCourseSelected: _ignore,
            onLevelSelected: (_) {},
            onGameSelected: (_) {},
            onPlay: _ignore,
            onLearn: _ignore,
            onChallenge: _ignore,
            onSources: _ignore,
            onProgress: _ignore,
            onSettings: _ignore,
            ritual: ritualView(days: 28),
            week: weekStrip(
              today: ritualToday,
              played: {daysAgo(2), daysAgo(1), ritualToday},
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(PlayView));
      await warmCampfire(tester, context, 28, sample.brightness);
      await tester.runAsync(() async {
        await Future.wait([
          for (final game in wordarcadeGames)
            if (game.artwork case final artwork?)
              precacheImage(
                ResizeImage(AssetImage(artwork), width: 1200),
                context,
              ),
        ]);
      });
      await tester.pumpAndSettle();
      if (sample.scale > 1) {
        final position =
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
      }
      final viewport = tester.getSize(find.byType(SingleChildScrollView).first);
      debugPrint('${sample.name}: область списка ${viewport.height} dp');
      await peek(tester, 'compact_home_actions_${sample.name}');
    });
  }
}
