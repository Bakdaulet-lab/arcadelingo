@Tags(['peek'])
library;

import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/app/learning_views.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';
import 'peek_harness.dart';

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  const germanFromRussian = StudyCourse.germanFromRussian;
  final today = DateTime(2026, 11, 28, 12);
  late Result<List<ReviewItem>> defaultSeed;
  late Map<StudyCourse, Result<List<ReviewItem>>> additionalSeeds;

  setUpAll(() async {
    defaultSeed = await loadWordsSeed();
    additionalSeeds = {
      StudyCourse.spanishFromRussian: await loadSpanishSeed(),
      StudyCourse.englishFromSpanish: await loadEnglishA1FromSpanishSeed(),
      StudyCourse.spanishFromEnglish: await loadSpanishFromEnglishSeed(),
      for (final course in StudyCourse.kazakhCourses)
        course: await loadKazakhSeed(course),
      for (final course in StudyCourse.germanCourses)
        course: await loadGermanSeed(course),
    };
  });

  for (final theme in AppTheme.values) {
    testWidgets('Немецкий курс и слово der Apfel · ${theme.name}', (
      tester,
    ) async {
      tester.view.physicalSize = peekPhysicalSize;
      tester.view.devicePixelRatio = peekDevicePixelRatio;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsPrefsStore(
        await SharedPreferences.getInstance(),
      );
      await settings.save(
        AppSettings.defaults.copyWith(
          theme: theme,
          interfaceLanguage: InterfaceLanguage.russian,
        ),
      );

      final decks = [
        for (final entry in additionalSeeds.entries)
          CourseDeck(
            course: entry.key,
            items: (entry.value as Ok<List<ReviewItem>>).value,
            // Keep the first new-word card and game prompt reproducible while
            // retaining the entire bundled dictionary and all course levels.
            cards: InMemoryCardStore({
              if (entry.key == germanFromRussian)
                for (final item in (entry.value as Ok<List<ReviewItem>>).value)
                  if (item.word.level == CefrLevel.a1 &&
                      item.word.id != 'de_apfel')
                    item.word.id: LeitnerCard(
                      box: 1,
                      due: today.add(const Duration(days: 2)),
                    ),
            }),
            answers: InMemoryAnswerLog(),
            streaks: InMemoryStreakStore(),
          ),
      ];
      await tester.pumpWidget(
        WordarcadeApp(
          ports: AppPorts(
            cards: InMemoryCardStore(),
            streaks: InMemoryStreakStore(),
            settings: settings,
          ),
          seed: defaultSeed,
          additionalDecks: decks,
          now: () => today,
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, find.byKey(AppKeys.course));
      await tester.ensureVisible(find.byKey(const ValueKey('course.kk-de')));
      await tester.pumpAndSettle();
      await peek(tester, 'german_courses_picker_${theme.name}');

      await _tap(tester, find.byKey(const ValueKey('course.ru-de')));
      await peek(tester, 'german_courses_home_${theme.name}');

      await _tap(tester, find.text('Автомат с клешнёй'));
      await _tap(tester, find.byKey(AppKeys.learn));
      await peek(tester, 'german_courses_apfel_${theme.name}');
      await _tap(tester, find.byKey(LearningKeys.start));
      await peek(tester, 'german_courses_claw_${theme.name}');
    });
  }
}
