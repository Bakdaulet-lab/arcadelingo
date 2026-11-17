import 'dart:io';

import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/attribution_view.dart';
import 'package:arcadelingo/app/progress_view.dart';
import 'package:arcadelingo/app/settings_view.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/progress/day_series.dart';
import 'package:arcadelingo/domain/progress/word_progress.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_views.dart'
    as falling;
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_views.dart'
    as ninja;
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _longTranslation = 'способствующий быстрому восстановлению сил';

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  required double scale,
}) async {
  tester.view.physicalSize = const Size(960, 1704);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    MaterialApp(
      theme: wordarcadeTheme(platform: TargetPlatform.android),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

ProgressData _progress({bool empty = false}) => ProgressData(
  words:
      empty
          ? WordCounts.empty
          : const WordCounts(hard: 17, learning: 202, learned: 345),
  totals:
      empty
          ? AnswerTotals.empty
          : const AnswerTotals(answers: 120000, correct: 108000, days: 12345),
  bestStreak: empty ? 0 : 12345,
  series: fillDays(
    tallies: const [],
    from: StreakDay(2026, 11, 4),
    to: StreakDay(2026, 11, 17),
  ),
);

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('прогресс 320 dp / $scale×: числа и подписи доступны', (
      tester,
    ) async {
      await _pump(
        tester,
        Scaffold(body: ProgressBody(data: _progress())),
        scale: scale,
      );
      expect(tester.takeException(), isNull);
      for (final label in [
        'Выучено',
        'В работе',
        'Трудные',
        'Всего',
        'Верных',
        'С ответами',
        'Лучшая серия',
        'Две недели',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      expect(find.text('345'), findsOneWidget);
      expect(find.text('90%'), findsOneWidget);
      expect(find.text('12345 дней'), findsOneWidget);
      expect(find.byType(SeriesBar), findsNWidgets(14));
      expect(tester.takeException(), isNull);
    });

    testWidgets('пустой прогресс 320 dp / $scale×: приглашение читается', (
      tester,
    ) async {
      await _pump(
        tester,
        Scaffold(body: ProgressBody(data: _progress(empty: true))),
        scale: scale,
      );
      expect(find.byKey(ProgressKeys.empty), findsOneWidget);
      expect(find.textContaining('Сыграй первую партию'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('настройки 320 dp / $scale×: звук и напоминание меняются', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SettingsPrefsStore(prefs);
      final applied = <AppSettings>[];
      await _pump(
        tester,
        SettingsScreen(
          store: store,
          onApply: (next) async {
            applied.add(next);
            return store.save(next);
          },
        ),
        scale: scale,
      );
      expect(tester.takeException(), isNull);
      await _tap(tester, find.byKey(SettingsKeys.sound));
      expect(applied.last.soundOn, isFalse);
      await _tap(tester, find.byKey(SettingsKeys.toggle));
      expect(applied.last.enabled, isTrue);
      await tester.ensureVisible(find.byKey(SettingsKeys.time));
      await tester.pumpAndSettle();
      expect(find.byKey(SettingsKeys.time).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('источники 320 dp / $scale×: документ и лицензии доступны', (
      tester,
    ) async {
      final source = File('assets/ATTRIBUTION.md').readAsStringSync();
      await _pump(tester, AttributionView(source: source), scale: scale);
      expect(find.byKey(AppKeys.sourcesView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _tap(tester, find.byKey(AppKeys.licenses));
      expect(find.byType(LicensePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ответ 320 dp / $scale×: длинный перевод показан целиком', (
      tester,
    ) async {
      var pressed = 0;
      await _pump(
        tester,
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: falling.AnswerButton(
                label: _longTranslation,
                state: falling.AnswerState.idle,
                onTap: () => pressed++,
              ),
            ),
          ),
        ),
        scale: scale,
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text(_longTranslation),
          matching: find.byType(RichText),
        ),
      );
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'Игрок должен прочитать весь русский вариант ответа',
      );
      await tester.tap(find.text(_longTranslation));
      expect(pressed, 1);
      expect(tester.takeException(), isNull);
    });

    for (final isNinja in [false, true]) {
      final game = isNinja ? 'ниндзя-слэш' : 'падающие слова';
      testWidgets('итоги $game 320 dp / $scale×: оба действия доступны', (
        tester,
      ) async {
        var again = 0;
        var exit = 0;
        final summary =
            isNinja
                ? ninja.SummaryView(
                  score: 1200,
                  bestCombo: 12,
                  correctCount: 14,
                  answeredCount: 15,
                  outOfLives: false,
                  footer: 'Ещё есть слова — сыграй ещё раунд',
                  onPlayAgain: () => again++,
                  onExit: () => exit++,
                )
                : falling.SummaryView(
                  score: 1200,
                  bestCombo: 12,
                  correctCount: 14,
                  answeredCount: 15,
                  outOfLives: false,
                  footer: 'Ещё есть слова — сыграй ещё раунд',
                  onPlayAgain: () => again++,
                  onExit: () => exit++,
                );
        await _pump(tester, Scaffold(body: summary), scale: scale);
        expect(find.text('Верных ответов: 14 из 15'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _tap(
          tester,
          find.byKey(
            isNinja
                ? ninja.NinjaKeys.playAgain
                : falling.FallingWordsKeys.playAgain,
          ),
        );
        await _tap(
          tester,
          find.byKey(
            isNinja ? ninja.NinjaKeys.exit : falling.FallingWordsKeys.exit,
          ),
        );
        expect((again, exit), (1, 1));
        expect(tester.takeException(), isNull);
      });

      testWidgets('пустая сессия $game 320 dp / $scale×: выход доступен', (
        tester,
      ) async {
        var exits = 0;
        final page =
            isNinja
                ? ninja.NothingTodayView(onExit: () => exits++)
                : falling.NothingTodayView(onExit: () => exits++);
        await _pump(tester, Scaffold(body: page), scale: scale);
        expect(find.text('На сегодня всё'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _tap(
          tester,
          find.byKey(
            isNinja ? ninja.NinjaKeys.exit : falling.FallingWordsKeys.exit,
          ),
        );
        expect(exits, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
