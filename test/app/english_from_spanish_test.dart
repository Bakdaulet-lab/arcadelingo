import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/data/challenges/challenge_prefs_store.dart';
import 'package:arcadelingo/data/dictionary/favorites_prefs_store.dart';
import 'package:arcadelingo/data/log/drift_answer_log.dart';
import 'package:arcadelingo/data/log/history_database.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/data/speech/device_word_speech.dart';
import 'package:arcadelingo/data/srs/leitner_prefs_store.dart';
import 'package:arcadelingo/data/streak/streak_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/main.dart'
    show loadEnglishA1FromSpanishCourse, loadSpanishA1Course;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/claw_actions.dart';
import '../support/sqlite_for_tests.dart';

final _now = DateTime(2026, 11, 18, 10);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(useTestSqlite);

  test('the new course requests the installed English voice', () async {
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
          {'name': 'Spanish', 'locale': 'es-ES', 'network_required': false},
          {
            'name': 'English cloud',
            'locale': 'en-US',
            'network_required': true,
          },
          {
            'name': 'English local',
            'locale': 'en-GB',
            'network_required': false,
          },
        ];
      }
      return 1;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final result = await loadEnglishA1FromSpanishCourse(
      prefs: prefs,
      history: db,
      speech: DeviceWordSpeech(platform: TargetPlatform.android),
    );
    final deck = (result as Ok<CourseDeck>).value;
    expect(await deck.speech.speak('fish'), SpeechResult.completed);
    expect(calls.singleWhere((call) => call.method == 'setVoice').arguments, {
      'name': 'English local',
      'locale': 'en-GB',
    });
    expect(
      calls.singleWhere((call) => call.method == 'speak').arguments,
      'fish',
    );
  });

  for (final (title, id) in [
    ('Palabras que caen', 'falling_words'),
    ('Corte ninja', 'ninja_slash'),
    ('Máquina de garra', 'claw_machine'),
  ]) {
    testWidgets('$title uses only English A1 with Spanish translations', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'reminder_settings':
            '{"version":2,"enabled":false,"hour":20,"minute":0,"interfaceLanguage":"es"}',
        'favorite_word_ids': ['fish'],
      });
      final prefs = await SharedPreferences.getInstance();
      final mainHistory = HistoryDatabase(NativeDatabase.memory());
      final spanishHistory = HistoryDatabase(NativeDatabase.memory());
      final newHistory = HistoryDatabase(NativeDatabase.memory());
      addTearDown(mainHistory.close);
      addTearDown(spanishHistory.close);
      addTearDown(newHistory.close);
      final speech = DeviceWordSpeech(platform: TargetPlatform.linux);
      final (deck, spanish) =
          (await tester.runAsync(() async {
            final newCourse = await loadEnglishA1FromSpanishCourse(
              prefs: prefs,
              history: newHistory,
              speech: speech,
            );
            final spanishCourse = await loadSpanishA1Course(
              prefs: prefs,
              history: spanishHistory,
              speech: speech,
            );
            return (
              (newCourse as Ok<CourseDeck>).value,
              (spanishCourse as Ok<CourseDeck>).value,
            );
          }))!;
      final target = deck.items.singleWhere((item) => item.word.text == 'fish');
      final due = _now.add(const Duration(days: 1));
      final cards = LeitnerPrefsStore(prefs);
      final answers = DriftAnswerLog(mainHistory);
      await cards.save({target.word.id: LeitnerCard(box: 3, due: due)});
      final before = prefs.getString(LeitnerPrefsStore.key);
      await deck.cards.save({
        for (final item in deck.items)
          if (item.word.id != target.word.id)
            item.word.id: LeitnerCard(box: 2, due: due),
      });
      final records = ChallengePrefsStore(prefs);
      const oldRecord = (
        courseId: 'ru-en',
        gameId: 'claw_machine',
        level: CefrLevel.a1,
      );
      const newRecord = (
        courseId: 'es-en',
        gameId: 'claw_machine',
        level: CefrLevel.a1,
      );
      await records.submit(oldRecord, 3);
      if (id == 'claw_machine') await records.submit(newRecord, 1);
      final ports = AppPorts(
        cards: cards,
        streaks: StreakPrefsStore(prefs),
        answers: answers,
        favorites: FavoritesPrefsStore(prefs),
        settings: SettingsPrefsStore(prefs),
        challengeRecords: records,
      );
      WordarcadeApp app() => WordarcadeApp(
        ports: ports,
        now: () => _now,
        additionalDecks: [spanish, deck],
        seed: Ok([
          ReviewItem(
            word: Word(id: target.word.id, text: 'fish', translation: 'рыба'),
          ),
          const ReviewItem(
            word: Word(
              id: 'duty',
              text: 'duty',
              translation: 'долг',
              level: CefrLevel.b2,
            ),
          ),
        ]),
      );
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(ChoiceChip, 'B2'));
      await _tap(tester, find.byKey(AppKeys.course));
      expect(find.byKey(const ValueKey('course.ru-es')), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('course.es-en')));
      expect(find.text('Inglés · traducciones al español'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'A1'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'B2'), findsNothing);
      await _tap(tester, find.text(title));
      if (id == 'claw_machine') {
        await _tap(tester, find.byKey(AppKeys.challenge));
        expect(find.text('Récord personal: 1'), findsOneWidget);
        await _tap(tester, find.text('Cancelar'));
      }
      final play = find.byKey(AppKeys.play);
      await tester.ensureVisible(play);
      await tester.tap(play);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      if (id == 'claw_machine') {
        expect(find.text('pez'), findsOneWidget);
        await spellWithClaw(tester, 'fish');
        await tapClaw(tester, ClawKeys.next);
      } else {
        final ninja = id == 'ninja_slash';
        await tester.pump(
          ninja ? NinjaRun.windUpTime : FallingWordsRun.windUpTime,
        );
        await tester.pump(const Duration(milliseconds: 850));
        expect(find.text('fish'), findsOneWidget);
        final shown = target.distractors.where(
          (answer) => find.text(answer).evaluate().isNotEmpty,
        );
        expect(shown, hasLength(ninja ? NinjaRun.maxObjects - 1 : 3));
        final correct = find.text('pez');
        expect(correct, findsOneWidget);
        if (ninja) {
          final center = tester.getCenter(correct);
          final swipe = await tester.startGesture(center - const Offset(30, 0));
          await swipe.moveTo(center + const Offset(30, 0));
          await swipe.up();
        } else {
          await tester.tap(correct);
        }
        await tester.pump();
        await tester.pump(
          ninja ? NinjaRun.correctReveal : FallingWordsRun.correctReveal,
        );
      }
      expect(find.text('рыба'), findsNothing);
      expect(find.text('Fin de la ronda'), findsOneWidget);
      final logged = (await tester.runAsync(deck.answers.all))!.single;
      expect(logged.wordId, target.word.id);
      expect(logged.gameId, id);
      expect(logged.correct, isTrue);
      expect(await tester.runAsync(answers.all), isEmpty);
      expect(await tester.runAsync(spanish.answers.all), isEmpty);
      expect(prefs.getString(LeitnerPrefsStore.key), before);
      expect(deck.favorites!.load(), isEmpty);
      await deck.favorites!.save({target.word.id});
      expect(ports.favorites!.load(), {'fish'});
      expect(spanish.favorites!.load(), isEmpty);
      expect((deck.streaks.load() as Ok<StreakState>).value.current, 1);
      expect((ports.streaks.load() as Ok<StreakState>).value.current, 0);
      expect((spanish.streaks.load() as Ok<StreakState>).value.current, 0);

      await tester.pumpWidget(const SizedBox());
      await prefs.reload();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Inglés · traducciones al español'), findsOneWidget);
      expect(find.text('Elige un juego'), findsOneWidget);
      expect(deck.favorites!.load(), {target.word.id});
      expect(prefs.getString('leitner_state.es-en'), contains(target.word.id));
      expect(await tester.runAsync(deck.answers.all), [logged]);
    });
  }
}
