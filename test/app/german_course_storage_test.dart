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
import 'package:arcadelingo/main.dart' show loadGermanCourse;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/result.dart';
import '../support/sqlite_for_tests.dart';

const _id = 'de_apfel';
const _level = CefrLevel.a1;
const _guesses = ['apfel', 'stuhl', 'sonne', 'woche'];
const _speechChannel = MethodChannel('flutter_tts');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(useTestSqlite);

  late SharedPreferences prefs;
  late List<CourseDeck> decks;
  final at = DateTime.utc(2026, 11, 28, 10);
  final day = StreakDay.of(at);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final speech = DeviceWordSpeech(platform: TargetPlatform.android);
    decks = [];
    for (final course in StudyCourse.germanCourses) {
      final history = HistoryDatabase(NativeDatabase.memory());
      addTearDown(history.close);
      decks.add(
        ok(
          await loadGermanCourse(
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
    'German decks isolate progress and history for the same word ID',
    () async {
      for (final (index, deck) in decks.indexed) {
        final item = deck.items.singleWhere((item) => item.word.id == _id);
        final courseId = deck.course.id;
        expect(item.word.level, _level);
        expect(item.word.headword, 'der Apfel');
        expect(
          await deck.cards.save({_id: LeitnerCard(box: index + 2, due: at)}),
          isTrue,
        );
        expect(
          await deck.streaks.save(
            StreakState(current: index + 1, best: index + 1, lastDay: day),
          ),
          isTrue,
        );
        expect(await deck.favorites!.save({if (index.isEven) _id}), isTrue);
        expect(
          await deck.customWords!.add(
            level: _level,
            text: 'Prüfwort',
            translation: 'word from $courseId',
          ),
          CustomWordSaveResult.saved,
        );
        expect(
          await deck.wordSets!.save(
            level: _level,
            name: 'Set from $courseId',
            wordIds: {_id},
          ),
          WordSetSaveResult.saved,
        );
        expect(
          await deck.dailyWord!.append(
            level: _level,
            day: at,
            targetId: _id,
            previousGuesses: [],
            guess: _guesses[index],
            finished: index == 0,
          ),
          DailyWordSaveResult.saved,
        );
        await deck.answers.append(
          AnswerRecord(
            wordId: _id,
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
        final courseId = deck.course.id;
        final item = deck.items.singleWhere((item) => item.word.id == _id);
        expect(ok(deck.cards.load()), {
          _id: LeitnerCard(box: index + 2, due: at),
        });
        expect(ok(deck.streaks.load()).current, index + 1);
        expect(deck.favorites!.load(), <String>{if (index.isEven) _id});
        expect(
          deck.customWords!.load(_level).single.translation,
          'word from $courseId',
        );
        final wordSet = deck.wordSets!.load(_level).single;
        expect(wordSet.name, 'Set from $courseId');
        expect(wordSet.wordIds, {_id});
        final puzzle = deck.dailyWord!.load(level: _level, day: at)!;
        expect(puzzle.targetId, _id);
        expect(puzzle.guesses, [_guesses[index]]);
        expect(puzzle.finished, index == 0);
        expect(deck.dailyWord!.load(level: CefrLevel.a2, day: at), isNull);
        final answer = (await deck.answers.all()).single;
        expect(answer.wordId, _id);
        expect(answer.sessionId, courseId);
        expect(answer.selectedAnswer, item.distractors.first);
        expect((await deck.events.forDay(day)).single.sessionId, courseId);
      }
    },
  );

  test('German decks prefer an installed de-DE voice', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(_speechChannel, (call) async {
      calls.add(call);
      if (call.method != 'getVoices') return 1;
      return [
        {'name': 'cloud', 'locale': 'de-DE', 'network_required': true},
        {'name': 'local east', 'locale': 'de-AT', 'network_required': false},
        {'name': 'local English', 'locale': 'en-US', 'network_required': false},
        {'name': 'local Germany', 'locale': 'de-DE', 'network_required': false},
      ];
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_speechChannel, null));

    for (final deck in decks) {
      final word = deck.items.singleWhere((item) => item.word.id == _id).word;
      expect(await deck.speech.speak(word.headword), SpeechResult.completed);
    }
    expect(calls.singleWhere((call) => call.method == 'setVoice').arguments, {
      'name': 'local Germany',
      'locale': 'de-DE',
    });
    expect(
      calls
          .where((call) => call.method == 'speak')
          .map((call) => call.arguments),
      List.filled(decks.length, 'der Apfel'),
    );
  });

  test(
    'German deck reports unavailable when only cloud voices match',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(_speechChannel, (call) async {
        calls.add(call.method);
        if (call.method != 'getVoices') return 1;
        return [
          {'name': 'cloud', 'locale': 'de-DE', 'network_required': true},
          {
            'name': 'local English',
            'locale': 'en-US',
            'network_required': false,
          },
        ];
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(_speechChannel, null),
      );
      expect(
        await decks.first.speech.speak('der Apfel'),
        SpeechResult.unavailable,
      );
      expect(calls, isNot(contains('setVoice')));
      expect(calls, isNot(contains('speak')));
    },
  );
}
