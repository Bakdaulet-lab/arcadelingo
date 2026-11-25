import 'dart:math';

import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/data/challenges/challenge_prefs_store.dart';
import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/usecases/start_session.dart';
import 'package:arcadelingo/features/games/match_three/match_three_game.dart';
import 'package:arcadelingo/features/games/match_three/match_three_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'три обычных совпадения открывают слово выбранного курса и уровня',
    () async {
      final courses = {
        StudyCourse.englishFromRussian: await loadWordsSeed(),
        StudyCourse.spanishFromRussian: await loadSpanishSeed(),
        StudyCourse.spanishFromEnglish: await loadSpanishFromEnglishSeed(),
        StudyCourse.englishFromSpanish: await loadEnglishA1FromSpanishSeed(),
      };
      for (final entry in courses.entries) {
        final items = (entry.value as Ok<List<ReviewItem>>).value;
        final levels = items.map((item) => item.word.level).toSet();
        for (final level in levels) {
          final log = InMemoryAnswerLog();
          final start = StartSession(
            cards: InMemoryCardStore(),
            streaks: InMemoryStreakStore(),
            now: () => DateTime.utc(2026, 11, 26),
            target: 1,
            answerLog: log,
          );
          final session =
              (start(items: items, gameId: 'match_three', level: level)
                      as Ok<ReviewSession>)
                  .value;
          final run = MatchThreeRun(session, Random(0));
          const moves = [(6, 7), (7, 13), (1, 7)];
          for (final (index, move) in moves.indexed) {
            expect(run.swap(move.$1, move.$2), isTrue);
            run.advance();
            expect(run.clearing, hasLength(3));
            for (var phase = 0; phase < 30 && run.isAnimating; phase++) {
              run.advance();
            }
            expect(run.chargeProgress, index + 1);
            expect(log.records, isEmpty);
          }
          expect(
            run.phase,
            MatchThreePhase.question,
            reason: '${entry.key.id}/${level.name}',
          );
          final card = items.firstWhere(
            (item) => item.word.id == run.item!.word.id,
          );
          expect(card.word.level, level);
          expect(run.choices, contains(card.word.translation));
          expect(
            run.choices,
            everyElement(isIn({card.word.translation, ...card.distractors})),
          );
          expect(run.answer(card.word.translation, Duration.zero), isTrue);
          expect(log.records.single.wordId, card.word.id);
          expect(log.records.single.gameId, 'match_three');
        }
      }
    },
  );

  testWidgets('четвёрка запускает перевод выбранного курса и уровня', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final records = ChallengePrefsStore(prefs);
    final baseLog = InMemoryAnswerLog();
    final spanishLog = InMemoryAnswerLog();
    tester.view.physicalSize = const Size(360, 780);
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
        now: () => DateTime(2026, 11, 20),
        seed: const Ok([
          ReviewItem(
            word: Word(id: 'apple', text: 'apple', translation: 'яблоко'),
          ),
        ]),
        additionalDecks: [
          CourseDeck(
            course: StudyCourse.spanishFromEnglish,
            items: const [
              ReviewItem(
                word: Word(id: 'es_llave', text: 'llave', translation: 'key'),
              ),
              ReviewItem(
                word: Word(
                  id: 'es_cuota',
                  text: 'cuota',
                  translation: 'membership fee',
                  level: CefrLevel.b1,
                ),
                distractors: ['rent', 'delivery', 'tax'],
              ),
            ],
            cards: InMemoryCardStore(),
            streaks: InMemoryStreakStore(),
            answers: spanishLog,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(AppKeys.course));
    await _tap(tester, find.byKey(const ValueKey('course.en-es')));
    await _tap(tester, find.widgetWithText(ChoiceChip, 'B1'));
    await _tap(tester, find.text('Три в ряд'));
    await _tap(tester, find.byKey(AppKeys.play));
    final from = find.byKey(MatchThreeKeys.cell(9));
    final to = find.byKey(MatchThreeKeys.cell(15));
    await tester.dragFrom(
      tester.getCenter(from),
      tester.getCenter(to) - tester.getCenter(from),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(MatchThreeKeys.word), findsOneWidget);
    expect(find.text('cuota'), findsOneWidget);
    expect(find.text('llave'), findsNothing);
    expect(find.text('apple'), findsNothing);
    await _tap(tester, find.text('membership fee'));
    expect(find.byKey(MatchThreeKeys.summary), findsOneWidget);
    expect(spanishLog.records.single.wordId, 'es_cuota');
    expect(spanishLog.records.single.gameId, 'match_three');
    expect(spanishLog.records.single.correct, isTrue);
    expect(baseLog.records, isEmpty);
    const scoreKey = (
      gameId: 'match_three',
      courseId: 'en-es',
      level: CefrLevel.b1,
    );
    expect(records.load(scoreKey), greaterThanOrEqualTo(160));
  });
}
