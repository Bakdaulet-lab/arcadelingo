import 'dart:async';

import 'package:arcadelingo/app/story_views.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/stories/situation_story.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/bundled_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);
  for (final locale in ['ru', 'en', 'es']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'two rounds then a practical decision ($locale, ${brightness.name})',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final story = SituationStory(
            situation: StorySituation.station,
            firstRound: const [
              ReviewItem(
                word: Word(
                  id: 'billete',
                  text: 'billete',
                  translation: 'ticket',
                ),
              ),
            ],
            secondRound: const [
              ReviewItem(
                word: Word(id: 'andén', text: 'andén', translation: 'platform'),
              ),
            ],
            clue: 'El tren sale del andén cuatro.',
            question: 'Which platform should you go to?',
            choices: const ['Platform two', 'Platform four', 'Platform eight'],
            correctIndex: 1,
            explanation: 'The train leaves from platform four.',
          );
          final stages = <int>[];
          var attempt = Completer<bool>();
          await tester.pumpWidget(
            MaterialApp(
              theme: wordarcadeTheme(brightness: brightness),
              locale: Locale(locale),
              supportedLocales: const [
                Locale('ru'),
                Locale('en'),
                Locale('es'),
              ],
              localizationsDelegates: const [
                AppStrings.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(1.8)),
                    child: child!,
                  ),
              home: SituationStoriesScreen(
                course: StudyCourse.spanishFromEnglish,
                level: CefrLevel.a1,
                stories: [story],
                playStage: (selected, stage) {
                  expect(selected, same(story));
                  stages.add(stage);
                  return attempt.future;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          final strings =
              tester.element(find.byType(SituationStoriesScreen)).strings;
          expect(find.text(strings.situationStories), findsOneWidget);
          Future<void> tap(String key) async {
            final target = find.byKey(ValueKey(key));
            await tester.ensureVisible(target);
            await tester.tap(target);
            await tester.pumpAndSettle();
          }

          await tap('story.station');
          expect(find.text(strings.wordMahjong), findsOneWidget);
          expect(find.byKey(const Key('story.final')), findsNothing);
          await tap('story.play');
          expect(stages, [0]);
          await tap('story.play');
          expect(stages, [0]);
          attempt.complete(false);
          await tester.pumpAndSettle();
          expect(find.text(strings.wordMahjong), findsOneWidget);
          attempt = Completer<bool>();
          await tap('story.play');
          attempt.complete(true);
          await tester.pumpAndSettle();
          expect(find.text(strings.fallingWords), findsOneWidget);
          attempt = Completer<bool>();
          await tap('story.play');
          attempt.complete(true);
          await tester.pumpAndSettle();
          expect(stages, [0, 0, 1]);
          expect(find.text(story.clue), findsOneWidget);
          expect(find.text(story.question), findsOneWidget);
          expect(find.text(story.explanation), findsNothing);
          await tap('story.answer.0');
          expect(find.byKey(const Key('story.final')), findsOneWidget);
          expect(find.byKey(const Key('story.complete')), findsNothing);
          await tap('story.answer.1');
          expect(find.byKey(const Key('story.complete')), findsOneWidget);
          expect(find.text(story.explanation), findsOneWidget);
          await tap('story.done');
          expect(find.byKey(const Key('story.station')), findsOneWidget);
          expect(stages, [0, 0, 1]);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
