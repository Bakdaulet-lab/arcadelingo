import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/space_word/space_field.dart';
import 'package:arcadelingo/features/games/space_word/space_flight.dart';
import 'package:arcadelingo/features/games/space_word/space_word_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';

const moon = Word(id: 'luna', text: 'luna', translation: 'Луна');
const sun = Word(id: 'sol', text: 'sol', translation: 'Солнце');
const sea = Word(id: 'mar', text: 'mar', translation: 'Море');
const cloud = Word(id: 'nube', text: 'nube', translation: 'Облако');
const imposter = Word(
  id: 'extra',
  text: 'astro',
  translation: 'небесное тело',
  level: CefrLevel.c1,
);
const synonym = Word(id: 'synonym', text: 'lunar', translation: 'Луна');
const vocabulary = [moon, sun, sea, cloud, imposter, synonym];

void main() {
  testWidgets('a corrected interception records the first pick only', (
    t,
  ) async {
    final session = FakeReviewSession([const ReviewItem(word: moon)]);
    var ends = 0;
    int? record;
    await t.pumpWidget(
      MaterialApp(
        home: SpaceWordGame(
          session: session,
          course: StudyCourse.spanishFromRussian,
          level: CefrLevel.a1,
          vocabulary: vocabulary,
          onPlayAgain: () {},
          onExit: () {},
          onRoundOver: () => ends++,
          onRoundScore: (n) {
            record = n;
            return const SizedBox();
          },
          seed: 12,
        ),
      ),
    );
    expect(t.widget<Text>(find.byKey(SpaceWordKeys.prompt)).data, 'Луна');
    await t.tap(find.byKey(SpaceWordKeys.start));
    await t.pump();
    final field = t.widget<SpaceField>(find.byType(SpaceField));
    expect(field.labels, hasLength(3));
    expect(field.labels, contains('luna'));
    expect(field.labels, isNot(contains('lunar')));
    expect(field.labels, isNot(contains('astro')));
    final wrong = field.labels.indexWhere((s) => s != 'luna');
    field.onEvent(FlightEvent(wrong));
    await t.pump();
    expect(session.reports.single.outcome.selectedAnswer, field.labels[wrong]);
    expect(session.reports.single.outcome.correct, isFalse);
    field.onEvent(FlightEvent(field.labels.indexOf('luna')));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.byKey(SpaceWordKeys.summary), findsOneWidget);
    expect(record, 100);
    expect(ends, 1);
    expect(session.reports, hasLength(1));
  });

  testWidgets('pause, physical collisions, exit and no-answer accounting', (
    t,
  ) async {
    final session = FakeReviewSession([const ReviewItem(word: sun)]);
    var ends = 0;
    await t.pumpWidget(
      MaterialApp(
        home: SpaceWordGame(
          session: session,
          vocabulary: vocabulary,
          onPlayAgain: () {},
          onExit: () {},
          onRoundOver: () => ends++,
        ),
      ),
    );
    await t.tap(find.byKey(SpaceWordKeys.start));
    await t.pump();
    SpaceField field() => t.widget<SpaceField>(find.byType(SpaceField));
    field().onPause();
    await t.pump();
    expect(field().playing, isFalse);
    field().onEvent(const FlightEvent(null));
    await t.tap(find.byKey(SpaceWordKeys.start));
    await t.pump();
    field().onEvent(const FlightEvent(null));
    await t.pump();
    expect(session.reports, isEmpty);
    field().onEvent(const FlightEvent(null));
    await t.pump();
    expect(ends, 0);
    field().onEvent(const FlightEvent(null));
    await t.pump();
    expect(find.byKey(SpaceWordKeys.summary), findsOneWidget);
    expect(ends, 1);
    expect(session.reports.single.outcome.selectedAnswer, isNull);
    expect(session.reports.single.outcome.correct, isFalse);
  });

  testWidgets(
    'five answers finish a longer session without reserving a sixth',
    (t) async {
      final session = FakeReviewSession(
        List.filled(8, const ReviewItem(word: moon)),
      );
      await t.pumpWidget(
        MaterialApp(
          home: SpaceWordGame(
            session: session,
            vocabulary: vocabulary,
            onExit: () {},
            onPlayAgain: () {},
          ),
        ),
      );
      await t.tap(find.byKey(SpaceWordKeys.start));
      await t.pump();
      for (var i = 0; i < 5; i++) {
        final field = t.widget<SpaceField>(find.byType(SpaceField));
        field.onEvent(FlightEvent(field.labels.indexOf('luna')));
        await t.pump();
        await t.pump(const Duration(seconds: 1));
      }
      expect(session.answered, 5);
      expect(session.nextItemCalls, 5);
      expect(find.byKey(SpaceWordKeys.summary), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      expect(session.answered, 5);
    },
  );
}
