import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/events/app_event.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:arcadelingo/features/recall/recall_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_answer_log.dart';
import '../support/in_memory_event_log.dart';
import '../support/in_memory_stores.dart';

ReviewItem _item(
  String text,
  String translation, [
  CefrLevel level = CefrLevel.b1,
]) => ReviewItem(
  word: Word(id: text, text: text, translation: translation, level: level),
);

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'recall uses familiar words and choices from the selected course and level only',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      const course = StudyCourse.spanishFromEnglish;
      final date = DateTime(2026, 11, 25);
      final cards = InMemoryCardStore({
        'avería': LeitnerCard(box: 3, due: date.add(const Duration(days: 3))),
      });
      final log = InMemoryAnswerLog();
      final baseLog = InMemoryAnswerLog();
      final events = InMemoryEventLog();
      final streaks = InMemoryStreakStore();
      await tester.pumpWidget(
        WordarcadeApp(
          ports: AppPorts(
            cards: InMemoryCardStore(),
            streaks: InMemoryStreakStore(),
            answers: baseLog,
          ),
          seed: Ok([_item('repair', 'ремонт')]),
          additionalDecks: [
            CourseDeck(
              course: course,
              items: [
                _item('comprar', 'to buy', CefrLevel.a1),
                _item('reseña', 'review'),
                _item('avería', 'breakdown'),
                _item('huésped', 'guest'),
              ],
              cards: cards,
              answers: log,
              streaks: streaks,
              events: events,
            ),
          ],
          now: () => date,
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(AppKeys.course));
      await _tap(tester, find.byKey(ValueKey('course.${course.id}')));
      await _tap(tester, find.text('B1'));
      await _tap(tester, find.byKey(AppKeys.recall));
      final screen = tester.widget<RecallScreen>(find.byType(RecallScreen));
      expect(
        screen.vocabulary.map((w) => w.text),
        unorderedEquals(['reseña', 'avería', 'huésped']),
      );
      expect(screen.course, course);
      expect(screen.level, CefrLevel.b1);
      expect(find.text('breakdown'), findsOneWidget);
      expect(find.text('avería'), findsNothing);
      await _tap(tester, find.byKey(const Key('recall.options')));
      expect(find.text('comprar'), findsNothing);
      expect(find.text('repair'), findsNothing);
      await _tap(tester, find.text('avería'));
      await _tap(tester, find.byKey(const Key('recall.next')));
      expect(find.byKey(const Key('recall.summary')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('recall.exit')));
      expect(log.records.single.gameId, 'active_recall');
      expect(log.records.single.wordId, 'avería');
      expect(log.records.single.grade, ReviewGrade.hard);
      expect(cards.saves, hasLength(1));
      expect(baseLog.records, isEmpty);
      expect(
        events.kinds.where((kind) => kind == AppEventKind.roundOver),
        hasLength(1),
      );
      expect(streaks.saves, hasLength(1));

      await _tap(tester, find.byKey(AppKeys.recall));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(log.records, hasLength(1));
      expect(events.kinds.last, AppEventKind.roundAbandon);
      expect(streaks.saves, hasLength(1));
    },
  );
}
