@Tags(['peek'])
library;

import 'dart:async';
import 'dart:io';

import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/attribution_view.dart';
import 'package:arcadelingo/app/progress_view.dart';
import 'package:arcadelingo/app/settings_view.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/progress/word_progress.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_views.dart'
    as falling;
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_game.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_views.dart'
    as ninja;
import 'package:arcadelingo/ui/arcade_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bundled_fonts.dart';
import '../support/fake_review_session.dart';
import 'peek_harness.dart';

ProgressData _progressData() {
  const counts = [14, 22, 0, 18, 30, 26, 0, 24, 20, 32, 16, 28, 35, 20];
  return ProgressData(
    words: const WordCounts(hard: 17, learning: 84, learned: 132),
    totals: const AnswerTotals(answers: 940, correct: 846, days: 23),
    bestStreak: 9,
    series: [
      for (final (index, answers) in counts.indexed)
        DayTally(
          day: StreakDay(2026, 11, 4 + index),
          answers: answers,
          correct: answers * 9 ~/ 10,
        ),
    ],
  );
}

Future<SettingsPrefsStore> _settingsStore() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = SettingsPrefsStore(prefs);
  await store.save(const AppSettings(enabled: true, at: ReminderTime(20, 30)));
  return store;
}

Future<void> _pumpRoute(
  WidgetTester tester,
  Widget page, {
  Size physicalSize = peekPhysicalSize,
  double textScale = 1,
}) async {
  await pumpPeek(
    tester,
    const Scaffold(),
    physicalSize: physicalSize,
    textScale: textScale,
  );
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => page)));
  await tester.pumpAndSettle();
}

void main() {
  late List<ReviewItem> words;

  setUpAll(() async {
    await loadBundledFonts();
    final loaded = await loadWordsSeed();
    words = switch (loaded) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError(failure.message),
    };
  });

  List<ReviewItem> gameWords() {
    final first = words.singleWhere((item) => item.word.id == 'whisper');
    return [
      first,
      ...words
          .where(
            (item) =>
                item.word.level == first.word.level &&
                item.word.id != first.word.id,
          )
          .take(14),
    ];
  }

  for (final scale in [1.0, 2.0]) {
    final suffix = scale == 1 ? '' : '_text2x';
    final size = scale == 1 ? peekPhysicalSize : const Size(960, 1704);

    testWidgets('Прогресс — Ночная аркада, $scale×', (tester) async {
      await _pumpRoute(
        tester,
        ArcadePage(
          title: 'Прогресс',
          child: ProgressBody(data: _progressData()),
        ),
        physicalSize: size,
        textScale: scale,
      );
      await tester.pumpAndSettle();
      await peek(tester, 'arcade_progress$suffix');
    });

    testWidgets('Настройки — Ночная аркада, $scale×', (tester) async {
      final store = await _settingsStore();
      await _pumpRoute(
        tester,
        SettingsScreen(store: store, onApply: store.save),
        physicalSize: size,
        textScale: scale,
      );
      await tester.pumpAndSettle();
      await peek(tester, 'arcade_settings$suffix');
    });

    testWidgets('Итоги — Ночная аркада, $scale×', (tester) async {
      await pumpPeek(
        tester,
        Scaffold(
          body: falling.SummaryView(
            score: 810,
            bestCombo: 12,
            correctCount: 14,
            answeredCount: 15,
            outOfLives: false,
            footer: 'Ещё есть слова — сыграй ещё раунд',
            onPlayAgain: () {},
            onExit: () {},
          ),
        ),
        physicalSize: size,
        textScale: scale,
      );
      await tester.pumpAndSettle();
      await peek(tester, 'arcade_falling_summary$suffix');
    });
  }

  testWidgets('Пустой прогресс — Ночная аркада', (tester) async {
    await _pumpRoute(
      tester,
      const ArcadePage(
        title: 'Прогресс',
        child: ProgressBody(
          data: ProgressData(
            words: WordCounts.empty,
            totals: AnswerTotals.empty,
            bestStreak: 0,
            series: [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await peek(tester, 'arcade_progress_empty');
  });

  testWidgets('Источники — Ночная аркада', (tester) async {
    final source = File('assets/ATTRIBUTION.md').readAsStringSync();
    await _pumpRoute(tester, AttributionView(source: source));
    await tester.pumpAndSettle();
    await peek(tester, 'arcade_sources');
  });

  testWidgets('Падающие слова — Ночная аркада', (tester) async {
    await pumpPeek(
      tester,
      FallingWordsGame(
        session: FakeReviewSession(gameWords()),
        seed: 1,
        onPlayAgain: () {},
        onExit: () {},
      ),
    );
    await tester.pump(FallingWordsRun.windUpTime);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1800));
    await peek(tester, 'arcade_falling');
  });

  testWidgets('Ниндзя-слэш — Ночная аркада', (tester) async {
    await pumpPeek(
      tester,
      NinjaSlashGame(
        session: FakeReviewSession(gameWords()),
        seed: 1,
        onPlayAgain: () {},
        onExit: () {},
      ),
    );
    await tester.pump(NinjaRun.windUpTime);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));
    await peek(tester, 'arcade_ninja');
  });

  testWidgets('Итоги ниндзя-слэша — Ночная аркада', (tester) async {
    await pumpPeek(
      tester,
      Scaffold(
        body: ninja.SummaryView(
          score: 810,
          bestCombo: 12,
          correctCount: 14,
          answeredCount: 15,
          outOfLives: false,
          footer: 'Ещё есть слова — сыграй ещё раунд',
          onPlayAgain: () {},
          onExit: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await peek(tester, 'arcade_ninja_summary');
  });

  testWidgets('Пустая сессия — Ночная аркада', (tester) async {
    await pumpPeek(
      tester,
      Scaffold(body: ninja.NothingTodayView(onExit: () {})),
    );
    await tester.pumpAndSettle();
    await peek(tester, 'arcade_empty_session');
  });

  testWidgets('Ошибка прогресса — Ночная аркада', (tester) async {
    await pumpPeek(
      tester,
      StateErrorView(
        message: 'Не удалось прочитать сохранённый прогресс.',
        onReset: () {},
      ),
    );
    await tester.pumpAndSettle();
    await peek(tester, 'arcade_state_error');
  });
}
