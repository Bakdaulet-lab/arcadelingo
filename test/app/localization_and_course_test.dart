import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/app/settings_view.dart';
import 'package:arcadelingo/data/dictionary/favorites_prefs_store.dart';
import 'package:arcadelingo/data/log/drift_answer_log.dart';
import 'package:arcadelingo/data/log/history_database.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/data/srs/leitner_codec.dart';
import 'package:arcadelingo/data/srs/leitner_prefs_store.dart';
import 'package:arcadelingo/data/streak/streak_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/claw_actions.dart';
import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';
import '../support/sqlite_for_tests.dart';

const _fish = ReviewItem(
  word: Word(id: 'fish', text: 'fish', translation: 'рыба'),
  distractors: ['краб', 'улитка', 'кит'],
);
final _now = DateTime(2026, 11, 18, 10);
const _course = Key('app.course');
const _language = Key('settings.language');
const _english = Key('settings.language.en');
const _russian = Key('settings.language.ru');

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(useTestSqlite);

  testWidgets(
    'системный выбор читает язык устройства и возвращается к английскому',
    (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        WordarcadeApp(
          ports: AppPorts(
            cards: InMemoryCardStore(),
            streaks: InMemoryStreakStore(),
          ),
          seed: const Ok([_fish]),
          followSystemLocale: true,
          now: () => _now,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose a game'), findsOneWidget);
      tester.platformDispatcher.localesTestValue = const [Locale('ru', 'KZ')];
      await tester.pumpAndSettle();
      expect(find.text('Выбери игру'), findsOneWidget);
    },
  );

  testWidgets(
    'установки старой версии и прогресс переживают смену меню и рестарт',
    (tester) async {
      final cards = encodeLeitnerState({
        'old': LeitnerCard(box: 4, due: _now.add(const Duration(days: 2))),
      });
      const streak =
          '{"version":1,"current":2,"best":3,"last_day":"2026-11-18"}';
      SharedPreferences.setMockInitialValues({
        'reminder_settings':
            '{"version":1,"enabled":false,"hour":7,"minute":30}',
        'leitner_state': cards,
        'favorite_word_ids': ['fish'],
        'streak_state': streak,
      });
      final prefs = await SharedPreferences.getInstance();
      final db = HistoryDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final answers = DriftAnswerLog(db);
      final previousAnswer = AnswerRecord(
        wordId: 'fish',
        at: _now.toUtc(),
        localDay: StreakDay.of(_now),
        grade: ReviewGrade.good,
        correct: true,
        responseTime: const Duration(seconds: 2),
        timeLimit: const Duration(seconds: 5),
        hintsUsed: 0,
        gameId: 'falling_words',
        sessionId: 'legacy-round',
      );
      await tester.runAsync(() => answers.append(previousAnswer));
      final ports = AppPorts(
        cards: LeitnerPrefsStore(prefs),
        streaks: StreakPrefsStore(prefs),
        favorites: FavoritesPrefsStore(prefs),
        answers: answers,
        settings: SettingsPrefsStore(prefs),
      );
      WordarcadeApp app() =>
          WordarcadeApp(ports: ports, seed: const Ok([_fish]), now: () => _now);
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await _tap(tester, find.byKey(_course));
      expect(find.text('Выбери курс'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('course.ru-en')));
      await _tap(tester, find.byKey(AppKeys.settings));
      expect(find.text('Настройки'), findsOneWidget);
      await _tap(tester, find.byKey(_language));
      await _tap(tester, find.byKey(_english));
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Choose a game'), findsOneWidget);
      expect(find.text('English · Russian translations'), findsOneWidget);
      expect(prefs.getString('leitner_state'), cards);
      expect(prefs.getStringList('favorite_word_ids'), ['fish']);
      expect(prefs.getString('streak_state'), streak);
      expect(await tester.runAsync(answers.all), [previousAnswer]);
      expect(prefs.getString('reminder_settings'), contains('"hour":7'));
      expect(prefs.getString('reminder_settings'), contains('"minute":30'));
      expect(
        prefs.getString('reminder_settings'),
        contains('"courseId":"ru-en"'),
      );

      await _tap(tester, find.byKey(AppKeys.settings));
      await _tap(tester, find.byKey(_language));
      await _tap(tester, find.byKey(_russian));
      expect(find.text('Настройки'), findsOneWidget);
      expect(find.byTooltip('Назад'), findsOneWidget);
      expect(prefs.getString('leitner_state'), cards);
    },
  );

  testWidgets('курсы с одинаковым ID слова сохраняют самостоятельный прогресс', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {
      'reminder_settings':
          '{"version":2,"enabled":false,"hour":20,"minute":0,"interfaceLanguage":"en"}',
    });
    final prefs = await SharedPreferences.getInstance();
    final cards = LeitnerPrefsStore(prefs);
    final answers = InMemoryAnswerLog();
    final secondCards = InMemoryCardStore();
    final secondAnswers = InMemoryAnswerLog();
    final ports = AppPorts(
      cards: cards,
      answers: answers,
      streaks: StreakPrefsStore(prefs),
      settings: SettingsPrefsStore(prefs),
    );
    WordarcadeApp app() => WordarcadeApp(
      ports: ports,
      seed: const Ok([_fish]),
      now: () => _now,
      additionalDecks: [
        CourseDeck(
          course: const StudyCourse(
            id: 'ru-es',
            studyLanguage: 'es',
            translationLanguage: 'ru',
          ),
          items: const [
            ReviewItem(
              word: Word(
                id: 'fish',
                text: 'pez',
                translation: 'рыба',
                level: CefrLevel.a2,
              ),
            ),
          ],
          cards: secondCards,
          streaks: InMemoryStreakStore(),
          answers: secondAnswers,
        ),
      ],
    );
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final oldDocument = prefs.getString(LeitnerPrefsStore.key);
    await _tap(tester, find.byKey(_course));
    await _tap(tester, find.byKey(const ValueKey('course.ru-es')));
    expect(find.text('Spanish level'), findsOneWidget);
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'A2')).selected,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Spanish · Russian translations'), findsOneWidget);
    await _tap(tester, find.text('Claw Machine'));
    await _tap(tester, find.byKey(AppKeys.play));
    await spellWithClaw(tester, 'pez');
    await tapClaw(tester, ClawKeys.next);
    expect(secondAnswers.records.single.wordId, 'fish');
    expect(secondAnswers.records.single.correct, isTrue);
    expect(secondCards.saves, isNotEmpty);
    expect(answers.records, isEmpty);
    expect(prefs.getString(LeitnerPrefsStore.key), oldDocument);
    await _tap(tester, find.text('Exit'));
    await _tap(tester, find.byKey(_course));
    await _tap(tester, find.byKey(const ValueKey('course.ru-en')));
    expect(find.text('English level'), findsOneWidget);
  });

  for (final locale in ['ru', 'en']) {
    testWidgets('настройки $locale доступны на 360×640 при шрифте 2×', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'reminder_settings':
            '{"version":2,"enabled":true,"hour":20,"minute":0,"interfaceLanguage":"$locale"}',
      });
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(
        WordarcadeApp(
          ports: AppPorts(
            cards: InMemoryCardStore(),
            streaks: InMemoryStreakStore(),
            settings: SettingsPrefsStore(prefs),
          ),
          seed: const Ok([_fish]),
          now: () => _now,
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(AppKeys.settings));
      expect(tester.takeException(), isNull);
      for (final key in [
        SettingsKeys.language,
        SettingsKeys.toggle,
        SettingsKeys.time,
        SettingsKeys.sound,
      ]) {
        final row = find.byKey(key);
        expect(
          row.hitTestable(),
          findsOneWidget,
          reason: 'строка доступна сразу: $key',
        );
        expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      }
      expect(tester.getSize(find.byType(AppBar)).height, lessThan(90));
      await _tap(tester, find.byKey(SettingsKeys.sound));
      expect(
        tester.widget<SwitchListTile>(find.byKey(SettingsKeys.sound)).value,
        isFalse,
      );
    });
  }

  for (final (title, id) in [
    ('Falling Words', 'falling_words'),
    ('Ninja Slash', 'ninja_slash'),
    ('Claw Machine', 'claw_machine'),
  ]) {
    testWidgets('$title на английском сохраняет ответ русского курса', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'reminder_settings':
            '{"version":2,"enabled":false,"hour":20,"minute":0,"interfaceLanguage":"en"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final answers = InMemoryAnswerLog();
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        WordarcadeApp(
          ports: AppPorts(
            cards: LeitnerPrefsStore(prefs),
            streaks: StreakPrefsStore(prefs),
            settings: SettingsPrefsStore(prefs),
            answers: answers,
          ),
          seed: const Ok([_fish]),
          now: () => _now,
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text(title));
      await tester.tap(find.byKey(AppKeys.play));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      if (id == 'claw_machine') {
        expect(find.text('Grab'), findsOneWidget);
        expect(find.text('рыба'), findsOneWidget);
        await spellWithClaw(tester, 'fish');
        await tapClaw(tester, ClawKeys.next);
      } else {
        final ninja = id == 'ninja_slash';
        await tester.pump(
          ninja ? NinjaRun.windUpTime : FallingWordsRun.windUpTime,
        );
        await tester.pump(const Duration(milliseconds: 850));
        final answer = find.text('рыба');
        expect(answer, findsOneWidget);
        if (ninja) {
          final center = tester.getCenter(answer);
          final slash = await tester.startGesture(center - const Offset(30, 0));
          await slash.moveTo(center + const Offset(30, 0));
          await slash.up();
        } else {
          await tester.tap(answer);
        }
        await tester.pump();
        await tester.pump(
          ninja ? NinjaRun.correctReveal : FallingWordsRun.correctReveal,
        );
      }
      expect(find.text('Round complete'), findsOneWidget);
      expect(find.text('Correct answers: 1 of 1'), findsOneWidget);
      expect(answers.records.single.wordId, 'fish');
      expect(answers.records.single.gameId, id);
      expect(answers.records.single.correct, isTrue);
      expect(prefs.getString('leitner_state'), contains('"fish"'));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
