import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tapClaw(WidgetTester tester, Key key) async {
  final target = find.byKey(key);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Finder clawCapsule(String letter) =>
    find
        .ancestor(
          of: find.text(letter),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'claw.capsule.',
                ),
          ),
        )
        .first;

Future<void> catchClawLetter(WidgetTester tester, String letter) async {
  final target = clawCapsule(letter);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
  await tapClaw(tester, ClawKeys.grab);
}

Future<void> spellWithClaw(WidgetTester tester, String word) async {
  for (final letter in word.toUpperCase().split('')) {
    await catchClawLetter(tester, letter);
  }
}
