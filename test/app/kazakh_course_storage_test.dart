import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/data/log/history_database.dart';
import 'package:arcadelingo/data/speech/device_word_speech.dart';
import 'package:arcadelingo/domain/events/app_event.dart';
import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/ports/custom_words_store.dart';
import 'package:arcadelingo/domain/ports/daily_word_store.dart';
import 'package:arcadelingo/domain/ports/word_sets_store.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/main.dart' show loadKazakhCourse;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/result.dart';
import '../support/sqlite_for_tests.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(useTestSqlite);

  late SharedPreferences prefs;
  late List<CourseDeck> decks;
  const level = CefrLevel.a1;
  final at = DateTime.utc(2026, 11, 28, 10);
  final day = StreakDay.of(at);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final speech = DeviceWordSpeech(platform: TargetPlatform.android);
    decks = [];
    for (final course in StudyCourse.kazakhCourses) {
      final history = HistoryDatabase(NativeDatabase.memory());
      addTearDown(history.close);
      decks.add(
        ok(
          await loadKazakhCourse(
            course: course,
            prefs: prefs,
            history: history,
            speech: speech,
          ),
        ),
      );
    }
  });

  test(
    'Kazakh decks persist separate progress, vocabulary and history',
    () async {
      for (final (index, deck) in decks.indexed) {
        final item = deck.items.firstWhere((item) => item.word.level == level);
        final id = item.word.id;
        final courseId = deck.course.id;
        expect(
          await deck.cards.save({id: LeitnerCard(box: index + 2, due: at)}),
          isTrue,
        );
        expect(
          await deck.streaks.save(
            StreakState(current: index + 1, best: index + 1, lastDay: day),
          ),
          isTrue,
        );
        expect(await deck.favorites!.save({id}), isTrue);
        expect(
          await deck.customWords!.add(
            level: level,
            text: 'test',
            translation: 'сынақ $courseId',
          ),
          CustomWordSaveResult.saved,
        );
        expect(
          await deck.wordSets!.save(level: level, name: 'Тізім', wordIds: {id}),
          WordSetSaveResult.saved,
        );
        expect(
          await deck.dailyWord!.append(
            level: level,
            day: at,
            targetId: id,
            previousGuesses: [],
            guess: item.word.text,
            finished: true,
          ),
          DailyWordSaveResult.saved,
        );
        await deck.answers.append(
          AnswerRecord(
            wordId: id,
            at: at,
            localDay: day,
            grade: ReviewGrade.again,
            correct: false,
            responseTime: const Duration(seconds: 2),
            timeLimit: const Duration(seconds: 6),
            hintsUsed: 0,
            gameId: 'falling_words',
            sessionId: courseId,
            selectedAnswer: item.distractors.first,
          ),
        );
        await deck.events.append(
          AppEvent.at(AppEventKind.roundOver, at, sessionId: courseId),
        );
      }

      await prefs.reload();
      for (final (index, deck) in decks.indexed) {
        final item = deck.items.firstWhere((item) => item.word.level == level);
        final id = item.word.id;
        expect(ok(deck.cards.load()), {
          id: LeitnerCard(box: index + 2, due: at),
        });
        expect(ok(deck.streaks.load()).current, index + 1);
        expect(deck.favorites!.load(), {id});
        expect(
          deck.customWords!.load(level).single.translation,
          'сынақ ${deck.course.id}',
        );
        expect(deck.wordSets!.load(level).single.wordIds, {id});
        expect(deck.dailyWord!.load(level: level, day: at)?.targetId, id);
        expect(deck.dailyWord!.load(level: CefrLevel.a2, day: at), isNull);
        final answer = (await deck.answers.all()).single;
        expect(answer.wordId, id);
        expect(answer.selectedAnswer, item.distractors.first);
        expect(
          (await deck.events.forDay(day)).single.sessionId,
          deck.course.id,
        );
      }
    },
  );

  test(
    'Kazakh decks send the studied word to its installed local voice',
    () async {
      const channel = MethodChannel('flutter_tts');
      const locales = {'ru': 'ru-RU', 'en': 'en-US', 'es': 'es-ES'};
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method != 'getVoices') return 1;
        return [
          {'name': 'local kk', 'locale': 'kk-KZ', 'network_required': false},
          for (final MapEntry(key: language, value: locale)
              in locales.entries) ...[
            {
              'name': 'remote $language',
              'locale': locale,
              'network_required': true,
            },
            {
              'name': 'local $language',
              'locale': locale,
              'network_required': false,
            },
          ],
        ];
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      for (final deck in decks) {
        calls.clear();
        final language = deck.course.studyLanguage;
        final word = deck.items.first.word;
        expect(await deck.speech.speak(word.text), SpeechResult.completed);
        expect(
          calls.singleWhere((call) => call.method == 'setVoice').arguments,
          {'name': 'local $language', 'locale': locales[language]},
        );
        expect(
          calls.singleWhere((call) => call.method == 'speak').arguments,
          word.text,
        );
      }
    },
  );
}
