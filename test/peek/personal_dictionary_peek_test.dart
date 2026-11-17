@Tags(['peek'])
library;

import 'package:arcadelingo/app/dictionary_view.dart';
import 'package:arcadelingo/app/learning_views.dart';
import 'package:arcadelingo/data/dictionary/favorites_prefs_store.dart';
import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bundled_fonts.dart';
import '../support/in_memory_answer_log.dart';
import 'peek_harness.dart';

const _climate = Word(
  id: 'climate',
  text: 'climate',
  translation: 'климат',
  partOfSpeech: 'noun',
  example: 'The climate is changing.',
  level: CefrLevel.b1,
);
const _words = [
  _climate,
  Word(
    id: 'journey',
    text: 'journey',
    translation: 'путешествие',
    level: CefrLevel.b1,
  ),
  Word(
    id: 'duty',
    text: 'duty',
    translation: 'обязанность',
    level: CefrLevel.b1,
  ),
  Word(
    id: 'approve',
    text: 'approve',
    translation: 'одобрять',
    level: CefrLevel.b1,
  ),
];

AnswerRecord _answer(String id, int day, bool correct, String game) {
  final at = DateTime(2026, 11, day);
  return AnswerRecord(
    wordId: id,
    at: at,
    localDay: StreakDay.of(at),
    grade: correct ? ReviewGrade.good : ReviewGrade.again,
    correct: correct,
    responseTime: const Duration(seconds: 1),
    timeLimit: const Duration(seconds: 3),
    hintsUsed: 0,
    gameId: game,
    sessionId: 'preview',
  );
}

Future<void> _openPage(WidgetTester tester, Widget page) async {
  await pumpPeek(
    tester,
    Builder(
      builder:
          (context) => TextButton(
            onPressed:
                () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (context) => page)),
            child: const Text('Открыть'),
          ),
    ),
  );
  await tester.tap(find.text('Открыть'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);

  testWidgets('личный словарь и история слова', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final favorites = FavoritesPrefsStore(
      await SharedPreferences.getInstance(),
    );
    await favorites.save({'climate', 'journey'});
    final log =
        InMemoryAnswerLog()
          ..records.addAll([
            _answer('approve', 14, true, 'falling_words'),
            _answer('climate', 14, true, 'falling_words'),
            _answer('duty', 15, false, 'ninja_slash'),
            _answer('journey', 16, true, 'falling_words'),
            _answer('climate', 17, false, 'falling_words'),
            _answer('climate', 18, false, 'ninja_slash'),
          ]);
    await _openPage(
      tester,
      DictionaryScreen(
        items: [for (final word in _words) ReviewItem(word: word)],
        level: CefrLevel.b1,
        answers: log,
        favorites: favorites,
        speech: const NoopWordSpeech(),
        gameTitles: const {
          'falling_words': 'Падающие слова',
          'ninja_slash': 'Ниндзя-слэш',
        },
      ),
    );
    await peek(tester, 'personal_dictionary');
    await tester.tap(find.text('climate'));
    await tester.pumpAndSettle();
    await peek(tester, 'personal_dictionary_word');
  });

  testWidgets('сравнение перевода и выбранного ответа', (tester) async {
    await _openPage(
      tester,
      MistakesReviewScreen(
        words: const [_climate],
        level: CefrLevel.b1,
        speech: const NoopWordSpeech(),
        outcomes: const {
          'climate': ReviewOutcome(
            correct: false,
            responseTime: Duration(seconds: 1),
            timeLimit: Duration(seconds: 3),
            selectedAnswer: 'погода',
          ),
        },
      ),
    );
    await peek(tester, 'personal_dictionary_mistake');
  });
}
