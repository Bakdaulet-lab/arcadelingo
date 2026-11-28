import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/data/daily_word/daily_word_prefs_store.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';

const _open = Key('app.daily-word');
const _input = Key('dailyWord.input');
const _submit = Key('dailyWord.submit');
const _share = Key('dailyWord.share');

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'home opens a course and level puzzle, resumes its result and rolls over at midnight',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var now = DateTime(2026, 11, 25, 23, 59, 30);
      final firstDay = now;
      const course = StudyCourse.spanishFromRussian;
      final english = DailyWordPrefsStore(
        prefs,
        courseId: StudyCourse.englishFromRussian.id,
      );
      final spanish = DailyWordPrefsStore(prefs, courseId: course.id);
      const level = CefrLevel.b1;
      await tester.pumpWidget(
        WordarcadeApp(
          now: () => now,
          ports: AppPorts(
            cards: InMemoryCardStore(),
            streaks: InMemoryStreakStore(),
            settings: SettingsPrefsStore(prefs),
            dailyWord: english,
          ),
          seed: const Ok([
            ReviewItem(
              word: Word(id: 'en_beach', text: 'beach', translation: 'пляж'),
            ),
          ]),
          additionalDecks: [
            CourseDeck(
              course: course,
              cards: InMemoryCardStore(),
              streaks: InMemoryStreakStore(),
              answers: InMemoryAnswerLog(),
              dailyWord: spanish,
              items: const [
                ReviewItem(
                  word: Word(
                    id: 'es_coche',
                    text: 'coche',
                    translation: 'автомобиль',
                  ),
                ),
                ReviewItem(
                  word: Word(
                    id: 'es_playa',
                    text: 'playa',
                    translation: 'пляж',
                    level: level,
                  ),
                ),
                ReviewItem(
                  word: Word(
                    id: 'es_campo',
                    text: 'campo',
                    translation: 'поле',
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
      await _tap(tester, find.text('B1'));
      await _tap(tester, find.byKey(_open));
      final beach = find.textContaining('пляж').evaluate().isNotEmpty;
      final clue = beach ? 'пляж' : 'поле';
      final answer = beach ? 'playa' : 'campo';
      final miss = beach ? 'campo' : 'playa';
      expect(find.textContaining(clue), findsOneWidget);
      expect(find.textContaining('автомобиль'), findsNothing);
      await tester.enterText(find.byKey(_input), miss);
      await _tap(tester, find.byKey(_submit));
      expect(spanish.load(level: level, day: firstDay)!.guesses, [miss]);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(_open));
      await tester.enterText(find.byKey(_input), answer);
      await _tap(tester, find.byKey(_submit));
      expect(find.byKey(_share), findsOneWidget);
      final saved = spanish.load(level: level, day: firstDay)!;
      expect(saved.finished, isTrue);
      expect(saved.guesses, [miss, answer]);
      expect(english.load(level: level, day: firstDay), isNull);
      expect(spanish.load(level: CefrLevel.a1, day: firstDay), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(_open));
      expect(find.byKey(_share), findsOneWidget);
      now = DateTime(2026, 11, 26);
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.textContaining(beach ? 'поле' : 'пляж'), findsOneWidget);
      expect(find.byKey(_input), findsOneWidget);
      expect(find.byKey(_share), findsNothing);
      expect(spanish.load(level: level, day: firstDay)!.guesses, [
        miss,
        answer,
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}
