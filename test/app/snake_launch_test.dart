import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/data/challenges/challenge_prefs_store.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/features/games/snake/snake_field.dart';
import 'package:arcadelingo/features/games/snake/snake_game.dart';
import 'package:arcadelingo/features/games/snake/snake_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';

final _now = DateTime(2026, 11, 21);
const _tick = SnakeRun.stepTime;

const _levels = {
  StudyCourse.englishFromRussian: CefrLevel.values,
  StudyCourse.spanishFromRussian: [
    CefrLevel.a1,
    CefrLevel.a2,
    CefrLevel.b1,
    CefrLevel.b2,
    CefrLevel.c1,
  ],
  StudyCourse.spanishFromEnglish: [
    CefrLevel.a1,
    CefrLevel.a2,
    CefrLevel.b1,
    CefrLevel.b2,
    CefrLevel.c1,
  ],
  StudyCourse.englishFromSpanish: [CefrLevel.a1],
};

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _steer(
  WidgetTester tester,
  Finder field,
  SnakeDirection direction, {
  required bool swipe,
}) async {
  if (swipe) {
    final offset = switch (direction) {
      SnakeDirection.up => const Offset(0, -56),
      SnakeDirection.right => const Offset(56, 0),
      SnakeDirection.down => const Offset(0, 56),
      SnakeDirection.left => const Offset(-56, 0),
    };
    await tester.ensureVisible(field);
    await tester.pump();
    await tester.drag(field, offset);
  } else {
    final key = switch (direction) {
      SnakeDirection.up => LogicalKeyboardKey.arrowUp,
      SnakeDirection.right => LogicalKeyboardKey.arrowRight,
      SnakeDirection.down => LogicalKeyboardKey.arrowDown,
      SnakeDirection.left => LogicalKeyboardKey.arrowLeft,
    };
    await tester.sendKeyEvent(key);
  }
  await tester.pump();
}

Future<void> _reachApple(
  WidgetTester tester,
  Finder field,
  SnakeCell target, {
  required bool swipe,
  required bool checkPause,
}) async {
  SnakeCell head() => tester.widget<SnakeField>(field).run.body.first;
  final route = switch (target) {
    (x: 3, y: 2) => [
      (SnakeDirection.up, (x: 5, y: 2)),
      (SnakeDirection.left, target),
    ],
    (x: 8, y: 6) => [(SnakeDirection.right, target)],
    (x: 8, y: 9) => [
      (SnakeDirection.down, (x: 5, y: 9)),
      (SnakeDirection.right, target),
    ],
    _ => throw ArgumentError.value(target, 'target', 'Opening apple position'),
  };
  for (final (index, (direction, stop)) in route.indexed) {
    await _steer(tester, field, direction, swipe: swipe);
    if (index == 0 && checkPause) {
      await _tap(tester, find.byKey(SnakeKeys.pause));
      final stopped = head();
      await tester.pump(const Duration(seconds: 2));
      expect(head(), stopped);
      await tester.tap(find.byKey(SnakeKeys.resume));
      await tester.pump();
    }
    for (var step = 0; step < 4 && head() != stop; step++) {
      await tester.pump(_tick);
    }
    expect(head(), stop);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<StudyCourse, List<ReviewItem>> seeds;

  setUpAll(() async {
    seeds = {
      StudyCourse.englishFromRussian:
          (await loadWordsSeed() as Ok<List<ReviewItem>>).value,
      StudyCourse.spanishFromRussian:
          (await loadSpanishSeed() as Ok<List<ReviewItem>>).value,
      StudyCourse.spanishFromEnglish:
          (await loadSpanishFromEnglishSeed() as Ok<List<ReviewItem>>).value,
      StudyCourse.englishFromSpanish:
          (await loadEnglishA1FromSpanishSeed() as Ok<List<ReviewItem>>).value,
    };
  });

  for (final theme in AppTheme.values) {
    for (final MapEntry(key: course, value: levels) in _levels.entries) {
      for (final level in levels) {
        testWidgets(
          'Snake via home: ${course.id}/${level.name}/${theme.name}',
          (tester) async {
            tester.view.physicalSize = const Size(320, 780);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            SharedPreferences.setMockInitialValues({});
            final preferences = await SharedPreferences.getInstance();
            final settings = SettingsPrefsStore(preferences);
            await settings.save(
              AppSettings.defaults.copyWith(
                theme: theme,
                interfaceLanguage: InterfaceLanguage.russian,
              ),
            );
            final records = ChallengePrefsStore(preferences);

            final words =
                seeds[course]!
                    .where((item) => item.word.level == level)
                    .map((item) => item.word)
                    .toList();
            final target = words.first;
            // Only this card is due. Other cards still supply the apples for
            // this level, even though they are not due for review.
            final decks = {
              for (final MapEntry(key: choice, value: items) in seeds.entries)
                choice: CourseDeck(
                  course: choice,
                  items: items,
                  cards: InMemoryCardStore({
                    if (choice == course)
                      for (final word in words.skip(1))
                        word.id: LeitnerCard(
                          box: 2,
                          due: _now.add(const Duration(days: 7)),
                        ),
                  }),
                  streaks: InMemoryStreakStore(),
                  answers: InMemoryAnswerLog(),
                ),
            };
            final base = decks[StudyCourse.englishFromRussian]!;
            final chosen = decks[course]!;
            await tester.pumpWidget(
              WordarcadeApp(
                ports: AppPorts(
                  cards: base.cards,
                  streaks: base.streaks,
                  answers: base.answers,
                  settings: settings,
                  challengeRecords: records,
                ),
                seed: Ok(base.items),
                additionalDecks: [
                  for (final deck in decks.values)
                    if (deck != base) deck,
                ],
                now: () => _now,
              ),
            );
            await tester.pumpAndSettle();

            if (course != base.course) {
              await _tap(tester, find.byKey(AppKeys.course));
              await _tap(tester, find.byKey(ValueKey('course.${course.id}')));
            }
            await _tap(
              tester,
              find.widgetWithText(ChoiceChip, level.name.toUpperCase()),
            );
            await _tap(tester, find.text('Змейка'));
            await _tap(tester, find.byKey(AppKeys.play));

            final field = find.byKey(SnakeKeys.field);
            expect(find.byType(SnakeGame), findsOneWidget);
            expect(
              Theme.of(tester.element(field)).brightness,
              theme == AppTheme.light ? Brightness.light : Brightness.dark,
            );
            expect(
              tester.widget<Text>(find.byKey(SnakeKeys.word)).data,
              target.translation,
            );
            final apples = tester.widget<SnakeField>(field).run.apples;
            final allowedIds = words.map((word) => word.id).toSet();
            expect(apples, hasLength(3));
            expect(
              apples.map((apple) => apple.word.text).toSet(),
              hasLength(3),
            );
            for (final apple in apples) {
              expect(allowedIds, contains(apple.word.id));
              expect(apple.word.level, level);
              expect(words, contains(apple.word));
              expect(
                find.descendant(
                  of: field,
                  matching: find.text(apple.word.text),
                ),
                findsOneWidget,
              );
            }

            final correct = apples.singleWhere(
              (apple) => apple.word.id == target.id,
            );
            await _reachApple(
              tester,
              field,
              correct.cell,
              swipe: theme == AppTheme.light,
              checkPause:
                  course == StudyCourse.spanishFromEnglish &&
                  level == CefrLevel.b1 &&
                  theme == AppTheme.dark,
            );
            final answers = chosen.answers as InMemoryAnswerLog;
            expect(answers.records, hasLength(1));
            expect(answers.records.single.wordId, target.id);
            expect(answers.records.single.gameId, 'snake');
            expect(answers.records.single.correct, isTrue);

            await _tap(tester, find.byKey(SnakeKeys.next));
            expect(find.byKey(SnakeKeys.summary), findsOneWidget);
            expect(
              (chosen.cards as InMemoryCardStore).saves.single.keys,
              contains(target.id),
            );
            for (final deck in decks.values.where((deck) => deck != chosen)) {
              expect((deck.answers as InMemoryAnswerLog).records, isEmpty);
              expect((deck.cards as InMemoryCardStore).saves, isEmpty);
              final otherCourse = (
                gameId: 'snake',
                courseId: deck.course.id,
                level: level,
              );
              expect(records.load(otherCourse), isNull);
            }
            final scoreKey = (
              gameId: 'snake',
              courseId: course.id,
              level: level,
            );
            final otherLevel = (
              gameId: 'snake',
              courseId: course.id,
              level: level == CefrLevel.a1 ? CefrLevel.a2 : CefrLevel.a1,
            );
            expect(records.load(scoreKey), 100);
            expect(records.load(otherLevel), isNull);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
