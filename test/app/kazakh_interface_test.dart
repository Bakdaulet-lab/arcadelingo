import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/app/settings_view.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bundled_fonts.dart';
import '../support/fake_reminders.dart';
import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';

const _baseWord = ReviewItem(
  word: Word(id: 'fish', text: 'fish', translation: 'рыба'),
);
const _kazakhLanguage = ValueKey('settings.language.kk');
const _englishLanguage = ValueKey('settings.language.en');
const _spanishCourse = ValueKey('course.ru-es');
const _kazakhEnglishCourse = ValueKey('course.kk-en');
const _kk = AppStrings(InterfaceLanguage.kazakh);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, Key menu, Key item) async {
  await _tap(tester, find.byKey(menu));
  await _tap(tester, find.byKey(item));
}

void _size(WidgetTester tester, {required double scale}) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('Kazakh interface survives course switches and a restart', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsPrefsStore(prefs);
    final reminders = FakeReminders();
    await store.save(
      AppSettings.defaults.copyWith(
        interfaceLanguage: InterfaceLanguage.english,
        enabled: true,
      ),
    );
    final decks = [
      for (final (course, word) in const [
        (
          StudyCourse.spanishFromRussian,
          Word(
            id: 'pez',
            text: 'pez',
            translation: 'рыба',
            partOfSpeech: 'noun',
          ),
        ),
        (
          StudyCourse.englishFromKazakh,
          Word(
            id: 'egg',
            text: 'egg',
            translation: 'жұмыртқа',
            partOfSpeech: 'noun',
          ),
        ),
      ])
        CourseDeck(
          course: course,
          items: [ReviewItem(word: word)],
          cards: InMemoryCardStore(),
          streaks: InMemoryStreakStore(),
          answers: InMemoryAnswerLog(),
        ),
    ];
    WordarcadeApp app() => WordarcadeApp(
      ports: AppPorts(
        cards: InMemoryCardStore(),
        streaks: InMemoryStreakStore(),
        settings: store,
        reminders: reminders,
      ),
      seed: const Ok([_baseWord]),
      additionalDecks: decks,
      now: () => DateTime(2026, 12, 4, 10),
    );
    _size(tester, scale: 1);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(AppKeys.settings));
    await _choose(tester, SettingsKeys.language, _kazakhLanguage);
    expect(find.text('Баптаулар'), findsOneWidget);
    expect(find.byTooltip('Артқа'), findsOneWidget);
    expect(reminders.current?.title, _kk.timeToReturn);
    await _tap(tester, find.byKey(SettingsKeys.time));
    expect(find.text(_kk.reminderTime), findsOneWidget);
    await _tap(tester, find.text(_kk.cancel));
    await _tap(tester, find.byTooltip('Артқа'));

    await _choose(tester, AppKeys.course, _spanishCourse);
    expect(
      find.text(_kk.courseName(StudyCourse.spanishFromRussian)),
      findsOneWidget,
    );
    await _tap(tester, find.byKey(AppKeys.learn));
    expect(find.text('pez'), findsOneWidget);
    expect(find.text('рыба'), findsOneWidget);
    expect(find.text('Зат есім'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await _choose(tester, AppKeys.course, _kazakhEnglishCourse);
    final kazakhCourseName = _kk.courseName(StudyCourse.englishFromKazakh);
    expect(find.text(kazakhCourseName), findsOneWidget);

    await prefs.reload();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text(kazakhCourseName), findsOneWidget);
    expect(
      (store.load() as Ok<AppSettings>).value.interfaceLanguage,
      InterfaceLanguage.kazakh,
    );
    expect((store.load() as Ok<AppSettings>).value.courseId, 'kk-en');
    await _tap(tester, find.byKey(AppKeys.settings));
    await _choose(tester, SettingsKeys.language, _englishLanguage);
    await _tap(tester, find.byTooltip('Back'));
    expect(find.text('English · Kazakh translations'), findsOneWidget);
    expect((store.load() as Ok<AppSettings>).value.courseId, 'kk-en');
  });

  testWidgets('device Kazakh works and the language menu fits at 200%', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    _size(tester, scale: 2);
    tester.platformDispatcher.localesTestValue = const [Locale('kk', 'KZ')];
    await tester.pumpWidget(
      WordarcadeApp(
        followSystemLocale: true,
        ports: AppPorts(
          cards: InMemoryCardStore(),
          streaks: InMemoryStreakStore(),
          settings: SettingsPrefsStore(prefs),
        ),
        seed: const Ok([_baseWord]),
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(AppKeys.settings));
    expect(find.text('Баптаулар'), findsOneWidget);
    await _choose(tester, SettingsKeys.language, _kazakhLanguage);
    tester.platformDispatcher.localesTestValue = const [Locale('ru', 'RU')];
    await tester.pumpAndSettle();
    expect(find.byTooltip('Артқа'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
