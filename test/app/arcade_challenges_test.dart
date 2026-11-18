import 'dart:math';

import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/data/challenges/challenge_prefs_store.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/domain/challenges/challenge_session.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/ports/answer_log.dart';
import 'package:arcadelingo/domain/ports/challenge_records.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_run.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/claw_actions.dart';
import '../support/fake_review_session.dart';
import '../support/in_memory_stores.dart';

const _english = ReviewItem(
  word: Word(id: 'cat', text: 'cat', translation: 'кошка'),
  distractors: ['собака'],
);
const _advanced = ReviewItem(
  word: Word(
    id: 'dog',
    text: 'dog',
    translation: 'собака',
    level: CefrLevel.a2,
  ),
);
const _spanish = ReviewItem(
  word: Word(id: 'pez', text: 'pez', translation: 'рыба'),
);
const _correct = ReviewOutcome.untimed(
  correct: true,
  responseTime: Duration.zero,
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<ChallengePrefsStore> _openChallengeApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final records = ChallengePrefsStore(prefs);
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    WordarcadeApp(
      ports: AppPorts(
        cards: InMemoryCardStore(),
        streaks: InMemoryStreakStore(),
        settings: SettingsPrefsStore(prefs),
        challengeRecords: records,
      ),
      seed: const Ok([_english, _advanced]),
      additionalDecks: [
        CourseDeck(
          course: StudyCourse.spanishFromRussian,
          items: const [_spanish, _advanced],
          cards: InMemoryCardStore(),
          streaks: InMemoryStreakStore(),
          answers: const NoopAnswerLog(),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
  return records;
}

Future<void> _startTimedChallenge(WidgetTester tester, Duration windUp) async {
  await _tap(tester, find.byKey(AppKeys.challenge));
  await tester.tap(find.byKey(const Key('challenge.start')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(windUp);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'challenge cycles within the selected level and enforces the review protocol',
    () {
      final session = ChallengeSession(
        items: const [_english, _advanced],
        level: CefrLevel.a1,
        random: Random(42),
        limit: 3,
      );
      for (var i = 0; i < 3; i++) {
        expect(session.nextItem(), _english);
        expect(session.nextItem, throwsStateError);
        session.report(_correct);
        expect(() => session.report(_correct), throwsStateError);
      }
      expect(session.isFinished, isTrue);
      expect(session.nextItem(), isNull);
    },
  );

  test(
    'sprint starts at 60 seconds, penalizes misses and cuts off the last word',
    () {
      final session = FakeReviewSession(List.filled(12, _english));
      final run = FallingWordsRun(
        session: session,
        random: Random(42),
        sprint: true,
      )..start();
      expect(run.sprintRemaining, const Duration(seconds: 60));
      for (var i = 0; i < 5; i++) {
        expect(run.timeout(), isTrue);
        run.advance();
      }
      expect(run.sprintRemaining, const Duration(seconds: 1));
      expect(run.timeLimit, const Duration(seconds: 1));
      expect(run.timeout(), isTrue);
      run.advance();
      expect(run.phase, FallingPhase.over);
      expect(run.lives, FallingWordsRun.startLives);
      expect(
        session.reports.last.outcome.responseTime,
        const Duration(seconds: 1),
      );
      expect(session.reports.last.outcome.timedOut, isTrue);
      expect(session.nextItemCalls, 6);
    },
  );

  test(
    'ninja misses reset the streak and eight precise hits end the round',
    () {
      final session = FakeReviewSession(List.filled(15, _english));
      final run = NinjaRun(
        session: session,
        random: Random(42),
        streakChallenge: true,
      )..start();
      run.slice(run.correctIndex, const Duration(milliseconds: 500));
      run.advance();
      run.slice(1 - run.correctIndex, const Duration(milliseconds: 500));
      expect(run.combo, 0);
      run.advance();
      for (var i = 0; i < 8; i++) {
        run.slice(run.correctIndex, const Duration(milliseconds: 500));
        run.advance();
      }
      expect(run.bestCombo, 8);
      expect(run.phase, NinjaPhase.over);
      expect(session.nextItemCalls, 10);
    },
  );

  test('claw uses one hint across words', () {
    final session = FakeReviewSession([_spanish, _spanish]);
    final run = ClawMachineRun(session, Random(42), hintLimit: 1)..advance();
    expect(run.hint(), isNotNull);
    for (final letter in 'PEZ'.split('')) {
      final i = run.stacks.indexWhere((s) => s.isNotEmpty && s.last == letter);
      run.grab(i, Duration.zero);
    }
    run.advance();
    expect(run.hint(), isNull);
    expect(run.hintsRemaining, 0);
    expect(session.reports.single.outcome.hintsUsed, 1);
  });

  test(
    'records isolate game, course and level and preserve the maximum upon reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var store = ChallengePrefsStore(prefs);
      const base = (
        gameId: 'falling_words',
        courseId: 'ru-en',
        level: CefrLevel.a1,
      );
      const game = (
        gameId: 'ninja_slash',
        courseId: 'ru-en',
        level: CefrLevel.a1,
      );
      const course = (
        gameId: 'falling_words',
        courseId: 'ru-es',
        level: CefrLevel.a1,
      );
      const level = (
        gameId: 'falling_words',
        courseId: 'ru-en',
        level: CefrLevel.a2,
      );
      await Future.wait([store.submit(base, 42), store.submit(base, 8)]);
      await store.submit(game, 5);
      await store.submit(course, 20);
      await store.submit(level, 55);
      await prefs.reload();
      store = ChallengePrefsStore(prefs);
      expect(
        [
          for (final key in [base, game, course, level]) store.load(key),
        ],
        [42, 5, 20, 55],
      );
    },
  );

  testWidgets(
    'claw challenge takes three words from the chosen course and records only completed rounds',
    (tester) async {
      final records = await _openChallengeApp(tester);
      const ChallengeKey spanish = (
        gameId: 'claw_machine',
        courseId: 'ru-es',
        level: CefrLevel.a1,
      );
      const ChallengeKey english = (
        gameId: 'claw_machine',
        courseId: 'ru-en',
        level: CefrLevel.a1,
      );
      await _tap(tester, find.byKey(const Key('app.course')));
      await _tap(tester, find.byKey(const ValueKey('course.ru-es')));
      await _tap(tester, find.text('Автомат с клешнёй'));
      await _tap(tester, find.byKey(const Key('app.challenge')));
      await _tap(tester, find.byKey(const Key('challenge.start')));
      await spellWithClaw(tester, 'pez');
      await _tap(tester, find.byType(BackButton));
      expect(records.load(spanish), isNull);

      await _tap(tester, find.byKey(AppKeys.challenge));
      expect(find.text('Рекорда пока нет'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('challenge.start')));
      for (var i = 0; i < 3; i++) {
        expect(find.text('рыба'), findsOneWidget);
        expect(find.text('кошка'), findsNothing);
        expect(find.text('собака'), findsNothing);
        if (i == 0) await tapClaw(tester, ClawKeys.hint);
        if (i == 1) {
          final hint = tester.widget<TextButton>(find.byKey(ClawKeys.hint));
          expect(hint.onPressed, isNull);
        }
        await spellWithClaw(tester, 'pez');
        if (i < 2) expect(records.load(spanish), isNull);
        await tapClaw(tester, ClawKeys.next);
      }
      expect(records.load(spanish), 3);
      expect(records.load(english), isNull);
      expect(find.text('Личный рекорд: 3'), findsOneWidget);
      await _tap(tester, find.text('Выйти'));
      await _tap(tester, find.byKey(AppKeys.challenge));
      expect(find.text('Личный рекорд: 3'), findsOneWidget);
    },
  );
  testWidgets(
    'sprint stays at English A2 and persists the score when time runs out',
    (tester) async {
      final records = await _openChallengeApp(tester);
      await _tap(tester, find.widgetWithText(ChoiceChip, 'A2'));
      await _startTimedChallenge(tester, FallingWordsRun.windUpTime);
      expect(find.text('dog'), findsOneWidget);
      expect(find.text('cat'), findsNothing);
      expect(find.text('pez'), findsNothing);
      expect(find.textContaining('Осталось 60 с'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('Осталось 58 с'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 15));
      expect(find.textContaining('Осталось 58 с'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('собака'));
      await tester.pump();
      await tester.pump(FallingWordsRun.correctReveal);

      const ChallengeKey key = (
        gameId: 'falling_words',
        courseId: 'ru-en',
        level: CefrLevel.a2,
      );
      expect(records.load(key), isNull);
      for (
        var i = 0;
        i < 7 && find.text('Раунд окончен').evaluate().isEmpty;
        i++
      ) {
        await tester.pump();
        expect(find.text('dog'), findsOneWidget);
        await tester.pump(FallingWordsRun.baseFallTime);
        await tester.pump();
        await tester.pump(FallingWordsRun.wrongReveal);
      }
      await tester.pumpAndSettle();
      expect(records.load(key), 10);
      expect(find.text('Личный рекорд: 10'), findsOneWidget);
      const a1 = (
        gameId: 'falling_words',
        courseId: 'ru-en',
        level: CefrLevel.a1,
      );
      expect(records.load(a1), isNull);
    },
  );

  testWidgets('ninja stops at eight and saves the Spanish A1 streak', (
    tester,
  ) async {
    final records = await _openChallengeApp(tester);
    await _tap(tester, find.byKey(AppKeys.course));
    await _tap(tester, find.byKey(const ValueKey('course.ru-es')));
    await _tap(tester, find.text('Ниндзя-слэш'));
    await _startTimedChallenge(tester, NinjaRun.windUpTime);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 850));
      expect(find.text('pez'), findsOneWidget);
      expect(find.text('cat'), findsNothing);
      expect(find.text('dog'), findsNothing);
      final center = tester.getCenter(find.text('рыба'));
      final slash = await tester.startGesture(center - const Offset(30, 0));
      await slash.moveTo(center + const Offset(30, 0));
      await slash.up();
      await tester.pump();
      await tester.pump(NinjaRun.correctReveal);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Личный рекорд: 8'), findsOneWidget);
    const ninja = (
      gameId: 'ninja_slash',
      courseId: 'ru-es',
      level: CefrLevel.a1,
    );
    const claw = (
      gameId: 'claw_machine',
      courseId: 'ru-es',
      level: CefrLevel.a1,
    );
    expect(records.load(ninja), 8);
    expect(records.load(claw), isNull);
  });
}
