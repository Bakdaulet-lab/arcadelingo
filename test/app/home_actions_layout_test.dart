import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/bundled_fonts.dart';

Future<void> _pumpHome(
  WidgetTester tester, {
  required double width,
  required List<Key> taps,
  Brightness brightness = Brightness.dark,
  double textScale = 1,
  bool continuous = false,
}) async {
  tester.view.physicalSize = Size(width, 780);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    MaterialApp(
      theme: wordarcadeTheme(brightness: brightness),
      home: PlayView(
        games: wordarcadeGames,
        selectedGameId: continuous ? snakeEntry.id : fallingWordsEntry.id,
        selectedLevel: CefrLevel.a1,
        onPlay: () => taps.add(AppKeys.play),
        onLearn: () => taps.add(AppKeys.learn),
        onChallenge: () => taps.add(AppKeys.challenge),
        onProgress: () => taps.add(AppKeys.progress),
        onSettings: () => taps.add(AppKeys.settings),
        onSources: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);
  final challenge = find.byKey(AppKeys.challenge);
  final learn = find.byKey(AppKeys.learn);
  final play = find.byKey(AppKeys.play);
  final progress = find.byKey(AppKeys.progress);

  for (final width in [360.0, 320.0]) {
    testWidgets('dark $width: secondary actions share a row above Play', (
      tester,
    ) async {
      final taps = <Key>[];
      await _pumpHome(
        tester,
        width: width,
        taps: taps,
        continuous: width == 320,
      );
      final challengeRect = tester.getRect(challenge);
      final learnRect = tester.getRect(learn);
      final playRect = tester.getRect(play);

      expect(challengeRect.center.dy, closeTo(learnRect.center.dy, .01));
      expect(challengeRect.right, lessThan(learnRect.left));
      expect(playRect.top, greaterThanOrEqualTo(learnRect.bottom));
      expect(
        playRect.bottom,
        lessThanOrEqualTo(tester.getTopLeft(progress).dy),
      );
      expect(playRect.left, closeTo(challengeRect.left, .01));
      expect(playRect.right, closeTo(learnRect.right, .01));
      expect(playRect.bottom - challengeRect.top, lessThanOrEqualTo(112));
      expect(find.text('Знакомство и игра'), findsOneWidget);
      expect(
        find.text(width == 320 ? 'Непрерывная игра' : 'Испытание'),
        findsOneWidget,
      );

      for (final action in [challenge, learn, play, progress]) {
        expect(action.hitTestable(), findsOneWidget);
        final size = tester.getSize(action);
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
        await tester.tap(action);
        await tester.pumpAndSettle();
      }
      expect(taps, [
        AppKeys.challenge,
        AppKeys.learn,
        AppKeys.play,
        AppKeys.progress,
      ]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'dark 320 with 200% text: actions wrap and scroll independently',
    (tester) async {
      final taps = <Key>[];
      await _pumpHome(
        tester,
        width: 320,
        taps: taps,
        textScale: 2,
        continuous: true,
      );
      expect(
        tester.getRect(challenge).bottom,
        lessThanOrEqualTo(tester.getRect(learn).top),
      );
      expect(
        tester.getRect(learn).bottom,
        lessThanOrEqualTo(tester.getRect(play).top),
      );
      for (final action in [challenge, learn, play, progress]) {
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
      }
      expect(taps, [
        AppKeys.challenge,
        AppKeys.learn,
        AppKeys.play,
        AppKeys.progress,
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('light keeps learn, play and challenge in the original order', (
    tester,
  ) async {
    await _pumpHome(tester, width: 360, brightness: Brightness.light, taps: []);
    expect(
      tester.getRect(learn).bottom,
      lessThanOrEqualTo(tester.getRect(play).top),
    );
    expect(
      tester.getRect(play).bottom,
      lessThanOrEqualTo(tester.getRect(challenge).top),
    );
    expect(
      tester.getRect(progress).bottom,
      lessThan(tester.getRect(learn).top),
    );
    expect(tester.takeException(), isNull);
  });
}
