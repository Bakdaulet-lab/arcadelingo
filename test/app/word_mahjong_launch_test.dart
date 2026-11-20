import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/app/learning_views.dart';
import 'package:arcadelingo/data/challenges/challenge_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/word_mahjong/word_mahjong_field.dart';
import 'package:arcadelingo/features/games/word_mahjong/word_mahjong_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';

class _Speech implements WordSpeech {
  final words = <String>[];

  @override
  Future<SpeechResult> speak(String text) async {
    words.add(text);
    return SpeechResult.completed;
  }

  @override
  Future<void> stop() async {}
}

ReviewItem _word(
  String text,
  String translation, [
  CefrLevel level = CefrLevel.a1,
]) => ReviewItem(
  word: Word(id: text, text: text, translation: translation, level: level),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'plays without a timer, reviews mistakes and stores only the selected course and level',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final records = ChallengePrefsStore(
        await SharedPreferences.getInstance(),
      );
      final baseLog = InMemoryAnswerLog();
      final spanishLog = InMemoryAnswerLog();
      final spanishCards = InMemoryCardStore();
      final speech = _Speech();
      tester.view.physicalSize = const Size(320, 680);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        WordarcadeApp(
          ports: AppPorts(
            cards: InMemoryCardStore(),
            streaks: InMemoryStreakStore(),
            answers: baseLog,
            challengeRecords: records,
          ),
          now: () => DateTime(2026, 11, 21),
          seed: Ok([_word('apple', 'яблоко')]),
          additionalDecks: [
            CourseDeck(
              course: StudyCourse.spanishFromEnglish,
              items: [
                _word('llave', 'key'),
                _word('cuota', 'membership fee', CefrLevel.b1),
                _word('beca', 'scholarship', CefrLevel.b1),
              ],
              cards: spanishCards,
              streaks: InMemoryStreakStore(),
              answers: spanishLog,
              speech: speech,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(AppKeys.course));
      await _tap(tester, find.byKey(const ValueKey('course.en-es')));
      await _tap(tester, find.widgetWithText(ChoiceChip, 'B1'));
      await _tap(tester, find.text('Маджонг со словами'));
      await _tap(tester, find.byKey(const Key('app.learn')));
      final intro = tester.widget<WordIntroductionScreen>(
        find.byType(WordIntroductionScreen),
      );
      expect(intro.words.map((word) => word.id), ['cuota', 'beca']);
      await _tap(tester, find.byKey(LearningKeys.speak));
      expect(speech.words.last, 'cuota');
      await _tap(tester, find.byKey(LearningKeys.next));
      await _tap(tester, find.byKey(LearningKeys.start));

      final field = tester.widget<WordMahjongField>(
        find.byKey(WordMahjongKeys.field),
      );
      expect(
        field.board.tiles.map((tile) => tile.label),
        unorderedEquals(['cuota', 'membership fee', 'beca', 'scholarship']),
      );
      await tester.pump(const Duration(minutes: 2));
      expect(spanishLog.records, isEmpty);
      await _tap(tester, find.text('beca'));
      expect(speech.words.last, 'beca');
      await _tap(tester, find.text('membership fee'));
      expect(
        find.text('Эти плитки не совпадают. Попробуй ещё раз.'),
        findsOneWidget,
      );
      expect(spanishLog.records, isEmpty);
      await _tap(tester, find.text('scholarship'));
      expect(spanishLog.records.single.wordId, 'beca');
      expect(spanishLog.records.single.correct, isFalse);
      await _tap(tester, find.byKey(WordMahjongKeys.hint));
      await _tap(tester, find.text('membership fee'));
      await _tap(tester, find.text('cuota'));
      expect(find.byKey(WordMahjongKeys.summary), findsOneWidget);
      expect(spanishLog.records.map((record) => record.wordId), [
        'beca',
        'cuota',
      ]);
      expect(spanishLog.records.last.correct, isTrue);
      expect(
        spanishLog.records.every((record) => record.gameId == 'word_mahjong'),
        isTrue,
      );
      expect(spanishCards.saves.last.keys, unorderedEquals(['beca', 'cuota']));
      expect(baseLog.records, isEmpty);
      expect(
        records.load((
          gameId: 'word_mahjong',
          courseId: 'en-es',
          level: CefrLevel.b1,
        )),
        125,
      );
      expect(
        records.load((
          gameId: 'word_mahjong',
          courseId: 'ru-en',
          level: CefrLevel.b1,
        )),
        isNull,
      );
      expect(
        records.load((
          gameId: 'word_mahjong',
          courseId: 'en-es',
          level: CefrLevel.a1,
        )),
        isNull,
      );
      await _tap(tester, find.byKey(const Key('game.review_mistakes')));
      final review = tester.widget<MistakesReviewScreen>(
        find.byType(MistakesReviewScreen),
      );
      expect(review.words.single.id, 'beca');
      expect(find.text('membership fee'), findsOneWidget);
      expect(find.text('scholarship'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
