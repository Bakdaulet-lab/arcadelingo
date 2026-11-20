import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:arcadelingo/ui/arcade_round_summary.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/claw_actions.dart';
import '../support/fake_review_session.dart';

Future<void> _showResult(
  WidgetTester tester, {
  Brightness brightness = Brightness.dark,
  bool reduceMotion = false,
  bool outOfLives = false,
  VoidCallback? onReplay,
}) => tester.pumpWidget(
  MaterialApp(
    theme: wordarcadeTheme(brightness: brightness),
    home: Builder(
      builder:
          (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: Scaffold(
              body: ArcadeRoundSummary(
                score: 100,
                bestCombo: 1,
                correctCount: 1,
                answeredCount: 2,
                outOfLives: outOfLives,
                actions: FilledButton(
                  onPressed: onReplay,
                  child: const Text('Replay'),
                ),
              ),
            ),
          ),
    ),
  ),
);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Итог $brightness один раз подчёркивает значок', (
      tester,
    ) async {
      var taps = 0;
      final outOfLives = brightness == Brightness.light;
      final icon = find.byIcon(
        outOfLives ? Icons.favorite_border_rounded : Icons.emoji_events_rounded,
      );
      final replay = find.text('Replay');
      await _showResult(
        tester,
        brightness: brightness,
        outOfLives: outOfLives,
        onReplay: () => taps++,
      );
      final rest = tester.getTopLeft(icon);
      final button = tester.getCenter(replay);
      await tester.pump(const Duration(milliseconds: 96));
      expect(tester.getTopLeft(icon).dy, lessThan(rest.dy - 1));
      expect(tester.getCenter(replay), button);
      await tester.tap(replay);
      expect(taps, 1);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(icon), rest);

      await _showResult(
        tester,
        brightness: brightness,
        outOfLives: outOfLives,
        onReplay: () => taps++,
      );
      await tester.pump(const Duration(milliseconds: 96));
      expect(tester.getTopLeft(icon), rest);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  }

  testWidgets('Уменьшение движения сразу останавливает акцент', (tester) async {
    final icon = find.byIcon(Icons.emoji_events_rounded);
    await _showResult(tester);
    final rest = tester.getTopLeft(icon);
    await tester.pump(const Duration(milliseconds: 96));
    expect(tester.getTopLeft(icon).dy, lessThan(rest.dy - 1));
    await _showResult(tester, reduceMotion: true);
    expect(tester.getTopLeft(icon), rest);
    await _showResult(tester);
    await tester.pump(const Duration(milliseconds: 48));
    expect(tester.getTopLeft(icon), rest);
  });

  testWidgets('При уменьшении движения результат неподвижен с первого кадра', (
    tester,
  ) async {
    final icon = find.byIcon(Icons.emoji_events_rounded);
    await _showResult(tester, reduceMotion: true);
    final rest = tester.getTopLeft(icon);
    await tester.pump(const Duration(milliseconds: 96));
    expect(tester.getTopLeft(icon), rest);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('Автомат с клешнёй показывает акцент после последнего слова', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClawMachineGame(
          session: FakeReviewSession(const [
            ReviewItem(
              word: Word(id: 'fish', text: 'fish', translation: 'рыба'),
            ),
          ]),
          seed: 7,
          onExit: () {},
          onPlayAgain: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await spellWithClaw(tester, 'fish');
    await tester.ensureVisible(find.byKey(ClawKeys.next));
    await tester.tap(find.byKey(ClawKeys.next));
    await tester.pump();
    final icon = find.byIcon(Icons.emoji_events_rounded);
    final rest = tester.getTopLeft(icon);
    await tester.pump(const Duration(milliseconds: 96));
    expect(tester.getTopLeft(icon).dy, lessThan(rest.dy - 1));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(icon), rest);
  });
}
