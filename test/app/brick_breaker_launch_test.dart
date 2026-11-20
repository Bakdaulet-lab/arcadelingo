import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';

void main() {
  testWidgets('арканоид запускается с главной и записывает ответ уровня B1', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final answers = InMemoryAnswerLog();
    await tester.pumpWidget(
      WordarcadeApp(
        ports: AppPorts(
          cards: InMemoryCardStore(),
          streaks: InMemoryStreakStore(),
          answers: answers,
        ),
        now: () => DateTime(2026, 11, 20),
        seed: const Ok([
          ReviewItem(
            word: Word(id: 'apple', text: 'apple', translation: 'яблоко'),
          ),
          ReviewItem(
            word: Word(
              id: 'shelter',
              text: 'shelter',
              translation: 'убежище',
              level: CefrLevel.b1,
            ),
            distractors: ['подъезд', 'двор', 'балкон'],
          ),
        ]),
      ),
    );
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
    expect(find.text('shelter'), findsOneWidget);
    expect(find.text('apple'), findsNothing);
    final answer = find.text('убежище');
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
    expect(answers.records.single.wordId, 'shelter');
    expect(answers.records.single.correct, isTrue);
  });
}
