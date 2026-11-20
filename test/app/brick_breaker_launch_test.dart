import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/data/challenges/challenge_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';

void main() {
  testWidgets('арканоид записывает ответ и рекорд выбранного курса и уровня', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final scores = ChallengePrefsStore(prefs);
    final answers = InMemoryAnswerLog();
    final otherAnswers = InMemoryAnswerLog();
    final cards = InMemoryCardStore();
    final otherCards = InMemoryCardStore();
    await tester.pumpWidget(
      WordarcadeApp(
        ports: AppPorts(
          cards: otherCards,
          streaks: InMemoryStreakStore(),
          answers: otherAnswers,
          challengeRecords: scores,
        ),
        now: () => DateTime(2026, 11, 20),
        seed: const Ok([
          ReviewItem(
            word: Word(
              id: 'apple',
              text: 'apple',
              translation: 'яблоко',
              level: CefrLevel.b1,
            ),
          ),
        ]),
        additionalDecks: [
          CourseDeck(
            course: StudyCourse.spanishFromEnglish,
            cards: cards,
            streaks: InMemoryStreakStore(),
            answers: answers,
            items: const [
              ReviewItem(
                word: Word(id: 'agua', text: 'agua', translation: 'water'),
              ),
              ReviewItem(
                word: Word(
                  id: 'cuota',
                  text: 'cuota',
                  translation: 'membership fee',
                  level: CefrLevel.b1,
                ),
                distractors: ['roof leak', 'delivery', 'bill'],
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.course));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('course.en-es')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'B1'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Арканоид'));
    await tester.tap(find.text('Арканоид'));
    await tester.pumpAndSettle();
    final play = find.byKey(AppKeys.play);
    await tester.ensureVisible(play);
    await tester.tap(play);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BrickBreakerKeys.launch));
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('cuota'), findsOneWidget);
    expect(find.text('apple'), findsNothing);
    expect(find.text('agua'), findsNothing);
    final answer = find.text('membership fee');
    final field = tester.getRect(find.byKey(BrickBreakerKeys.field));
    final x = tester.getCenter(answer).dx;
    await tester.dragFrom(
      Offset(field.center.dx, field.bottom - 26),
      Offset(x - field.center.dx, 0),
    );
    for (var i = 0; i < 260; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(answers.records.single.gameId, 'brick_breaker');
    expect(answers.records.single.wordId, 'cuota');
    expect(answers.records.single.correct, isTrue);
    expect(otherAnswers.records, isEmpty);
    expect(otherCards.saves, isEmpty);
    expect(cards.saves, hasLength(1));
    await prefs.reload();
    expect(
      scores.load((
        gameId: 'brick_breaker',
        courseId: 'en-es',
        level: CefrLevel.b1,
      )),
      110,
    );
    expect(
      scores.load((
        gameId: 'brick_breaker',
        courseId: 'en-es',
        level: CefrLevel.a1,
      )),
      isNull,
    );
    expect(
      scores.load((
        gameId: 'brick_breaker',
        courseId: 'ru-en',
        level: CefrLevel.b1,
      )),
      isNull,
    );
  });
}
