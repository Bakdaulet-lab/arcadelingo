import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/events/app_event.dart';
import 'package:arcadelingo/domain/kitchen/kitchen_shift.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/order_kitchen/order_kitchen_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_answer_log.dart';
import '../support/in_memory_event_log.dart';
import '../support/in_memory_stores.dart';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 650));
}

void main() {
  testWidgets('A1 kitchen follows the course and counts only finished shifts', (
    tester,
  ) async {
    const course = StudyCourse.spanishFromEnglish;
    final homeStreak = InMemoryStreakStore();
    final cafeStreak = InMemoryStreakStore();
    final cafeEvents = InMemoryEventLog();
    final answers = InMemoryAnswerLog();
    const items = [
      ReviewItem(word: Word(id: 'cafe', text: 'café', translation: 'coffee')),
      ReviewItem(
        word: Word(
          id: 'turno',
          text: 'turno',
          translation: 'shift',
          level: CefrLevel.a2,
        ),
      ),
    ];
    await tester.pumpWidget(
      WordarcadeApp(
        now: () => DateTime(2026, 6, 10, 12),
        ports: AppPorts(cards: InMemoryCardStore(), streaks: homeStreak),
        seed: const Ok([
          ReviewItem(word: Word(id: 'tea', text: 'tea', translation: 'чай')),
        ]),
        additionalDecks: [
          CourseDeck(
            course: course,
            items: items,
            cards: InMemoryCardStore(),
            answers: answers,
            streaks: cafeStreak,
            events: cafeEvents,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final kitchen = find.byKey(AppKeys.orderKitchen);
    expect(kitchen, findsOneWidget);
    await _tap(tester, find.byKey(AppKeys.course));
    await _tap(tester, find.byKey(const ValueKey('course.en-es')));
    await _tap(tester, find.text('A2'));
    expect(kitchen, findsNothing);
    await _tap(tester, find.text('A1'));
    await _tap(tester, kitchen);
    final game = tester.widget<OrderKitchenGame>(find.byType(OrderKitchenGame));
    expect(game.course.id, course.id);
    final orders = kitchenOrdersFor(
      course: course,
      level: CefrLevel.a1,
      seed: game.seed,
    );
    for (final order in orders) {
      expect(find.text(order.phrase('es')), findsOneWidget);
      for (final ingredient in order.ingredients) {
        await _tap(
          tester,
          find.byKey(Key('kitchen.ingredient.${ingredient.name}')),
        );
      }
      await _tap(tester, find.byKey(const Key('kitchen.serve')));
      await _tap(tester, find.byKey(const Key('kitchen.next')));
    }
    expect(cafeStreak.state.current, 1);
    expect(homeStreak.state.current, 0);
    expect(answers.records, isEmpty);
    await _tap(tester, find.byKey(const Key('kitchen.replay')));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(kitchen, findsOneWidget);
    final shifts =
        cafeEvents.events.where((e) => e.kind != AppEventKind.appOpen).toList();
    expect(shifts.map((e) => e.kind), [
      AppEventKind.roundStart,
      AppEventKind.roundOver,
      AppEventKind.roundStart,
      AppEventKind.roundAbandon,
    ]);
    expect(shifts[0].sessionId, shifts[1].sessionId);
    expect(shifts[2].sessionId, shifts[3].sessionId);
    expect(shifts[0].sessionId, isNot(shifts[2].sessionId));
    expect(tester.takeException(), isNull);
  });
}
