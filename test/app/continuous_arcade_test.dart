import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/data/challenges/challenge_prefs_store.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/domain/challenges/challenge_session.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/features/games/snake/snake_field.dart';
import 'package:arcadelingo/features/games/snake/snake_game.dart';
import 'package:arcadelingo/features/games/word_maze/word_maze_game.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';
import '../support/maze_actions.dart';

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  const course = StudyCourse.spanishFromRussian;
  const level = CefrLevel.b1;
  const pairs = {'llave': 'ключ', 'silla': 'стул', 'puente': 'мост'};
  const other = ReviewItem(
    word: Word(id: 'a1', text: 'pan', translation: 'хлеб'),
  );
  for (final game in [snakeEntry, wordMazeEntry]) {
    final snake = game == snakeEntry;
    testWidgets(
      '${game.id} opens endless play, saves one answer and a separate record',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final records = ChallengePrefsStore(prefs);
        final settings = SettingsPrefsStore(prefs);
        final language =
            snake ? InterfaceLanguage.english : InterfaceLanguage.spanish;
        final strings = AppStrings(language);
        await settings.save(
          AppSettings.defaults.copyWith(
            theme: snake ? AppTheme.dark : AppTheme.light,
            interfaceLanguage: language,
          ),
        );
        final baseAnswers = InMemoryAnswerLog();
        final answers = InMemoryAnswerLog();
        final cards = InMemoryCardStore();
        final key = (gameId: game.id, courseId: course.id, level: level);
        await records.submit(key, 777);
        await tester.pumpWidget(
          WordarcadeApp(
            ports: AppPorts(
              cards: InMemoryCardStore(),
              streaks: InMemoryStreakStore(),
              answers: baseAnswers,
              settings: settings,
              challengeRecords: records,
            ),
            seed: const Ok([other]),
            additionalDecks: [
              CourseDeck(
                course: course,
                cards: cards,
                streaks: InMemoryStreakStore(),
                answers: answers,
                items: [
                  other,
                  for (final pair in pairs.entries)
                    ReviewItem(
                      word: Word(
                        id: pair.key,
                        text: pair.key,
                        translation: pair.value,
                        level: level,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await _tap(tester, find.byKey(AppKeys.course));
        await _tap(tester, find.byKey(ValueKey('course.${course.id}')));
        await _tap(tester, find.widgetWithText(ChoiceChip, 'B1'));
        await _tap(tester, find.text(game.titleFor(strings)));
        final mode = find.byKey(AppKeys.challenge);
        expect(
          find.descendant(
            of: mode,
            matching: find.text(strings.continuousMode),
          ),
          findsOneWidget,
        );
        await _tap(tester, mode);
        expect(find.text(strings.challengeBest(null)), findsOneWidget);
        await _tap(tester, find.byKey(const Key('challenge.start')));

        final prompt = find.byKey(snake ? SnakeKeys.word : MazeKeys.word);
        final first = tester.widget<Text>(prompt).data!;
        expect(pairs.values, contains(first));
        if (snake) {
          final run =
              tester.widget<SnakeField>(find.byKey(SnakeKeys.field)).run;
          expect(
            run.apples.map((a) => a.word.text),
            unorderedEquals(pairs.keys),
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pump();
          for (var i = 0; i < 90 && answers.records.isEmpty; i++) {
            await tester.pump(const Duration(milliseconds: 20));
          }
        } else {
          final gates = mazeGateWords(tester);
          expect(gates, unorderedEquals(pairs.keys));
          await enterMazeGate(
            tester,
            gates.indexOf(
              pairs.entries.firstWhere((entry) => entry.value == first).key,
            ),
          );
        }
        final second = tester.widget<Text>(prompt).data!;
        expect(second, isNot(first));
        expect(pairs.values, contains(second));
        expect(
          answers.records.single.wordId,
          pairs.entries.firstWhere((entry) => entry.value == first).key,
        );
        await _tap(
          tester,
          find.byKey(snake ? SnakeKeys.pause : MazeKeys.pause),
        );
        await _tap(tester, find.text(strings.finishRun));
        expect(
          find.byKey(snake ? SnakeKeys.summary : MazeKeys.summary),
          findsOneWidget,
        );
        final best = records.load(key, mode: ArcadeChallenge.continuous);
        expect(best, isNotNull);
        expect(records.load(key), 777);
        final otherCourse = (gameId: game.id, courseId: 'ru-en', level: level);
        final otherLevel = (
          gameId: game.id,
          courseId: course.id,
          level: CefrLevel.a1,
        );
        expect(
          records.load(otherCourse, mode: ArcadeChallenge.continuous),
          isNull,
        );
        expect(
          records.load(otherLevel, mode: ArcadeChallenge.continuous),
          isNull,
        );
        expect(cards.saves, hasLength(1));
        expect(baseAnswers.records, isEmpty);
        await _tap(tester, find.text(strings.playAgain));
        expect(find.text(strings.continuousProgress(1)), findsOneWidget);
        await _tap(tester, find.byType(BackButton));
        expect(answers.records, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
