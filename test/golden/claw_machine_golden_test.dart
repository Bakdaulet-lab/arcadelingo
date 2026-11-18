import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/claw_actions.dart';
import '../support/fake_review_session.dart';
import '../support/golden_harness.dart';

Future<void> _start(WidgetTester tester) async {
  tester.view.physicalSize = goldenPhysicalSize;
  tester.view.devicePixelRatio = goldenDevicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = 1;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    MaterialApp(
      theme: wordarcadeTheme(platform: TargetPlatform.android),
      debugShowCheckedModeBanner: false,
      home: ClawMachineGame(
        session: FakeReviewSession(const [
          ReviewItem(word: Word(id: 'fish', text: 'fish', translation: 'рыба')),
        ]),
        seed: 7,
        onPlayAgain: () {},
        onExit: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('выбор капсулы', tags: 'golden', (tester) async {
    await _start(tester);
    await spellWithClaw(tester, 'fi');
    await expectGolden(tester, 'claw_aim');
  });

  testWidgets('подсказка и захват', tags: 'golden', (tester) async {
    await _start(tester);
    await spellWithClaw(tester, 'fi');
    await tapClaw(tester, ClawKeys.hint);
    await tester.tap(find.byKey(ClawKeys.grab));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    await expectGolden(tester, 'claw_grab');
  });

  testWidgets('слово собрано', tags: 'golden', (tester) async {
    await _start(tester);
    await spellWithClaw(tester, 'fish');
    await expectGolden(tester, 'claw_result');
  });
}
