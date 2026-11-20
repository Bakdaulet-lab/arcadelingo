@Tags(['peek'])
library;

import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/app/learning_views.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_stores.dart';
import 'peek_harness.dart';

void main() {
  late Result<List<ReviewItem>> seed;
  setUpAll(() async {
    seed = await loadWordsSeed();
  });
  for (final theme in AppTheme.values) {
    testWidgets('выбор игры и знакомство со словами, ${theme.name}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.5;
      tester.view.physicalSize = const Size(585, 1266);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsPrefsStore(
        await SharedPreferences.getInstance(),
      );
      await settings.save(AppSettings.defaults.copyWith(theme: theme));
      await tester.pumpWidget(
        WordarcadeApp(
          seed: seed,
          now: () => DateTime(2026, 11, 21),
          ports: AppPorts(
            cards: InMemoryCardStore(),
            streaks: InMemoryStreakStore(),
            settings: settings,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final selector = find.byType(GameSelector);
      final card = find.descendant(
        of: selector,
        matching: find.text(ninjaSlashEntry.title),
      );
      final context = tester.element(selector);
      await tester.runAsync(() async {
        for (final game in wordarcadeGames) {
          await precacheImage(
            ResizeImage(AssetImage(game.artwork!), width: 1200),
            context,
          );
        }
      });
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();

      var frame = 0;
      Future<void> capture(int count) async {
        for (var i = 0; i < count; i++) {
          await tester.pump(const Duration(milliseconds: 30));
          await peek(tester, 'motion_${theme.name}_${frame++}');
        }
      }

      await capture(1);
      final finger = await tester.startGesture(tester.getCenter(card));
      await capture(8);
      await finger.up();
      await capture(7);
      await tester.tap(find.byKey(AppKeys.learn));
      await tester.pump();
      await capture(10);
      await tester.tap(find.byKey(LearningKeys.next));
      await tester.pump();
      await capture(8);
      await tester.tap(find.byKey(LearningKeys.previous));
      await tester.pump();
      await capture(8);
    });
  }
}
