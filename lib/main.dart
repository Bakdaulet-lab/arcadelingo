/// Точка входа: разрешить асинхронные зависимости и отдать их корню.
///
/// Состояние читается не здесь, хотя `SharedPreferences` уже под рукой:
/// сессия строится по тапу «Играть» (0.6), и чтение состояния идёт тем же
/// тапом. Прочитанное на старте успело бы устареть.
library;

import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/data/challenges/challenge_prefs_store.dart';
import 'package:arcadelingo/data/daily_word/daily_word_prefs_store.dart';
import 'package:arcadelingo/data/dictionary/custom_words_prefs_store.dart';
import 'package:arcadelingo/data/dictionary/favorites_prefs_store.dart';
import 'package:arcadelingo/data/dictionary/word_sets_prefs_store.dart';
import 'package:arcadelingo/data/log/drift_answer_log.dart';
import 'package:arcadelingo/data/log/drift_event_log.dart';
import 'package:arcadelingo/data/log/history_database.dart';
import 'package:arcadelingo/data/notifications/plugin_reminders.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/data/sound/audio_sounds.dart';
import 'package:arcadelingo/data/speech/device_word_speech.dart';
import 'package:arcadelingo/data/srs/leitner_prefs_store.dart';
import 'package:arcadelingo/data/streak/streak_prefs_store.dart';
import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicense();
  final prefs = await SharedPreferences.getInstance();
  final seed = await loadWordsSeed();
  // Одна база на два журнала: у них одна природа и одна миграция. Файл
  // открывается лениво, при первой записи, — журналы не на пути старта.
  final history = HistoryDatabase(driftDatabase(name: 'wordarcade_answers'));
  final speech = DeviceWordSpeech();
  final extraCourses = await Future.wait([
    loadSpanishCourse(
      prefs: prefs,
      history: HistoryDatabase(driftDatabase(name: 'wordarcade_answers_ru_es')),
      speech: speech,
    ),
    loadEnglishA1FromSpanishCourse(
      prefs: prefs,
      history: HistoryDatabase(driftDatabase(name: 'wordarcade_answers_es_en')),
      speech: speech,
    ),
    loadSpanishFromEnglishCourse(
      prefs: prefs,
      history: HistoryDatabase(driftDatabase(name: 'wordarcade_answers_en_es')),
      speech: speech,
    ),
    for (final course in StudyCourse.kazakhCourses)
      loadKazakhCourse(
        course: course,
        prefs: prefs,
        history: HistoryDatabase(
          driftDatabase(
            name: 'wordarcade_answers_${course.id.replaceAll('-', '_')}',
          ),
        ),
        speech: speech,
      ),
    for (final course in StudyCourse.germanCourses)
      loadGermanCourse(
        course: course,
        prefs: prefs,
        history: HistoryDatabase(
          driftDatabase(
            name: 'wordarcade_answers_${course.id.replaceAll('-', '_')}',
          ),
        ),
        speech: speech,
      ),
    for (final course in StudyCourse.multilingualCourses)
      loadMultilingualCourse(
        course: course,
        prefs: prefs,
        history: HistoryDatabase(
          driftDatabase(
            name: 'wordarcade_answers_${course.id.replaceAll('-', '_')}',
          ),
        ),
        speech: speech,
      ),
  ]);
  final additionalDecks = <CourseDeck>[];
  for (final result in extraCourses) {
    switch (result) {
      case Ok(:final value):
        additionalDecks.add(value);
      case Err(:final failure):
        debugPrint(failure.message);
    }
  }
  // База зон и плагин поднимаются один раз: база IANA весит сотни килобайт,
  // и грузить её на каждое планирование незачем.
  final reminders = await PluginReminders.start();
  runApp(
    WordarcadeApp(
      ports: AppPorts(
        cards: LeitnerPrefsStore(prefs),
        streaks: StreakPrefsStore(prefs),
        // Файл открывается лениво, при первой записи: журнал не на пути
        // старта, и ждать его здесь незачем.
        answers: DriftAnswerLog(history),
        favorites: FavoritesPrefsStore(prefs),
        dailyWord: DailyWordPrefsStore(
          prefs,
          courseId: StudyCourse.englishFromRussian.id,
        ),
        wordSets: WordSetsPrefsStore(
          prefs,
          courseId: StudyCourse.englishFromRussian.id,
        ),
        customWords: CustomWordsPrefsStore(
          prefs,
          courseId: StudyCourse.englishFromRussian.id,
        ),
        events: DriftEventLog(history),
        reminders: reminders,
        settings: SettingsPrefsStore(prefs),
        challengeRecords: ChallengePrefsStore(prefs),
        sounds: AudioSounds(),
        speech: speech,
        askReminderPermission: reminders.requestPermission,
      ),
      seed: seed,
      additionalDecks: additionalDecks,
      followSystemLocale: true,
    ),
  );
}

/// Собирает словарь и хранилища курса русского → испанского A1–C1.
Future<Result<CourseDeck>> loadSpanishCourse({
  required SharedPreferences prefs,
  required HistoryDatabase history,
  required DeviceWordSpeech speech,
}) async => _buildCourseDeck(
  StudyCourse.spanishFromRussian,
  await loadSpanishSeed(),
  prefs: prefs,
  history: history,
  speech: speech,
);

/// Собирает словарь и хранилища курса испанского → английского A1.
Future<Result<CourseDeck>> loadEnglishA1FromSpanishCourse({
  required SharedPreferences prefs,
  required HistoryDatabase history,
  required DeviceWordSpeech speech,
}) async => _buildCourseDeck(
  StudyCourse.englishFromSpanish,
  await loadEnglishA1FromSpanishSeed(),
  prefs: prefs,
  history: history,
  speech: speech,
);

/// Собирает словарь и хранилища курса английского → испанского A1–C1.
Future<Result<CourseDeck>> loadSpanishFromEnglishCourse({
  required SharedPreferences prefs,
  required HistoryDatabase history,
  required DeviceWordSpeech speech,
}) async => _buildCourseDeck(
  StudyCourse.spanishFromEnglish,
  await loadSpanishFromEnglishSeed(),
  prefs: prefs,
  history: history,
  speech: speech,
);

Future<Result<CourseDeck>> loadKazakhCourse({
  required StudyCourse course,
  required SharedPreferences prefs,
  required HistoryDatabase history,
  required DeviceWordSpeech speech,
}) async => _buildCourseDeck(
  course,
  await loadKazakhSeed(course),
  prefs: prefs,
  history: history,
  speech: speech,
);

Future<Result<CourseDeck>> loadGermanCourse({
  required StudyCourse course,
  required SharedPreferences prefs,
  required HistoryDatabase history,
  required DeviceWordSpeech speech,
}) async => _buildCourseDeck(
  course,
  await loadGermanSeed(course),
  prefs: prefs,
  history: history,
  speech: speech,
);

Future<Result<CourseDeck>> loadMultilingualCourse({
  required StudyCourse course,
  required SharedPreferences prefs,
  required HistoryDatabase history,
  required DeviceWordSpeech speech,
}) async => _buildCourseDeck(
  course,
  await loadMultilingualSeed(course),
  prefs: prefs,
  history: history,
  speech: speech,
);

Result<CourseDeck> _buildCourseDeck(
  StudyCourse course,
  Result<List<ReviewItem>> seed, {
  required SharedPreferences prefs,
  required HistoryDatabase history,
  required DeviceWordSpeech speech,
}) => switch (seed) {
  Ok(:final value) => Ok(
    CourseDeck(
      course: course,
      items: value,
      cards: LeitnerPrefsStore(prefs, courseId: course.id),
      streaks: StreakPrefsStore(prefs, courseId: course.id),
      answers: DriftAnswerLog(history),
      events: DriftEventLog(history),
      favorites: FavoritesPrefsStore(prefs, courseId: course.id),
      wordSets: WordSetsPrefsStore(prefs, courseId: course.id),
      dailyWord: DailyWordPrefsStore(prefs, courseId: course.id),
      customWords: CustomWordsPrefsStore(prefs, courseId: course.id),
      speech: speech.forLanguage(
        course.studyLanguage,
        readings: {
          if (course.studyLanguage == 'ja')
            for (final item in value)
              if (item.word.reading case final reading?)
                item.word.text: reading,
        },
      ),
    ),
  ),
  Err(:final failure) => Err(failure),
};

/// Отдаёт лицензию шрифта в `showLicensePage`.
///
/// Не формальность: OFL требует распространять текст лицензии вместе со
/// шрифтом, а шрифт вшит в приложение. Реестр — единственное место, где он
/// доезжает до пользователя.
void _registerFontLicense() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks([wordarcadeFont], text);
    final lora = await rootBundle.loadString('assets/fonts/Lora-OFL.txt');
    yield LicenseEntryWithLineBreaks([warmPaperFont], lora);
    final arabic = await rootBundle.loadString(
      'assets/fonts/NotoSansArabic-OFL.txt',
    );
    yield LicenseEntryWithLineBreaks([arabicFont], arabic);
    final chinese = await rootBundle.loadString(
      'assets/fonts/NotoSansSC-OFL.txt',
    );
    yield LicenseEntryWithLineBreaks([chineseFont], chinese);
    final korean = await rootBundle.loadString(
      'assets/fonts/NotoSansKR-OFL.txt',
    );
    yield LicenseEntryWithLineBreaks([koreanFont], korean);
    final japanese = await rootBundle.loadString(
      'assets/fonts/NotoSansJP-OFL.txt',
    );
    yield LicenseEntryWithLineBreaks([japaneseFont], japanese);
  });
}
