import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/claw_actions.dart';
import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';
import '../support/result.dart';

void main() {
  for (final level in CefrLevel.values) {
    testWidgets('Автомат: запуск из меню и карточки только ${level.name}', (
      tester,
    ) async {
      final bundled = ok((await tester.runAsync(loadWordsSeed))!);
      final items = [
        for (final band in CefrLevel.values)
          ...bundled.where((item) => item.word.level == band).take(2),
      ];
      final expected = items.where((item) => item.word.level == level);
      final answers = InMemoryAnswerLog();
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        WordarcadeApp(
          ports: AppPorts(
            cards: InMemoryCardStore(),
            streaks: InMemoryStreakStore(),
            answers: answers,
          ),
          seed: Ok(items),
          now: () => DateTime(2026, 11, 18, 10),
        ),
      );
      await tester.pumpAndSettle();

      for (final title in [level.name.toUpperCase(), 'Автомат с клешнёй']) {
        final target = find.text(title);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }
      await tapClaw(tester, AppKeys.play);
      for (final item in expected) {
        expect(
          tester.widget<Text>(find.byKey(ClawKeys.prompt)).data,
          item.word.translation,
        );
        await spellWithClaw(tester, item.word.text);
        expect(answers.records.last.wordId, item.word.id);
        expect(answers.records.last.gameId, 'claw_machine');
        expect(answers.records.last.correct, isTrue);
        await tapClaw(tester, ClawKeys.next);
      }
      expect(answers.records, hasLength(2));
      expect(find.byKey(ClawKeys.summary), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
