import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/domain/candy_delivery/candy_orders.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/events/app_event.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/candy_delivery/candy_delivery_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_answer_log.dart';
import '../support/in_memory_event_log.dart';
import '../support/in_memory_stores.dart';

Future<void> tapControl(WidgetTester tester, Finder control) async {
  await tester.ensureVisible(control);
  await tester.tap(control);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets(
    'switch course and level, retry a miss, finish only the active course',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      const course = StudyCourse.spanishFromEnglish;
      final homeStreak = InMemoryStreakStore();
      final targetStreak = InMemoryStreakStore();
      final events = InMemoryEventLog();
      await tester.pumpWidget(
        WordarcadeApp(
          now: () => DateTime(2026, 10, 10, 12),
          seed: const Ok([
            ReviewItem(word: Word(id: 'tea', text: 'tea', translation: 'чай')),
          ]),
          ports: AppPorts(cards: InMemoryCardStore(), streaks: homeStreak),
          additionalDecks: [
            CourseDeck(
              course: course,
              cards: InMemoryCardStore(),
              answers: InMemoryAnswerLog(),
              streaks: targetStreak,
              events: events,
              items: const [
                ReviewItem(
                  word: Word(id: 'sol', text: 'sol', translation: 'sun'),
                ),
                ReviewItem(
                  word: Word(
                    id: 'nube',
                    text: 'nube',
                    translation: 'cloud',
                    level: CefrLevel.a2,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final tile = find.byKey(AppKeys.candyDelivery);
      await tapControl(tester, find.text('B2'));
      expect(tile, findsNothing);
      await tapControl(tester, find.byKey(AppKeys.course));
      await tapControl(tester, find.byKey(const ValueKey('course.en-es')));
      await tapControl(tester, find.text('A2'));
      await tapControl(tester, tile);
      final game = tester.widget<CandyDeliveryGame>(
        find.byType(CandyDeliveryGame),
      );
      expect(game.course.id, course.id);
      expect(game.level, CefrLevel.a2);
      final orders = candyOrdersFor(
        course: course,
        level: CefrLevel.a2,
        seed: game.seed,
      );
      for (final (n, order) in orders.indexed) {
        final correct = order.rabbits.indexOf(order.target);
        expect(find.text(order.phrase), findsOneWidget);
        expect(find.text(order.translation), findsNothing);
        await tapControl(tester, find.byKey(const Key('candy.hint')));
        expect(find.text(order.translation), findsOneWidget);
        if (n == 0) {
          await tapControl(
            tester,
            find.byKey(Key('candy.aim.${(correct + 1) % 3}')),
          );
          await tapControl(tester, find.byKey(const Key('candy.cut')));
          expect(
            tester.widget<Text>(find.byKey(const Key('candy.status'))).data,
            'Конфета у другого кролика',
          );
          await tapControl(tester, find.byKey(const Key('candy.retry')));
          expect(find.text(order.phrase), findsOneWidget);
        }
        await tapControl(tester, find.byKey(Key('candy.aim.$correct')));
        await tapControl(tester, find.byKey(const Key('candy.cut')));
        expect(
          tester.widget<Text>(find.byKey(const Key('candy.status'))).data,
          'Доставлено!',
        );
        if (n < orders.length - 1) {
          await tapControl(tester, find.byKey(const Key('candy.next')));
        }
      }
      expect(targetStreak.state.current, 1);
      expect(homeStreak.state.current, 0);
      await tapControl(tester, find.byKey(const Key('candy.replay')));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tile, findsOneWidget);
      expect(events.kinds.where((event) => event != AppEventKind.appOpen), [
        AppEventKind.roundStart,
        AppEventKind.roundOver,
        AppEventKind.roundStart,
        AppEventKind.roundAbandon,
      ]);
      expect(tester.takeException(), isNull);
    },
  );
}
