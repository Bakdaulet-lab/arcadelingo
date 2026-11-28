import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/data/log/history_database.dart';
import 'package:arcadelingo/data/speech/device_word_speech.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/main.dart' show loadMultilingualCourse;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/result.dart';
import '../support/sqlite_for_tests.dart';

const _speechChannel = MethodChannel('flutter_tts');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(useTestSqlite);

  late SharedPreferences prefs;
  late DeviceWordSpeech speech;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    speech = DeviceWordSpeech(platform: TargetPlatform.android);
  });

  Future<CourseDeck> load(StudyCourse course, HistoryDatabase history) async =>
      ok(
        await loadMultilingualCourse(
          course: course,
          prefs: prefs,
          history: history,
          speech: speech,
        ),
      );

  HistoryDatabase newHistory() {
    final history = HistoryDatabase(NativeDatabase.memory());
    addTearDown(history.close);
    return history;
  }

  List<MethodCall> mockVoices({
    required List<String> installed,
    required List<String> online,
  }) {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(_speechChannel, (call) async {
      calls.add(call);
      if (call.method != 'getVoices') return 1;
      return [
        for (final locale in online)
          {'name': 'cloud $locale', 'locale': locale, 'network_required': true},
        for (final locale in installed)
          {
            'name': 'local $locale',
            'locale': locale,
            'network_required': false,
          },
      ];
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_speechChannel, null));
    return calls;
  }

  test(
    '20 course directions reload independent word and streak progress',
    () async {
      final courses = StudyCourse.multilingualCourses;
      expect(courses.length, 20);
      final histories = [for (final _ in courses) newHistory()];
      final at = DateTime.utc(2026, 11, 28, 10);
      final wordIds = <String, String>{};

      for (final (index, course) in courses.indexed) {
        final deck = await load(course, histories[index]);
        final word =
            deck.items
                .firstWhere((item) => item.word.level == CefrLevel.a1)
                .word;
        expect(
          word.id,
          wordIds.putIfAbsent(course.studyLanguage, () => word.id),
          reason: course.id,
        );
        final count = index + 1;
        final card = LeitnerCard(box: 2, due: at.add(Duration(days: count)));
        expect(await deck.cards.save({word.id: card}), isTrue);
        expect(
          await deck.streaks.save(
            StreakState(current: count, best: count, lastDay: StreakDay.of(at)),
          ),
          isTrue,
        );
      }

      await prefs.reload();
      for (final (index, course) in courses.indexed) {
        final deck = await load(course, histories[index]);
        final count = index + 1;
        final expected = LeitnerCard(
          box: 2,
          due: at.add(Duration(days: count)),
        );
        final wordId = wordIds[course.studyLanguage]!;
        final cards = ok(deck.cards.load());
        expect(cards, {wordId: expected}, reason: course.id);
        expect(ok(deck.streaks.load()).current, count, reason: course.id);
      }
    },
  );

  for (final mandarin in ['cmn-CN', 'zh-CN']) {
    test(
      'course speech prefers installed fr-FR, $mandarin, ar-SA and ko-KR',
      () async {
        final calls = mockVoices(
          installed: [
            'fr-CA',
            'zh-HK',
            'zh-TW',
            'ar-EG',
            'yue-HK',
            'fr-FR',
            mandarin,
            'ar-SA',
            'ko',
            'ko-KR',
          ],
          online: ['fr-FR', mandarin, 'ar-SA', 'ko-KR'],
        );
        final locales = {
          'fr': 'fr-FR',
          'zh': mandarin,
          'ar': 'ar-SA',
          'ko': 'ko-KR',
        };
        final spoken = <String>[];
        for (final language in locales.keys) {
          final course = StudyCourse.multilingualCourses.firstWhere(
            (course) => course.studyLanguage == language,
          );
          final deck = await load(course, newHistory());
          final text = deck.items.first.word.headword;
          expect(await deck.speech.speak(text), SpeechResult.completed);
          spoken.add(text);
        }

        expect(
          calls
              .where((call) => call.method == 'setVoice')
              .map((call) => call.arguments),
          [
            for (final locale in locales.values)
              {'name': 'local $locale', 'locale': locale},
          ],
        );
        expect(
          calls
              .where((call) => call.method == 'speak')
              .map((call) => call.arguments),
          spoken,
        );
      },
    );
  }

  test(
    'Japanese speech uses the installed ja-JP voice and the card reading',
    () async {
      final calls = mockVoices(installed: ['ja', 'ja-JP'], online: ['ja-JP']);
      final course = StudyCourse.multilingualCourses.firstWhere(
        (course) => course.id == 'ru-ja',
      );
      final deck = await load(course, newHistory());
      final word =
          deck.items.firstWhere((item) {
            return item.word.text == '学校';
          }).word;
      expect(await deck.speech.speak(word.text), SpeechResult.completed);
      expect(calls.singleWhere((call) => call.method == 'setVoice').arguments, {
        'name': 'local ja-JP',
        'locale': 'ja-JP',
      });
      expect(
        calls.singleWhere((call) => call.method == 'speak').arguments,
        'がっこう',
      );
    },
  );

  test(
    'Mandarin reports unavailable with only Cantonese and cloud Mandarin',
    () async {
      final calls = mockVoices(
        installed: ['zh-HK', 'yue-HK'],
        online: ['zh-CN', 'cmn-CN'],
      );
      final course = StudyCourse.multilingualCourses.firstWhere(
        (course) => course.studyLanguage == 'zh',
      );
      final deck = await load(course, newHistory());
      expect(
        await deck.speech.speak(deck.items.first.word.headword),
        SpeechResult.unavailable,
      );
      final methods = calls.map((call) => call.method);
      expect(methods, contains('getVoices'));
      expect(methods, isNot(contains('setVoice')));
      expect(methods, isNot(contains('speak')));
    },
  );
}
