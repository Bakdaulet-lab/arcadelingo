@Tags(['peek'])
library;

import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/features/games/space_word/space_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final now = DateTime(2026, 11, 28, 12);
  late Map<StudyCourse, Result<List<ReviewItem>>> seeds;

  setUpAll(() async {
    seeds = {
      StudyCourse.englishFromRussian: await loadWordsSeed(),
      StudyCourse.spanishFromRussian: await loadSpanishSeed(),
      StudyCourse.englishFromSpanish: await loadEnglishA1FromSpanishSeed(),
      StudyCourse.spanishFromEnglish: await loadSpanishFromEnglishSeed(),
      for (final course in StudyCourse.kazakhCourses)
        course: await loadKazakhSeed(course),
    };
  });

  for (final theme in AppTheme.values) {
    testWidgets('Казахские курсы и Space Word · ${theme.name}', (tester) async {
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
        for (final entry in seeds.entries)
          if (entry.key != StudyCourse.englishFromRussian)
            CourseDeck(
              course: entry.key,
              items: (entry.value as Ok<List<ReviewItem>>).value,
              cards: InMemoryCardStore({
                if (entry.key == StudyCourse.russianFromKazakh)
                  for (final item
                      in (entry.value as Ok<List<ReviewItem>>).value)
                    if (item.word.level == CefrLevel.a1 &&
                        item.word.translation != 'жұмыртқа')
                      item.word.id: LeitnerCard(
                        box: 1,
                        due: now.add(const Duration(days: 2)),
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
          seed: seeds[StudyCourse.englishFromRussian]!,
          additionalDecks: decks,
          now: () => now,
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, find.byKey(AppKeys.course));
      await peek(tester, 'kazakh_course_picker_${theme.name}');
      await _tap(tester, find.byKey(const ValueKey('course.kk-ru')));
      await _tap(tester, find.text('Space Word'));
      await _tap(tester, find.byKey(AppKeys.play));

      final field = tester.element(find.byType(SpaceField));
      final variant = theme == AppTheme.dark ? 'night' : 'day';
      await tester.runAsync(
        () => precacheImage(
          ExactAssetImage(
            'assets/images/space_word/$variant.webp',
            bundle: rootBundle,
          ),
          field,
        ),
      );
      await tester.pump();
      await peek(tester, 'kazakh_space_word_${theme.name}');
    });
  }
}
