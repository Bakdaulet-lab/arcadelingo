@Tags(['peek'])
library;

import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/app/settings_view.dart';
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
  final today = DateTime(2026, 11, 28, 12);
  const course = StudyCourse.spanishFromEnglish;
  late Result<List<ReviewItem>> defaultSeed;
  late List<ReviewItem> spanish;

  setUpAll(() async {
    defaultSeed = await loadWordsSeed();
    spanish =
        (await loadSpanishFromEnglishSeed() as Ok<List<ReviewItem>>).value;
  });

  for (final theme in AppTheme.values) {
    testWidgets('Қазақша интерфейс · ${theme.name}', (tester) async {
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
          interfaceLanguage: InterfaceLanguage.kazakh,
          courseId: course.id,
        ),
      );

      await tester.pumpWidget(
        WordarcadeApp(
          ports: AppPorts(
            cards: InMemoryCardStore(),
            streaks: InMemoryStreakStore(),
            settings: settings,
          ),
          seed: defaultSeed,
          additionalDecks: [
            CourseDeck(
              course: course,
              items: spanish,
              // A predictable English clue and Spanish answers demonstrate
              // that the selected Kazakh UI belongs to the app, not the deck.
              cards: InMemoryCardStore({
                for (final item in spanish)
                  if (item.word.level == CefrLevel.a1 &&
                      item.word.text != 'leche')
                    item.word.id: LeitnerCard(
                      box: 1,
                      due: today.add(const Duration(days: 2)),
                    ),
              }),
              answers: InMemoryAnswerLog(),
              streaks: InMemoryStreakStore(),
            ),
          ],
          now: () => today,
        ),
      );
      await tester.pumpAndSettle();
      await peek(tester, 'kazakh_interface_home_${theme.name}');

      await _tap(tester, find.byKey(AppKeys.settings));
      await peek(tester, 'kazakh_interface_settings_${theme.name}');
      await _tap(tester, find.byKey(SettingsKeys.language));
      await peek(tester, 'kazakh_interface_languages_${theme.name}');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Space Word'));
      await _tap(tester, find.byKey(AppKeys.play));

      final space = tester.element(find.byType(SpaceField));
      final variant = theme == AppTheme.dark ? 'night' : 'day';
      await tester.runAsync(
        () => precacheImage(
          ExactAssetImage(
            'assets/images/space_word/$variant.webp',
            bundle: rootBundle,
          ),
          space,
        ),
      );
      await tester.pump();
      await peek(tester, 'kazakh_interface_game_${theme.name}');
    });
  }
}
