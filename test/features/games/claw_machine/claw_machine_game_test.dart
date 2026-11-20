import 'package:arcadelingo/domain/ports/sounds.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_field.dart'
    show ClawMachineField;
import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/claw_actions.dart';
import '../../../support/fake_review_session.dart';

const _fish = ReviewItem(
  word: Word(id: 'fish', text: 'fish', translation: 'рыба'),
);

class _RecordingSounds implements Sounds {
  final played = <GameSound>[];

  @override
  void play(GameSound sound) => played.add(sound);
}

Future<void> _show(
  WidgetTester tester,
  FakeReviewSession session, {
  VoidCallback? finish,
  bool reduceMotion = false,
  Brightness brightness = Brightness.dark,
  Sounds sounds = const NoopSounds(),
}) async {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: wordarcadeTheme(brightness: brightness),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
      home: ClawMachineGame(
        session: session,
        sounds: sounds,
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
  for (final brightness in Brightness.values) {
    testWidgets('glass and keys aim without grabbing ($brightness)', (
      tester,
    ) async {
      final session = FakeReviewSession([_fish]);
      await _show(tester, session, brightness: brightness);
      final field = find.byType(ClawMachineField);
      final bounds = tester.getRect(field);
      await tester.tapAt(bounds.topLeft + const Offset(20, 45));
      await tester.pump();
      expect(tester.widget<ClawMachineField>(field).column, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(tester.widget<ClawMachineField>(field).column, 1);
      expect(session.reports, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(tester.widget<ClawMachineField>(field).capturing, isTrue);
      await tester.pumpAndSettle();
      expect(tester.widget<ClawMachineField>(field).capturing, isFalse);
    });

    testWidgets('wrong capsule and completed word react ($brightness)', (
      tester,
    ) async {
      final session = FakeReviewSession([_fish]);
      await _show(tester, session, brightness: brightness);
      final field = tester.widget<ClawMachineField>(
        find.byType(ClawMachineField),
      );
      final wrong = field.stacks
          .map((stack) => stack.last)
          .firstWhere((letter) => letter != 'F');
      Future<void> checkGrab(String letter, Finder label) async {
        await tester.tap(clawCapsule(letter));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ClawKeys.grab));
        await tester.pump();
        // The capture finishes on the first frame past its 570 ms duration.
        await tester.pump(const Duration(milliseconds: 580));
        expect(label, findsOneWidget);
        await tester.pump(const Duration(milliseconds: 60));
        final moving = tester.getRect(label);
        await tester.pumpAndSettle();
        expect(tester.getRect(label), isNot(moving));
      }

      await checkGrab(wrong, find.text('Буква $wrong не подошла'));
      expect(session.reports, isEmpty);
      await spellWithClaw(tester, 'fis');
      await checkGrab('H', find.text('FISH'));
      expect(session.reports.single.outcome.correct, isFalse);
      expect(find.byKey(ClawKeys.next), findsOneWidget);
    });
  }
  testWidgets('горизонтальный жест на стекле выбирает дорожку', (tester) async {
    final session = FakeReviewSession([_fish]);
    await _show(tester, session);
    final field = find.byType(ClawMachineField);
    final glass = tester.getRect(field);
    final start = Offset(glass.center.dx, glass.top + 55);
    final drag = await tester.startGesture(start);
    await drag.moveBy(const Offset(-35, 0));
    await drag.moveTo(Offset(glass.left + 20, start.dy));
    await drag.up();
    await tester.pumpAndSettle();
    expect(tester.widget<ClawMachineField>(field).column, 0);
    expect(session.reports, isEmpty);
  });

  testWidgets('уменьшенное движение: захват быстрый, итог звучит один раз', (
    tester,
  ) async {
    final session = FakeReviewSession([_fish]);
    final sounds = _RecordingSounds();
    await _show(tester, session, reduceMotion: true, sounds: sounds);
    await spellWithClaw(tester, 'fis');
    await tester.tap(clawCapsule('H'));
    await tester.pump();
    final grab = find.byKey(ClawKeys.grab);
    await tester.tap(grab);
    await tester.tap(grab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(session.reports.single.outcome.correct, isTrue);
    expect(find.text('FISH'), findsOneWidget);
    expect(sounds.played, [
      GameSound.clawCatch,
      GameSound.clawCatch,
      GameSound.clawCatch,
      GameSound.clawWord,
    ]);
    await tapClaw(tester, ClawKeys.next);
    expect(
      sounds.played.where((sound) => sound == GameSound.roundEnd),
      hasLength(1),
    );
  });

  testWidgets('быстрые стрелки останавливаются у края рельса', (tester) async {
    await _show(tester, FakeReviewSession([_fish]));
    await tapClaw(tester, ClawKeys.left);
    final left = find.byKey(ClawKeys.left);
    await tester.tap(left);
    await tester.tap(left);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<ClawMachineField>(find.byType(ClawMachineField)).column,
      0,
    );
  });

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
    await catchClawLetter(tester, 'F');
    final wrong = await missWithClaw(tester, 'I');
    expect(find.text('Буква $wrong не подошла'), findsOneWidget);
    await missWithClaw(tester, 'I', avoid: wrong);
    expect(
      find.descendant(of: find.byKey(ClawKeys.slots), matching: find.text('F')),
      findsOneWidget,
    );
    expect(session.reports, isEmpty);
    await tapClaw(tester, ClawKeys.hint);
    await tapClaw(tester, ClawKeys.hint);
    await tapClaw(tester, ClawKeys.grab);
    await spellWithClaw(tester, 'sh');
    final report = session.reports.single.outcome;
    expect(report.correct, isFalse);
    expect(report.selectedAnswer, 'F$wrong');
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
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 1));
    expect(session.reports, isEmpty);
    for (final state in [AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    await tester.pump(const Duration(days: 1));
    expect(session.reports, isEmpty);
    expect(find.byKey(ClawKeys.result), findsNothing);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
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
    await missWithClaw(tester, 'F');
    await tester.pumpWidget(const SizedBox());
    expect(session.reports.single.outcome.correct, isFalse);
    expect(session.reports.single.outcome.selectedAnswer, isNull);
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
