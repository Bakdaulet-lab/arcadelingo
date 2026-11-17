import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ritual_views.dart';

Future<void> _pumpHome(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
  VoidCallback? onPlay,
  VoidCallback? onProgress,
  VoidCallback? onSettings,
  VoidCallback? onSources,
  ValueChanged<String>? onGameSelected,
  ValueChanged<CefrLevel>? onLevelSelected,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  var game = ninjaSlashEntry.id;
  var level = CefrLevel.b1;
  await tester.pumpWidget(
    MaterialApp(
      theme: wordarcadeTheme(platform: TargetPlatform.android),
      home: StatefulBuilder(
        builder:
            (context, setState) => PlayView(
              onPlay: onPlay ?? () {},
              onProgress: onProgress ?? () {},
              onSettings: onSettings ?? () {},
              onSources: onSources ?? () {},
              ritual: ritualView(days: 5),
              games: wordarcadeGames,
              selectedGameId: game,
              selectedLevel: level,
              onGameSelected: (value) {
                setState(() => game = value);
                onGameSelected?.call(value);
              },
              onLevelSelected: (value) {
                setState(() => level = value);
                onLevelSelected?.call(value);
              },
            ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('360×800: две игры и запуск видны на первом экране', (
    tester,
  ) async {
    await _pumpHome(tester, size: const Size(360, 800));

    expect(find.text('Ниндзя-слэш').hitTestable(), findsOneWidget);
    expect(find.text('Падающие слова').hitTestable(), findsOneWidget);
    expect(find.text('Разрежь правильный перевод'), findsOneWidget);
    expect(find.text('Нажми на верный перевод'), findsOneWidget);
    expect(find.byKey(AppKeys.play).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('320×568, шрифт $scale×: выбор и все действия доступны', (
      tester,
    ) async {
      var played = 0;
      var progress = 0;
      var settings = 0;
      var sources = 0;
      String? selectedGame;
      CefrLevel? selectedLevel;
      await _pumpHome(
        tester,
        size: const Size(320, 568),
        textScale: scale,
        onPlay: () => played++,
        onProgress: () => progress++,
        onSettings: () => settings++,
        onSources: () => sources++,
        onGameSelected: (value) => selectedGame = value,
        onLevelSelected: (value) => selectedLevel = value,
      );
      expect(tester.takeException(), isNull);

      await _tap(tester, find.widgetWithText(ChoiceChip, 'C2'));
      expect(selectedLevel, CefrLevel.c2);
      await _tap(tester, find.text('Падающие слова'));
      expect(selectedGame, fallingWordsEntry.id);
      await _tap(tester, find.byKey(AppKeys.play));
      await _tap(tester, find.byKey(AppKeys.progress));
      await _tap(tester, find.byKey(AppKeys.settings));
      await _tap(tester, find.byKey(AppKeys.sources));

      expect((played, progress, settings, sources), (1, 1, 1, 1));
      expect(tester.takeException(), isNull);
    });
  }
}
