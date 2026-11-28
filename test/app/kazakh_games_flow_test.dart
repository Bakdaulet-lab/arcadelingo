import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/kitchen/kitchen_shift.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_field.dart';
import 'package:arcadelingo/features/games/order_kitchen/order_kitchen_game.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/word_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bundled_fonts.dart';
import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 420));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<StudyCourse, List<ReviewItem>> catalogues;
  setUpAll(() async {
    await loadBundledFonts();
    catalogues = {
      for (final course in StudyCourse.kazakhCourses)
        course: (await loadKazakhSeed(course) as Ok<List<ReviewItem>>).value,
    };
  });

  testWidgets('English C1 phrases have a localized card label', (tester) async {
    final word =
        catalogues[StudyCourse.englishFromKazakh]!
            .firstWhere((item) => item.word.partOfSpeech == 'phrase')
            .word;
    for (final (locale, label) in [('ru', 'Выражение'), ('es', 'Expresión')]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          supportedLocales: const [Locale('ru'), Locale('es')],
          localizationsDelegates: const [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(body: WordPanel(word: word)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
      expect(find.text(word.translation), findsOneWidget);
    }
  });

  for (final (index, course) in StudyCourse.kazakhCourses.indexed) {
    final language =
        [
          InterfaceLanguage.russian,
          InterfaceLanguage.english,
          InterfaceLanguage.spanish,
        ][index];
    for (final level in CefrLevel.values.take(5)) {
      testWidgets(
        '${course.id} ${level.name} routes its own words into arcade games',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          SharedPreferences.setMockInitialValues({});
          final settings = SettingsPrefsStore(
            await SharedPreferences.getInstance(),
          );
          await settings.save(
            AppSettings.defaults.copyWith(
              theme: index.isEven ? AppTheme.dark : AppTheme.light,
              interfaceLanguage: language,
            ),
          );
          GameLaunch? last;
          final games = [
            for (final entry in wordarcadeGames)
              GameEntry(
                id: entry.id,
                title: entry.title,
                artwork: entry.artwork,
                instruction: entry.instruction,
                challenge: entry.challenge,
                tracksRoundScore: entry.tracksRoundScore,
                roundLimit: entry.roundLimit,
                build: (launch) {
                  last = launch;
                  return entry.build(launch);
                },
              ),
          ];
          await tester.pumpWidget(
            WordarcadeApp(
              now: () => DateTime(2026, 12, 1, 10),
              games: games,
              ports: AppPorts(
                cards: InMemoryCardStore(),
                streaks: InMemoryStreakStore(),
                settings: settings,
              ),
              seed: const Ok([
                ReviewItem(
                  word: Word(id: 'base', text: 'sky', translation: 'небо'),
                ),
              ]),
              additionalDecks: [
                for (final MapEntry(key: course, value: words)
                    in catalogues.entries)
                  CourseDeck(
                    course: course,
                    items: words,
                    cards: InMemoryCardStore(),
                    answers: InMemoryAnswerLog(),
                    streaks: InMemoryStreakStore(),
                  ),
              ],
            ),
          );
          await tester.pumpAndSettle();
          await _tap(tester, find.byKey(AppKeys.course));
          final strings = AppStrings(language);
          for (final option in StudyCourse.kazakhCourses) {
            expect(find.text(strings.courseName(option)), findsOneWidget);
          }
          await _tap(tester, find.byKey(ValueKey('course.${course.id}')));
          expect(
            (settings.load() as Ok<AppSettings>).value.courseId,
            course.id,
          );
          expect(
            (settings.load() as Ok<AppSettings>).value.interfaceLanguage,
            language,
          );
          expect(find.widgetWithText(ChoiceChip, 'C2'), findsNothing);
          await _tap(
            tester,
            find.widgetWithText(ChoiceChip, level.name.toUpperCase()),
          );
          final authorized = [
            for (final item in catalogues[course]!)
              if (item.word.level == level) item.word,
          ];
          // Every game actually opens in each of the three courses. Levels A1–B2
          // also exercise the normal home path with a rotating selection.
          final entries =
              level == CefrLevel.c1
                  ? games
                  : [games[(level.index + index) % games.length]];
          for (final entry in entries) {
            last = null;
            await _tap(tester, find.text(entry.titleFor(strings)).first);
            await _tap(tester, find.byKey(AppKeys.play));
            expect(last?.course, course);
            expect(last?.level, level);
            expect(last?.vocabulary, unorderedEquals(authorized));
            expect(last?.session.total, entry.roundLimit ?? sessionTarget);
            if (entry.id == 'claw_machine' &&
                course == StudyCourse.russianFromKazakh) {
              final field = tester.widget<ClawMachineField>(
                find.byType(ClawMachineField),
              );
              expect(
                field.stacks.expand((stack) => stack),
                everyElement(matches(RegExp(r'^[А-ЯЁ0-9]$'))),
              );
            }
            expect(tester.takeException(), isNull);
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
          }
          final kitchen = find.byKey(AppKeys.orderKitchen);
          if (level == CefrLevel.a1) {
            await _tap(tester, kitchen);
            final game = tester.widget<OrderKitchenGame>(
              find.byType(OrderKitchenGame),
            );
            final order =
                kitchenOrdersFor(
                  course: course,
                  level: level,
                  seed: game.seed,
                ).first;
            expect(game.course, course);
            expect(
              find.text(order.phrase(course.studyLanguage)),
              findsOneWidget,
            );
            for (final ingredient in order.ingredients) {
              await _tap(
                tester,
                find.byKey(Key('kitchen.ingredient.${ingredient.name}')),
              );
            }
            await _tap(tester, find.byKey(const Key('kitchen.serve')));
            expect(find.text(order.phrase('kk')), findsOneWidget);
          } else {
            expect(kitchen, findsNothing);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
