@Tags(['peek'])
library;

import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/ui/week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/bundled_fonts.dart';
import '../support/ritual_views.dart';
import 'peek_harness.dart';

void main() {
  setUpAll(loadBundledFonts);

  for (final scale in [1.0, 2.0]) {
    testWidgets('Ночная аркада, шрифт $scale', (tester) async {
      await pumpPeek(
        tester,
        PlayView(
          onPlay: () {},
          onProgress: () {},
          onSettings: () {},
          onSources: () {},
          ritual: ritualView(days: 5),
          week: weekStrip(
            today: ritualToday,
            played: {daysAgo(2), daysAgo(1), ritualToday},
          ),
          games: wordarcadeGames,
          selectedGameId: ninjaSlashEntry.id,
          onGameSelected: (_) {},
          selectedLevel: CefrLevel.b1,
          onLevelSelected: (_) {},
        ),
        textScale: scale,
      );
      await tester.runAsync(() async {
        await precacheImage(
          const ResizeImage(
            AssetImage('assets/images/home/ninja.png'),
            width: 1200,
          ),
          tester.element(find.byType(PlayView)),
        );
        await precacheImage(
          const ResizeImage(
            AssetImage('assets/images/home/falling-words.png'),
            width: 1200,
          ),
          tester.element(find.byType(PlayView)),
        );
      });
      await tester.pumpAndSettle();
      await peek(tester, scale == 1 ? 'night_arcade' : 'night_arcade_text2x');
    });
  }
}
