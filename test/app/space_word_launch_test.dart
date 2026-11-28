import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/app/learning_views.dart';
import 'package:arcadelingo/data/challenges/challenge_prefs_store.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/review/word_labels.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/features/games/space_word/space_field.dart';
import 'package:arcadelingo/features/games/space_word/space_word_game.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bundled_fonts.dart';
import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';
import '../support/space_actions.dart';

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 480));
  await tester.pump();
}

// Fly this storage-and-routing scenario with three unambiguous real signs.
// Other levels and courses stay in the fixture to catch scope leaks.
List<Word> _missionWords(List<ReviewItem> items, CefrLevel level) {
  final candidates = [
    for (final item in items)
      if (item.word.level == level) item.word,
  ]..sort((a, b) {
    final byWidth = a.text.length.compareTo(b.text.length);
    return byWidth != 0 ? byWidth : a.id.compareTo(b.id);
  });
  final words = <Word>[];
  final meanings = <String>{};
  for (final word in candidates) {
    final senses = translationMeanings(word.translation);
    if (senses.any(meanings.contains) ||
        words.any((w) => w.text == word.text)) {
      continue;
    }
    words.add(word);
    meanings.addAll(senses);
    if (words.length == 3) break;
  }
  return words;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 11, 25);
  late Map<StudyCourse, List<ReviewItem>> catalogues;
  setUpAll(() async {
    await loadBundledFonts();
    catalogues = {
      StudyCourse.englishFromRussian:
          (await loadWordsSeed() as Ok<List<ReviewItem>>).value,
      StudyCourse.spanishFromRussian:
          (await loadSpanishSeed() as Ok<List<ReviewItem>>).value,
      StudyCourse.englishFromSpanish:
          (await loadEnglishA1FromSpanishSeed() as Ok<List<ReviewItem>>).value,
      StudyCourse.spanishFromEnglish:
          (await loadSpanishFromEnglishSeed() as Ok<List<ReviewItem>>).value,
    };
  });
  final scopes = {
    StudyCourse.englishFromRussian: CefrLevel.values,
    StudyCourse.spanishFromRussian: CefrLevel.values.take(5),
    StudyCourse.spanishFromEnglish: CefrLevel.values.take(5),
    StudyCourse.englishFromSpanish: [CefrLevel.a1],
  };
  var index = 0;
  for (final scope in scopes.entries) {
    final course = scope.key;
    for (final level in scope.value) {
      final n = index++;
      final language =
          [
            InterfaceLanguage.russian,
            InterfaceLanguage.english,
            InterfaceLanguage.spanish,
          ][n % 3];
      final theme = n.isEven ? AppTheme.dark : AppTheme.light;
      final learn = level == CefrLevel.b1;
      testWidgets(
        'Space Word from home ${course.id}/${level.name} in ${language.name}, ${theme.name}',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final records = ChallengePrefsStore(prefs);
          final settings = SettingsPrefsStore(prefs);
          await settings.save(
            AppSettings.defaults.copyWith(
              theme: theme,
              interfaceLanguage: language,
            ),
          );
          final words = _missionWords(catalogues[course]!, level);
          expect(words, hasLength(3));
          final target = words.first;
          final decks = {
            for (final catalogue in catalogues.entries)
              catalogue.key: CourseDeck(
                course: catalogue.key,
                items:
                    catalogue.key == course
                        ? [
                          for (final item in catalogue.value)
                            if (item.word.level != level ||
                                words.contains(item.word))
                              item,
                        ]
                        : catalogue.value,
                cards: InMemoryCardStore({
                  if (catalogue.key == course)
                    for (final word in words.skip(1))
                      word.id: LeitnerCard(
                        box: 2,
                        due: now.add(const Duration(days: 7)),
                      ),
                }),
                streaks: InMemoryStreakStore(),
                answers: InMemoryAnswerLog(),
              ),
          };
          final base = decks[StudyCourse.englishFromRussian]!;
          final selected = decks[course]!;
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
              additionalDecks: decks.values.where((d) => d != base).toList(),
              now: () => now,
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
          await _tap(
            tester,
            find.text(spaceWordEntry.titleFor(AppStrings(language))),
          );
          await _tap(tester, find.byKey(learn ? AppKeys.learn : AppKeys.play));
          if (learn) {
            final intro = tester.widget<WordIntroductionScreen>(
              find.byType(WordIntroductionScreen),
            );
            expect(intro.words.map((w) => w.id), [target.id]);
            await _tap(tester, find.byKey(LearningKeys.start));
          }
          expect(
            tester.widget<Text>(find.byKey(SpaceWordKeys.prompt)).data,
            target.translation,
          );
          await _tap(tester, find.byKey(SpaceWordKeys.start));
          final drones =
              tester.widget<SpaceField>(find.byType(SpaceField)).labels;
          expect(drones, hasLength(3));
          expect(drones.toSet(), hasLength(3));
          expect(drones, everyElement(isIn(words.map((w) => w.text))));
          final pick =
              learn
                  ? drones.indexWhere((w) => w != target.text)
                  : drones.indexOf(target.text);
          await shootSpaceWord(tester, drones[pick]);
          if (learn) await shootSpaceWord(tester, target.text);
          final result = (selected.answers as InMemoryAnswerLog).records.single;
          expect(result.wordId, target.id);
          expect(result.gameId, 'space_word');
          expect(result.correct, !learn);
          // The history keeps the wrong spelling for mistake review.
          expect(result.selectedAnswer, learn ? drones[pick] : null);
          expect(find.byKey(SpaceWordKeys.summary), findsOneWidget);
          if (learn) {
            await _tap(tester, find.byKey(const Key('game.review_mistakes')));
            final review = tester.widget<MistakesReviewScreen>(
              find.byType(MistakesReviewScreen),
            );
            expect(review.words.single.id, target.id);
            expect(find.text(drones[pick]), findsOneWidget);
          }
          expect(
            (selected.cards as InMemoryCardStore).saves.single.keys,
            contains(target.id),
          );
          final scoreKey = (
            gameId: 'space_word',
            courseId: course.id,
            level: level,
          );
          expect(records.load(scoreKey), isNotNull);
          expect(
            records.load((gameId: 'snake', courseId: course.id, level: level)),
            isNull,
          );
          final anotherLevel =
              level == CefrLevel.a1 ? CefrLevel.a2 : CefrLevel.a1;
          final otherLevelKey = (
            gameId: 'space_word',
            courseId: course.id,
            level: anotherLevel,
          );
          expect(records.load(otherLevelKey), isNull);
          for (final deck in decks.values.where((d) => d != selected)) {
            expect((deck.answers as InMemoryAnswerLog).records, isEmpty);
            final otherCourse = (
              gameId: 'space_word',
              courseId: deck.course.id,
              level: level,
            );
            expect(records.load(otherCourse), isNull);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
