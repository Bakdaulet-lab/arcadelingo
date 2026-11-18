@Tags(['peek'])
library;

import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ritual_views.dart';
import 'peek_harness.dart';

void main() {
  testWidgets('выбран автомат с клешнёй', (tester) async {
    await pumpPeek(
      tester,
      PlayView(
        onPlay: () {},
        onLearn: () {},
        onProgress: () {},
        onSettings: () {},
        onSources: () {},
        games: wordarcadeGames,
        selectedGameId: clawMachineEntry.id,
        onGameSelected: (_) {},
        selectedLevel: CefrLevel.a1,
        onLevelSelected: (_) {},
        ritual: ritualView(),
      ),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byType(PlayView));
      await Future.wait([
        for (final game in wordarcadeGames)
          precacheImage(
            ResizeImage(AssetImage(game.artwork!), width: 1200),
            context,
          ),
      ]);
    });
    await tester.ensureVisible(find.text(clawMachineEntry.title));
    await tester.pumpAndSettle();
    await peek(tester, 'claw_home');
  });
}
