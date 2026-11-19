import 'dart:io';

import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/data/dictionary/favorites_prefs_store.dart';
import 'package:arcadelingo/data/log/drift_answer_log.dart';
import 'package:arcadelingo/data/log/history_database.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/data/speech/device_word_speech.dart';
import 'package:arcadelingo/data/srs/leitner_prefs_store.dart';
import 'package:arcadelingo/data/streak/streak_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/events/app_event.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/main.dart'
    show
        loadEnglishA1FromSpanishCourse,
        loadSpanishA1Course,
        loadSpanishA1FromEnglishCourse;
import 'package:arcadelingo/ui/word_pronunciation.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/claw_actions.dart';
import '../support/sqlite_for_tests.dart';

final _now = DateTime(2026, 11, 19, 10);
final _today = StreakDay.of(_now);
const _spanish = ValueKey('course.en-es');
const _spanishForRussian = ValueKey('course.ru-es');
const _englishForSpanish = ValueKey('course.es-en');
const _english = ValueKey('course.ru-en');

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(useTestSqlite);

  for (final voiceInstalled in [true, false]) {
    test('Spanish voice installed: $voiceInstalled', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = HistoryDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      const channel = MethodChannel('flutter_tts');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'getVoices') {
          return [
            {
              'name': 'English local',
              'locale': 'en-US',
              'network_required': false,
            },
            {
              'name': 'Spanish cloud',
              'locale': 'es-ES',
              'network_required': true,
            },
            {
              'name': 'Spanish not installed',
              'locale': 'es-ES',
              'network_required': false,
              'features': ['notInstalled'],
            },
            if (voiceInstalled)
              {
                'name': 'Spanish local',
                'locale': 'es-MX',
                'network_required': false,
              },
          ];
        }
        return 1;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final result = await loadSpanishA1FromEnglishCourse(
        prefs: prefs,
        history: db,
        speech: DeviceWordSpeech(platform: TargetPlatform.android),
      );
      final deck = (result as Ok<CourseDeck>).value;
      final spoken = await deck.speech.speak('niño');
      if (voiceInstalled) {
        expect(spoken, SpeechResult.completed);
        expect(
          calls.singleWhere((call) => call.method == 'setVoice').arguments,
          {'name': 'Spanish local', 'locale': 'es-MX'},
        );
        expect(
          calls.singleWhere((call) => call.method == 'speak').arguments,
          'niño',
        );
      } else {
        expect(spoken, SpeechResult.unavailable);
        expect(
          calls.where(
            (call) => call.method == 'setVoice' || call.method == 'speak',
          ),
          isEmpty,
        );
      }
    });
  }

  for (final (title, id) in [
    ('Falling Words', 'falling_words'),
    ('Ninja Slash', 'ninja_slash'),
    ('Claw Machine', 'claw_machine'),
  ]) {
    testWidgets(
      '$title uses bundled Spanish A1 and writes only to the English-to-Spanish course',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'reminder_settings':
              '{"version":2,"enabled":false,"hour":20,"minute":0,"interfaceLanguage":"en"}',
          'streak_state':
              '{"version":1,"current":4,"best":4,"last_day":"2026-11-19"}',
        });
        final prefs = await SharedPreferences.getInstance();
        final folder = Directory.systemTemp.createTempSync(
          'spanish_from_english_test',
        );
        addTearDown(() => folder.deleteSync(recursive: true));
        final file = File('${folder.path}/spanish.sqlite');
        final spanishDb = HistoryDatabase(NativeDatabase(file));
        final englishDb = HistoryDatabase(NativeDatabase.memory());
        var spanishClosed = false;
        addTearDown(() async {
          if (!spanishClosed) await spanishDb.close();
        });
        addTearDown(englishDb.close);
        final speech = DeviceWordSpeech(platform: TargetPlatform.linux);
        final deck =
            (await tester.runAsync(() async {
              final loaded = await loadSpanishA1FromEnglishCourse(
                prefs: prefs,
                history: spanishDb,
                speech: speech,
              );
              return (loaded as Ok<CourseDeck>).value;
            }))!;
        final ruSpanishDb = HistoryDatabase(NativeDatabase.memory());
        final esEnglishDb = HistoryDatabase(NativeDatabase.memory());
        addTearDown(ruSpanishDb.close);
        addTearDown(esEnglishDb.close);
        final (ruSpanish, esEnglish) =
            (await tester.runAsync(() async {
              final russianCourse = await loadSpanishA1Course(
                prefs: prefs,
                history: ruSpanishDb,
                speech: speech,
              );
              final spanishCourse = await loadEnglishA1FromSpanishCourse(
                prefs: prefs,
                history: esEnglishDb,
                speech: speech,
              );
              return (
                (russianCourse as Ok<CourseDeck>).value,
                (spanishCourse as Ok<CourseDeck>).value,
              );
            }))!;
        final targetWord = deck.items.firstWhere(
          (item) => item.word.text == 'niño',
        );
        final targetId = targetWord.word.id;
        final existingSpanishWord = ruSpanish.items.singleWhere(
          (item) => item.word.text == 'niño',
        );
        expect(existingSpanishWord.word.id, targetId);
        final englishCards = LeitnerPrefsStore(prefs);
        final englishFavorites = FavoritesPrefsStore(prefs);
        final englishAnswers = DriftAnswerLog(englishDb);
        final englishStreaks = StreakPrefsStore(prefs);
        final dueTomorrow = _now.add(const Duration(days: 1));
        await englishCards.save({
          targetId: LeitnerCard(box: 3, due: dueTomorrow),
        });
        await englishFavorites.save({targetId});
        await ruSpanish.cards.save({
          targetId: LeitnerCard(box: 4, due: dueTomorrow),
        });
        final oldSpanishFavorite = ruSpanish.items.first.word.id;
        await ruSpanish.favorites!.save({oldSpanishFavorite});
        const otherProgressKeys = [
          'leitner_state',
          'streak_state',
          'favorite_word_ids',
          'leitner_state.ru-es',
          'streak_state.ru-es',
          'favorite_word_ids.ru-es',
          'leitner_state.es-en',
          'streak_state.es-en',
          'favorite_word_ids.es-en',
        ];
        Map<String, Object?> otherCourseProgress() => {
          for (final key in otherProgressKeys) key: prefs.get(key),
        };
        final previousProgress = otherCourseProgress();
        expect(deck.favorites!.load(), isEmpty);
        // Keep one real bundled card due so the test can finish a whole round.
        await deck.cards.save({
          for (final item in deck.items)
            if (item.word.id != targetId)
              item.word.id: LeitnerCard(box: 2, due: dueTomorrow),
        });

        final ports = AppPorts(
          cards: englishCards,
          streaks: englishStreaks,
          answers: englishAnswers,
          favorites: englishFavorites,
          settings: SettingsPrefsStore(prefs),
        );
        final englishSeed = Ok([
          ReviewItem(
            word: Word(id: targetId, text: 'child', translation: 'ребёнок'),
            distractors: const ['рыба', 'кот', 'тигр'],
          ),
        ]);
        WordarcadeApp app(CourseDeck course) => WordarcadeApp(
          ports: ports,
          seed: englishSeed,
          additionalDecks: [ruSpanish, esEnglish, course],
          now: () => _now,
        );
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(app(deck));
        await tester.pumpAndSettle();
        await _tap(tester, find.widgetWithText(ChoiceChip, 'C2'));
        await _tap(tester, find.byKey(AppKeys.course));
        expect(find.byKey(_spanishForRussian), findsOneWidget);
        expect(find.byKey(_englishForSpanish), findsOneWidget);
        await _tap(tester, find.byKey(_spanish));
        expect(find.text('Spanish level'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, 'A1'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, 'A2'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, 'C2'), findsNothing);
        expect(
          tester.widget<PlayView>(find.byType(PlayView)).ritual?.playedToday,
          isFalse,
        );

        if (id == 'claw_machine') {
          await _tap(tester, find.byKey(AppKeys.learn));
          expect(find.text('niño'), findsOneWidget);
          await _tap(tester, find.byKey(WordPronunciation.buttonKey));
          expect(find.byKey(WordPronunciation.messageKey), findsOneWidget);
          expect(
            tester.widget<Text>(find.byKey(WordPronunciation.messageKey)).data,
            contains('local Spanish voice'),
          );
          Navigator.of(tester.element(find.byType(WordPronunciation))).pop();
          await tester.pumpAndSettle();
        }

        await _tap(tester, find.text(title));
        final play = find.byKey(AppKeys.play);
        await tester.ensureVisible(play);
        await tester.tap(play);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        if (id == 'claw_machine') {
          expect(find.text('boy'), findsOneWidget);
          await spellWithClaw(tester, 'niño');
          await tapClaw(tester, ClawKeys.next);
        } else {
          final ninja = id == 'ninja_slash';
          await tester.pump(
            ninja ? NinjaRun.windUpTime : FallingWordsRun.windUpTime,
          );
          await tester.pump(const Duration(milliseconds: 850));
          expect(find.text('niño'), findsOneWidget);
          expect(find.text('мальчик'), findsNothing);
          final displayedDistractors = targetWord.distractors.where(
            (option) => find.text(option).evaluate().isNotEmpty,
          );
          expect(
            displayedDistractors,
            hasLength(ninja ? NinjaRun.maxObjects - 1 : 3),
          );
          final answer = find.text('boy');
          expect(answer, findsOneWidget);
          if (ninja) {
            final center = tester.getCenter(answer);
            final slash = await tester.startGesture(
              center - const Offset(30, 0),
            );
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
        final records = (await tester.runAsync(deck.answers.all))!;
        expect(records.single.wordId, targetId);
        expect(records.single.gameId, id);
        expect(records.single.correct, isTrue);
        expect(await tester.runAsync(englishAnswers.all), isEmpty);
        expect(await tester.runAsync(ruSpanish.answers.all), isEmpty);
        expect(await tester.runAsync(esEnglish.answers.all), isEmpty);
        expect(otherCourseProgress(), previousProgress);
        expect(englishFavorites.load(), {targetId});
        expect(await deck.favorites!.save({targetId}), isTrue);
        expect(await deck.favorites!.save({deck.items.first.word.id}), isTrue);
        expect(englishFavorites.load(), {targetId});

        await tester.pumpWidget(const SizedBox());
        final reopenedDb = await tester.runAsync(() async {
          await spanishDb.close();
          spanishClosed = true;
          await prefs.reload();
          return HistoryDatabase(NativeDatabase(file));
        });
        addTearDown(reopenedDb!.close);
        final reopened =
            (await tester.runAsync(() async {
              final loaded = await loadSpanishA1FromEnglishCourse(
                prefs: prefs,
                history: reopenedDb,
                speech: speech,
              );
              return (loaded as Ok<CourseDeck>).value;
            }))!;
        expect(await tester.runAsync(reopened.answers.all), records);
        final reopenedCards =
            reopened.cards.load() as Ok<Map<String, LeitnerCard>>;
        expect(
          reopenedCards.value[targetId],
          schedule(
            LeitnerCard(box: 1, due: _now),
            records.single.grade,
            now: _now,
          ),
        );
        final streak = reopened.streaks.load() as Ok<StreakState>;
        expect(streak.value.current, 1);
        expect(
          await tester.runAsync(
            () => reopened.events.daysWith(
              kind: AppEventKind.roundOver,
              from: _today,
              to: _today,
            ),
          ),
          contains(_today),
        );
        expect(reopened.favorites!.load(), {deck.items.first.word.id});
        expect(ruSpanish.favorites!.load(), {oldSpanishFavorite});
        expect(esEnglish.favorites!.load(), isEmpty);
        await tester.pumpWidget(app(reopened));
        await tester.pumpAndSettle();
        expect(find.text('Spanish · English translations'), findsOneWidget);
        await _tap(tester, find.byKey(AppKeys.course));
        await _tap(tester, find.byKey(_english));
        expect(find.text('English · Russian translations'), findsOneWidget);
        expect(otherCourseProgress(), previousProgress);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
