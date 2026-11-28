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

const _featuredWords = {
  'ru-fr': 'fr_ecole',
  'ru-zh': 'zh_xuexiao',
  'ru-ar': 'ar_school',
};

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
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
      for (final course in StudyCourse.multilingualCourses)
        course: await loadMultilingualSeed(course),
    };
  });

  for (final theme in AppTheme.values) {
    for (final featured in _featuredWords.entries) {
      final course = StudyCourse.multilingualCourses.singleWhere(
        (course) => course.id == featured.key,
      );
      final language = course.studyLanguage;
      testWidgets('Карточка ${course.id} · ${theme.name}', (tester) async {
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
            if (entry.value case Ok(:final value))
              CourseDeck(
                course: entry.key,
                items: value,
                // Make the same real card available first in both themes.
                cards: InMemoryCardStore({
                  if (entry.key == course)
                    for (final item in value)
                      if (item.word.level == CefrLevel.a1 &&
                          item.word.id != featured.value)
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
        if (language == 'zh') {
          await tester.ensureVisible(
            find.byKey(const ValueKey('course.ru-ar')),
          );
          await tester.pumpAndSettle();
          await peek(tester, 'multilingual_courses_picker_${theme.name}');
        }
        await _tap(tester, find.byKey(ValueKey('course.${course.id}')));
        await _tap(tester, find.text('Автомат с клешнёй'));
        await _tap(tester, find.byKey(AppKeys.learn));
        await peek(tester, 'multilingual_courses_${language}_${theme.name}');

        if (language != 'fr') {
          await _tap(tester, find.byKey(LearningKeys.start));
          await peek(
            tester,
            'multilingual_courses_${language}_claw_${theme.name}',
          );
        }
      });
    }
  }
}
