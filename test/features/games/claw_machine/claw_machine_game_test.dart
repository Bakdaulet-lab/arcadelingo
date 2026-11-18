import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/claw_actions.dart';
import '../../../support/fake_review_session.dart';

const _fish = ReviewItem(
  word: Word(id: 'fish', text: 'fish', translation: 'рыба'),
);

Future<void> _show(
  WidgetTester tester,
  FakeReviewSession session, {
  VoidCallback? finish,
}) async {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: wordarcadeTheme(),
      home: ClawMachineGame(
        session: session,
        onExit: () {},
        onPlayAgain: () {},
        onRoundOver: finish,
        seed: 7,
        now: tester.binding.clock.now,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('нет таймаута, один самостоятельный доклад и один конец', (
    tester,
  ) async {
    final session = FakeReviewSession([_fish]);
    var ends = 0;
    await _show(tester, session, finish: () => ends++);
    await tester.pump(const Duration(minutes: 10));
    expect(session.reports, isEmpty);
    await spellWithClaw(tester, 'fish');
    final report = session.reports.single.outcome;
    expect(report.correct, isTrue);
    expect(report.isUntimed, isTrue);
    expect(report.timedOut, isFalse);
    expect(
      report.responseTime,
      greaterThanOrEqualTo(const Duration(minutes: 10)),
    );
    expect(find.text('FISH'), findsOneWidget);
    expect(ends, 0);
    await tapClaw(tester, ClawKeys.next);
    expect(find.byKey(ClawKeys.summary), findsOneWidget);
    expect(session.nextItemCalls, 2);
    expect(ends, 1);
    await tester.pumpWidget(const SizedBox());
    expect(session.reports, hasLength(1));
  });

  testWidgets('промах исправим, один доклад хранит ошибку и подсказку', (
    tester,
  ) async {
    final session = FakeReviewSession([_fish]);
    await _show(tester, session);
    final wrong = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byWidgetPredicate(
              (widget) =>
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith(
                    'claw.capsule.',
                  ),
            ),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data!)
        .firstWhere((letter) => letter != 'F');
    await catchClawLetter(tester, wrong);
    expect(find.text('Буква $wrong не подошла'), findsOneWidget);
    expect(session.reports, isEmpty);
    await tapClaw(tester, ClawKeys.hint);
    await tapClaw(tester, ClawKeys.hint);
    await tapClaw(tester, ClawKeys.grab);
    await spellWithClaw(tester, 'ish');
    final report = session.reports.single.outcome;
    expect(report.correct, isFalse);
    expect(report.selectedAnswer, wrong);
    expect(report.hintsUsed, 1);
    expect(find.text('FISH'), findsOneWidget);
  });

  testWidgets('двойной захват и сворачивание не двигают раунд', (tester) async {
    final session = FakeReviewSession([_fish]);
    await _show(tester, session);
    await spellWithClaw(tester, 'fis');
    await tester.tap(clawCapsule('H'));
    await tester.pumpAndSettle();
    final grab = find.byKey(ClawKeys.grab);
    await tester.tap(grab);
    await tester.tap(grab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(days: 1));
    expect(session.reports, isEmpty);
    expect(find.byKey(ClawKeys.result), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(session.reports.single.outcome.correct, isTrue);
    expect(
      session.reports.single.outcome.responseTime,
      lessThan(const Duration(minutes: 1)),
    );
    expect(find.text('FISH'), findsOneWidget);
  });

  testWidgets('уход докладывает неответ без завершения партии', (tester) async {
    final session = FakeReviewSession([_fish]);
    var ends = 0;
    await _show(tester, session, finish: () => ends++);
    await tester.pumpWidget(const SizedBox());
    expect(session.reports.single.outcome.correct, isFalse);
    expect(session.reports.single.outcome.timedOut, isFalse);
    expect(ends, 0);
  });

  testWidgets('пустая очередь открывает экран на сегодня всё', (tester) async {
    final session = FakeReviewSession([]);
    var ends = 0;
    await _show(tester, session, finish: () => ends++);
    expect(find.text('На сегодня всё'), findsOneWidget);
    expect(session.nextItemCalls, 1);
    expect(session.reports, isEmpty);
    expect(ends, 0);
  });

  testWidgets('длинное слово печатается целиком при шрифте 2×', (tester) async {
    const word = 'telecommunications';
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await _show(
      tester,
      FakeReviewSession(const [
        ReviewItem(
          word: Word(id: word, text: word, translation: 'телекоммуникации'),
        ),
      ]),
    );
    await spellWithClaw(tester, word);
    expect(find.text(word.toUpperCase()), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
