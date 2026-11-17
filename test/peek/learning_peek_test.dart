@Tags(['peek'])
library;

import 'dart:async';

import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/app/learning_views.dart';
import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_views.dart'
    as falling;
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_views.dart'
    as ninja;
import 'package:arcadelingo/ui/week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/bundled_fonts.dart';
import '../support/ritual_views.dart';
import 'peek_harness.dart';

Future<void> _pumpRoute(
  WidgetTester tester,
  Widget page, {
  required double scale,
}) async {
  await pumpPeek(
    tester,
    const Scaffold(body: SizedBox.expand()),
    textScale: scale,
    physicalSize: scale == 1 ? peekPhysicalSize : const Size(960, 1704),
  );
  unawaited(
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(MaterialPageRoute<void>(builder: (_) => page)),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Word> words;
  setUpAll(() async {
    await loadBundledFonts();
    words = switch (await loadWordsSeed()) {
      Ok(:final value) => value.map((item) => item.word).toList(),
      Err(:final failure) => throw StateError(failure.message),
    };
  });

  for (final scale in [1.0, 2.0]) {
    final suffix = scale == 1 ? '' : '_text2x';
    testWidgets('Знакомство с настоящими словами B1, $scale×', (tester) async {
      await _pumpRoute(
        tester,
        WordIntroductionScreen(
          words:
              words
                  .where((word) => word.level == CefrLevel.b1)
                  .take(5)
                  .toList(),
          level: CefrLevel.b1,
          speech: const NoopWordSpeech(),
          onStart: () {},
        ),
        scale: scale,
      );
      await peek(tester, 'learning_introduction$suffix');
      if (scale == 2) {
        await tester.ensureVisible(find.byKey(LearningKeys.skip));
        await tester.pumpAndSettle();
        await peek(tester, 'learning_introduction_actions$suffix');
      }
    });

    testWidgets('Разбор длинного слова C2, $scale×', (tester) async {
      final first = words.firstWhere(
        (word) =>
            word.level == CefrLevel.c2 && word.text == 'counterproductively',
      );
      await _pumpRoute(
        tester,
        MistakesReviewScreen(
          words: [
            first,
            ...words
                .where(
                  (word) => word.level == CefrLevel.c2 && word.id != first.id,
                )
                .take(2),
          ],
          level: CefrLevel.c2,
          speech: const NoopWordSpeech(),
        ),
        scale: scale,
      );
      await peek(tester, 'learning_mistakes$suffix');
      if (scale == 2) {
        await tester.ensureVisible(find.byKey(LearningKeys.translation));
        await tester.pumpAndSettle();
        await peek(tester, 'learning_mistakes_translation$suffix');
        await tester.ensureVisible(find.byKey(LearningKeys.done));
        await tester.pumpAndSettle();
        await peek(tester, 'learning_mistakes_actions$suffix');
      }
    });

    testWidgets('Вход в знакомство с главной, $scale×', (tester) async {
      await pumpPeek(
        tester,
        PlayView(
          onPlay: () {},
          onLearn: () {},
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
        physicalSize: scale == 1 ? peekPhysicalSize : const Size(960, 1704),
      );
      await tester.runAsync(() async {
        for (final path in [
          'assets/images/home/ninja.png',
          'assets/images/home/falling-words.png',
        ]) {
          await precacheImage(
            ResizeImage(AssetImage(path), width: 1200),
            tester.element(find.byType(PlayView)),
          );
        }
      });
      await tester.pumpAndSettle();
      await peek(tester, 'learning_home$suffix');
      if (scale == 2) {
        await tester.ensureVisible(find.byKey(AppKeys.learn));
        await tester.pumpAndSettle();
        await peek(tester, 'learning_home_actions$suffix');
      }
    });

    for (final game in ['falling', 'ninja']) {
      testWidgets('Разбор ошибок на итогах $game, $scale×', (tester) async {
        final summary =
            game == 'falling'
                ? falling.SummaryView(
                  score: 810,
                  bestCombo: 12,
                  correctCount: 12,
                  answeredCount: 15,
                  outOfLives: false,
                  onPlayAgain: () {},
                  onExit: () {},
                  mistakeCount: 3,
                  onReviewMistakes: () {},
                )
                : ninja.SummaryView(
                  score: 810,
                  bestCombo: 12,
                  correctCount: 12,
                  answeredCount: 15,
                  outOfLives: false,
                  onPlayAgain: () {},
                  onExit: () {},
                  mistakeCount: 3,
                  onReviewMistakes: () {},
                );
        await pumpPeek(
          tester,
          Scaffold(body: summary),
          textScale: scale,
          physicalSize: scale == 1 ? peekPhysicalSize : const Size(960, 1704),
        );
        await peek(tester, 'learning_${game}_summary$suffix');
        if (scale == 2) {
          await tester.ensureVisible(
            find.byKey(const Key('game.review_mistakes')),
          );
          await tester.pumpAndSettle();
          await peek(tester, 'learning_${game}_summary_actions$suffix');
        }
      });
    }
  }

  testWidgets('Сообщение об отсутствующем английском голосе', (tester) async {
    await _pumpRoute(
      tester,
      WordIntroductionScreen(
        words:
            words.where((word) => word.level == CefrLevel.a1).take(1).toList(),
        level: CefrLevel.a1,
        speech: const NoopWordSpeech(),
        onStart: () {},
      ),
      scale: 1,
    );
    await tester.ensureVisible(find.byKey(LearningKeys.speak));
    await tester.tap(find.byKey(LearningKeys.speak));
    await tester.pumpAndSettle();
    await peek(tester, 'learning_speech_unavailable');
  });
}
